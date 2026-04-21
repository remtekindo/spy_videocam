# Changelog — Spy VideoCam
# Format: https://keepachangelog.com

All notable changes to this project will be documented in this file.
Semua perubahan penting pada proyek ini didokumentasikan di file ini.

---

## [v1.3.0] — 2026-04-21

### Fixed
- Scheduled recording crash (SecurityException) on Android 12+ —
  added SCHEDULE_EXACT_ALARM and USE_EXACT_ALARM permissions to
  AndroidManifest, fallback to setWindow when exact alarm unavailable.
  Crash rekam terjadwal (SecurityException) di Android 12+ —
  tambah permission SCHEDULE_EXACT_ALARM dan USE_EXACT_ALARM di
  AndroidManifest, fallback ke setWindow jika exact alarm tidak tersedia.
- SchedulerService: fixed duplicate else block in when expression.
  SchedulerService: hapus duplikat else pada when block setAlarm.
- main.dart: moved scheduleExactAlarm request to its own block,
  separate from storage permission branching (sdkInt >= 31).
  main.dart: pindah scheduleExactAlarm ke blok terpisah dari
  storage permission.
- MainActivity: fixed ClassCastException Integer to Long for delayMs
  argument from Flutter MethodChannel.
  MainActivity: fix ClassCastException Integer ke Long untuk argumen
  delayMs dari Flutter MethodChannel.
- RecordingService: subscribe EventChannel before invokeMethod
  startRecordingNow, added 300ms delay to ensure onListen fires first.
  RecordingService: subscribe EventChannel sebelum startRecordingNow,
  tambah delay 300ms agar onListen terpanggil lebih dulu.
- CameraRecorderPlugin: TEMPLATE_RECORD fallback to TEMPLATE_PREVIEW
  for OPPO/OnePlus devices that reject template 3 via Camera2 API.
  CameraRecorderPlugin: fallback TEMPLATE_RECORD ke TEMPLATE_PREVIEW
  untuk device OPPO/OnePlus yang menolak template 3 via Camera2.

### Added / Ditambahkan
- Permission.scheduleExactAlarm request for Android 12+ (API 31+).
  Request Permission.scheduleExactAlarm untuk Android 12+ (API 31+).

---

## [v1.2.0] — 2026-04-21

### Added / Ditambahkan
- CameraRecorderPlugin.kt: Camera2 + MediaRecorder native layer,
  10-minute chunk rotation, status push via EventChannel.
  CameraRecorderPlugin.kt: native layer Camera2 + MediaRecorder,
  chunk rotation 10 menit, push status via EventChannel.

### Changed / Diubah
- VideoForegroundService: integrated CameraRecorderPlugin, recording
  now runs entirely in native layer.
  VideoForegroundService: integrasikan CameraRecorderPlugin, rekaman
  kini berjalan sepenuhnya di native.
- MainActivity: added EventChannel com.remtekindo.cctv/recorder_events.
  MainActivity: tambah EventChannel recorder_events.
- recording_service.dart: removed CameraController, replaced with
  MethodChannel + EventChannel to native.
  recording_service.dart: hapus CameraController, diganti
  MethodChannel + EventChannel ke native.

### Fixed / Diperbaiki
- Recording stopped when home button pressed or screen locked —
  now runs fully in background without requiring Flutter surface.
  Rekaman berhenti saat tombol home ditekan atau layar dikunci —
  sekarang berjalan penuh di background tanpa Flutter surface.

---

## [v1.1.0] — 2026-04-20

### Added / Ditambahkan
- HomeScreen: 2-button layout, status card, minimized REC bar.
- RecordingPopup: live duration timer, chunk counter, 6-hour progress bar.
- SchedulePopup: drum wheel time picker, locked date badge, countdown display.
- RecordingService: Camera2 chunk rotation (10 min), wakelock, auto-stop at 6h.
- SchedulerService (Dart): Flutter-Kotlin MethodChannel bridge for scheduling.
- VideoForegroundService.kt: persistent foreground notification with stop action.
- SchedulerService.kt: AlarmManager exact alarm + BootReceiver for boot restore.
- AndroidManifest: full permission declarations including MANAGE_EXTERNAL_STORAGE.
- build.gradle: compileSdk upgraded to 36 to support CameraX 1.5.3.
- pubspec.yaml: integrated permission_handler, device_info_plus,
  camera_android_camerax.

### Fixed / Diperbaiki
- Build system: resolved CheckAarMetadata failure by upgrading
  compileSdk from 34 to 36.
- Permission mapping: fixed MANAGE_EXTERNAL_STORAGE not found in
  manifest (code 15).
- Kotlin conflicts: removed duplicate BootReceiver.kt that caused
  build-time errors.
- Platform branching: updated requestPermissions() logic —
  Android 13+: Permission.videos,
  Android 11–12: Permission.manageExternalStorage,
  Android 10 and below: Permission.storage.
- MethodChannel stability: aligned package name com.remtekindo.cctv
  across MainActivity and Services.

### Changed / Diubah
- App renamed from "Matel VideoCam" to "Spy VideoCam".
  Nama app diubah dari "Matel VideoCam" ke "Spy VideoCam".
- Video output directory changed from /DCIM/MatelCCTV/ to
  /DCIM/SpyVideoCam/.
- Version display corrected from v1.0.0 to v1.1.0 in HomeScreen.

---

## [Unreleased]

- Video playback inside app / Pemutaran video di dalam app
- Gallery browser for recorded chunks / Browser galeri untuk chunk rekaman
- Remote viewing via local network stream / Akses remote via jaringan lokal

---

*For architecture details — see PROJECT_EVOLUTION.md*
*Untuk detail arsitektur — lihat PROJECT_EVOLUTION.md*

*Last updated: April 21, 2026*