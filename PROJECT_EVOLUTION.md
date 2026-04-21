# Project Evolution — Spy VideoCam

> This document records the architectural decisions, technical
> rationale, and development trajectory of Spy VideoCam. It is
> intended to help contributors understand not just what was built,
> but why.
>
> Dokumen ini mencatat keputusan arsitektur, alasan teknis, dan
> perjalanan pengembangan Spy VideoCam. Ditujukan untuk membantu
> kontributor memahami tidak hanya apa yang dibangun, tetapi mengapa.

**Repo:** spy_videocam
**Data source:** Full Git history + session logs (init to Apr 21, 2026)

---

## Overview / Gambaran Umum

Spy VideoCam was born out of a practical need: repurposing idle Android
devices as functional security cameras without purchasing dedicated
hardware. The goal from day one was simplicity — a single APK, no cloud
dependency, no account required.

Spy VideoCam lahir dari kebutuhan praktis: memanfaatkan kembali
perangkat Android yang tidak terpakai sebagai kamera keamanan tanpa
perlu membeli hardware khusus. Tujuan dari awal adalah kesederhanaan —
satu APK, tanpa ketergantungan cloud, tanpa akun.

---

## v1.1.0 — Initial Release (April 2026)

### Background / Latar Belakang

The project started as an internal tool under Remtekindo's hardware
ecosystem. The first working version was built iteratively across three
development sessions, each addressing a distinct layer of the stack.

Proyek ini dimulai sebagai alat internal dalam ekosistem hardware
Remtekindo. Versi pertama yang berfungsi dibangun secara iteratif
dalam tiga sesi pengembangan, masing-masing menangani lapisan stack
yang berbeda.

### Session 1 — UI and Service Foundation

The first session established the full Flutter UI and the Dart-side
service layer:

- HomeScreen with two primary actions: manual recording and scheduled
  recording. A minimized recording bar allows the user to return to
  the home screen without interrupting an active session.
- RecordingPopup as a blocking overlay during active recording. The
  back button is intentionally disabled — the session can only be
  ended via the Stop button to prevent accidental interruption.
- SchedulePopup with a drum wheel time picker. The date is locked to
  today to keep the interaction surface minimal and reduce user error.
- RecordingService as a singleton managing the full recording
  lifecycle: camera initialization, 10-minute chunk rotation, elapsed
  timer, wakelock, and a 6-hour hard stop.
- SchedulerService as a thin Dart bridge to the native AlarmManager
  via MethodChannel.

#### Why chunk rotation? / Mengapa chunk rotation?

A single continuous video file over several hours creates practical
problems: large files are harder to transfer, a single write failure
loses everything, and some file systems have size limits. Chunking at
10 minutes keeps individual files manageable and limits data loss to
at most one chunk on failure.

Satu file video kontinu selama beberapa jam menimbulkan masalah
praktis: file besar sulit ditransfer, satu kegagalan tulis
menghilangkan semua data, dan beberapa sistem file memiliki batas
ukuran. Chunking 10 menit menjaga ukuran file tetap manageable dan
membatasi kehilangan data maksimal satu chunk per kegagalan.

#### Why 6 hours max? / Mengapa maksimal 6 jam?

Six hours covers the most common CCTV use cases (overnight parking,
a workday, a shift) without requiring the app to manage indefinite
recording. The wakelock is acquired with a matching 6-hour timeout.

Enam jam mencakup kasus penggunaan CCTV paling umum (parkir semalam,
hari kerja, satu shift) tanpa mengharuskan app mengelola rekaman
tanpa batas. WakeLock diperoleh dengan timeout 6 jam yang sesuai.

### Session 2 — Native Android Layer

The second session built the native Kotlin layer required for reliable
background operation:

- VideoForegroundService keeps the recording alive when the app is
  backgrounded. Android aggressively kills background processes on
  modern versions — a foreground service with a persistent
  notification is the only reliable mechanism.
- SchedulerService.kt uses AlarmManager with setExactAndAllowWhileIdle
  to fire even when the device is in Doze mode.
- BootReceiver restores any pending scheduled alarm after a device
  reboot.

#### Why AlarmManager over WorkManager?

WorkManager is designed for deferrable background work and gives the
system latitude to delay execution. For a scheduled recording that
must start at a specific time, that latitude is unacceptable.
AlarmManager with RTC_WAKEUP provides exact timing guarantees.

WorkManager dirancang untuk pekerjaan background yang dapat ditunda
dan memberi sistem keleluasaan untuk menunda eksekusi. Untuk rekaman
terjadwal yang harus dimulai pada waktu tertentu, keleluasaan itu
tidak dapat diterima. AlarmManager dengan RTC_WAKEUP memberikan
jaminan waktu yang tepat.

### Session 3 — Build Fixes and Permission Layer

The third session resolved build and runtime issues that emerged
during device testing:

- compileSdk raised to 36 to satisfy camera_android_camerax 1.5.3.
- Duplicate Kotlin BootReceiver file removed.
- requestPermissions() rewritten with API-level branching: camera and
  audio are the only gates for recording; storage permissions are
  requested per API level but do not block the recording flow.

### Rename — Matel VideoCam to Spy VideoCam

Before opening the repository to the public, the app was renamed from
"Matel VideoCam" to "Spy VideoCam" to establish a clear standalone
identity separate from the Matel hardware ecosystem.

---

## v1.2.0 — Native Camera2 Recording (April 2026)

### Background / Latar Belakang

Device testing showed that recording stopped when the home button was
pressed or the screen locked. Root cause: the Flutter camera plugin
requires an active surface — it cannot record without the screen on.
Since Spy VideoCam is intended as a headless CCTV device, this was a
blocker that had to be resolved before the app could be used in a
real deployment.

Pengujian device menunjukkan bahwa rekaman berhenti ketika tombol
home ditekan atau layar dikunci. Root cause: Flutter camera plugin
membutuhkan active surface — tidak dapat merekam tanpa layar aktif.
Karena Spy VideoCam dirancang sebagai device CCTV headless, ini
adalah blocker yang harus diselesaikan sebelum app dapat digunakan
secara nyata.

### Solution — Camera2 Native Layer / Solusi — Native Layer Camera2

Recording was moved entirely to native Kotlin using Camera2 API and
MediaRecorder. Flutter no longer holds a CameraController — it only
sends start/stop commands and receives status updates.

CameraRecorderPlugin is a new class that manages the full recording
lifecycle in native: opens the camera via Camera2, configures
MediaRecorder, runs chunk rotation via Handler, and pushes status to
Flutter via EventChannel. This plugin lives inside
VideoForegroundService and remains active as long as the service runs
— regardless of whether the screen is off, the app is in background,
or the Flutter engine is inactive.

Rekaman dipindahkan sepenuhnya ke native Kotlin menggunakan Camera2
API dan MediaRecorder. Flutter tidak lagi memegang CameraController —
hanya mengirim perintah start/stop dan menerima status.

### Communication Architecture / Arsitektur Komunikasi

Flutter → Native: MethodChannel "com.remtekindo.cctv/scheduler"
startRecordingNow, stopRecording
Native → Flutter: EventChannel "com.remtekindo.cctv/recorder_events"
push map: {type, isRecording, chunkIndex, savedFiles, elapsedMs}

### Video Parameters / Parameter Video

480p (640×480), H264, 1.5 Mbps, 24fps, AAC 128kbps 44100Hz.
Resolution chosen for balance between CCTV readability and
battery/storage consumption on older devices.

Resolusi dipilih untuk keseimbangan antara keterbacaan gambar CCTV
dan konsumsi baterai/storage pada device lama.

### Known Trade-off / Trade-off yang Diketahui

Camera preview is no longer available in Flutter UI — CameraController
was removed entirely. This is intentional: preview requires the same
surface used by MediaRecorder, and showing preview would complicate
background recording. For a headless CCTV use case, preview is not
needed.

Preview kamera tidak lagi tersedia di Flutter UI — CameraController
dihapus sepenuhnya. Ini disengaja: preview membutuhkan surface yang
sama dengan MediaRecorder. Untuk use case CCTV headless, preview
tidak dibutuhkan.

---

## v1.3.0 — Bug Fixes & Device Compatibility (April 2026)

### Scheduled Recording — SecurityException on Android 12+

Android 12 introduced a requirement that apps must hold
SCHEDULE_EXACT_ALARM permission before calling
setExactAndAllowWhileIdle. This was a hard crash on first scheduled
recording attempt. The fix has two parts: declare the permission in
AndroidManifest, and add a runtime check via canScheduleExactAlarms()
with a setWindow fallback for devices where the user has not granted
the permission.

Android 12 memperkenalkan persyaratan bahwa app harus memegang izin
SCHEDULE_EXACT_ALARM sebelum memanggil setExactAndAllowWhileIdle.
Ini menyebabkan hard crash pada percobaan rekam terjadwal pertama.
Fix terdiri dari dua bagian: deklarasi permission di AndroidManifest,
dan pengecekan runtime via canScheduleExactAlarms() dengan fallback
setWindow.

### EventChannel Race Condition

The recorder status stream was silent on first launch because
RecordingService called startRecordingNow before subscribing to the
EventChannel. The native layer was already pushing status events
before Flutter had registered its listener, causing all early events
to be dropped with a FlutterJNI detached warning in the log. Fix:
subscribe the EventChannel first, wait 300ms for onListen to fire,
then invoke startRecordingNow.

Stream status recorder tidak menampilkan apapun pada peluncuran
pertama karena RecordingService memanggil startRecordingNow sebelum
subscribe ke EventChannel. Fix: subscribe EventChannel dulu, tunggu
300ms agar onListen terpanggil, baru panggil startRecordingNow.

### Integer to Long Cast — MethodChannel

Flutter's MethodChannel serializes small integers as Int rather than
Long. The Kotlin side was casting directly via call.argument<Long>
which throws ClassCastException when the value fits in an Int. Fixed
by reading as Number and calling toLong().

MethodChannel Flutter menyerialisasi integer kecil sebagai Int bukan
Long. Sisi Kotlin melakukan cast langsung via call.argument<Long>
yang melempar ClassCastException. Fix: baca sebagai Number dan
panggil toLong().

### Camera2 TEMPLATE_RECORD Compatibility

Tested on CPH1919 (OnePlus/OPPO, Android 12). The device's camera HAL
does not implement TEMPLATE_RECORD (template 3), returning Function
not implemented (-38). This is a firmware-level omission common to
several OPPO/OnePlus models.

The fix wraps createCaptureRequest in a try-catch: attempt
TEMPLATE_RECORD first, fall back to TEMPLATE_PREVIEW on
CameraAccessException. Both templates direct output to the same
MediaRecorder surface, so recording quality and behavior are
identical. The fallback is logged at warning level for diagnostics.

Diuji pada CPH1919 (OnePlus/OPPO, Android 12). Camera HAL device
tidak mengimplementasikan TEMPLATE_RECORD (template 3). Fix:
bungkus createCaptureRequest dalam try-catch, coba TEMPLATE_RECORD
dulu, fallback ke TEMPLATE_PREVIEW jika CameraAccessException.

### Device Compatibility Notes / Catatan Kompatibilitas Device

Recording has been verified on:
Rekaman telah diverifikasi pada:

- Samsung Galaxy A05 (Android 13) — full Camera2 support
- OnePlus CPH1919 (Android 12) — TEMPLATE_PREVIEW fallback active
- Samsung Galaxy Note 10+ (Android 12) — pending verification
- Xiaomi Redmi 5A (Android 8.1 / MIUI) — install via release APK only

---

## Architectural Decisions / Keputusan Arsitektur

### Single APK, no backend

Spy VideoCam deliberately has no server component, no cloud upload,
and no remote viewing. This keeps the trust surface small — the
user's video never leaves the device unless they choose to move it
manually.

Spy VideoCam sengaja tidak memiliki komponen server, upload cloud,
atau remote viewing. Ini menjaga permukaan kepercayaan tetap kecil —
video pengguna tidak pernah meninggalkan device kecuali mereka
memilih untuk memindahkannya secara manual.

### Singleton Services

RecordingService and SchedulerService are implemented as Dart
singletons. This ensures a single source of truth for recording state
across the UI without introducing a state management library.

RecordingService dan SchedulerService diimplementasikan sebagai Dart
singleton. Ini memastikan satu sumber kebenaran untuk state rekaman
di seluruh UI tanpa memperkenalkan library state management.

### MethodChannel over Platform Plugins

The scheduling bridge uses a raw MethodChannel rather than a
published Flutter plugin. This was a pragmatic choice: no existing
plugin covers exact-time AlarmManager scheduling with boot restore
in a single package.

Bridge scheduling menggunakan MethodChannel langsung daripada plugin
Flutter yang dipublikasikan. Ini adalah pilihan pragmatis: tidak ada
plugin yang mencakup AlarmManager scheduling dengan boot restore
dalam satu paket.

---

## Known Limitations (v1.3.0)

- No video playback inside the app. / Tidak ada pemutaran video di app.
- No in-app gallery or file browser. / Tidak ada browser galeri di app.
- Samsung Galaxy Note 10+ recording not yet verified.
  Rekaman Samsung Galaxy Note 10+ belum diverifikasi.
- No unit tests. / Tidak ada unit test.

---

## Roadmap

v1.4.0
- In-app gallery: browse and delete recorded chunks
  Browser galeri: lihat dan hapus chunk rekaman
- Video playback inside the app
  Pemutaran video di dalam app

v1.5.0
- Local network stream: view live feed from another device
  Stream jaringan lokal: lihat live feed dari device lain

v2.0.0
- Multi-device support / Dukungan multi-device
- Optional cloud backup / Backup cloud opsional

---

## Contributing / Kontribusi

See README.md for contribution guidelines. For architectural changes
or new features, please open an issue first to align on direction
before submitting a pull request.

Lihat README.md untuk panduan kontribusi. Untuk perubahan arsitektur
atau fitur baru, buka issue terlebih dahulu sebelum mengajukan pull
request.

---

Copyright (C) 2026 Remtekindo
Licensed under the GNU General Public License v3.0