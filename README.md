# Readme — Spy VideoCam

> **Turn your old Android phone into a CCTV camera.**
> **Ubah ponsel Android lama Anda menjadi kamera CCTV.**

[![Version](https://img.shields.io/badge/version-1.3.0-blue)](CHANGELOG.md)
[![Platform](https://img.shields.io/badge/platform-Android-green)](https://developer.android.com)
[![Flutter](https://img.shields.io/badge/Flutter-3.x-blue)](https://flutter.dev)
[![Status](https://img.shields.io/badge/status-prototype-orange)](CHANGELOG.md)

---

Spy VideoCam is an open-source Android application built with Flutter that
transforms any spare Android device into a security camera. It supports
manual recording, scheduled recording, background operation, and automatic
chunk rotation to prevent file size limits.

Spy VideoCam adalah aplikasi Android open-source yang dibangun dengan
Flutter, mengubah perangkat Android yang tidak terpakai menjadi kamera
keamanan. Mendukung rekaman manual, rekaman terjadwal, operasi latar
belakang, dan rotasi chunk otomatis untuk mencegah batas ukuran file.

---

## Features / Fitur

- Manual recording — start instantly, stop anytime
  Rekam manual — mulai seketika, berhenti kapan saja
- Scheduled recording — set a start time, recording begins automatically
  Rekam terjadwal — atur jam mulai, rekaman dimulai otomatis
- Chunk rotation — video split every 10 minutes automatically
  Rotasi chunk — video dibagi setiap 10 menit secara otomatis
- Max duration — auto-stop after 6 hours
  Durasi maksimal — berhenti otomatis setelah 6 jam
- Background recording — continues recording when screen is off or app
  is minimized
  Rekam latar belakang — rekaman tetap berjalan saat layar mati atau
  app diminimize
- Foreground service — persistent notification with stop action
  Foreground service — notifikasi persisten dengan tombol stop
- Boot restore — scheduled alarm restored after device reboot
  Boot restore — alarm terjadwal dipulihkan setelah device reboot
- API-aware permissions — handles Android 7 through 14+
  Permission adaptif — mendukung Android 7 hingga 14+

---

## Supported Devices / Perangkat yang Didukung

Tested on / Diuji pada:
- Samsung Galaxy A05 (Android 13)
- Samsung Galaxy Note 10+ (Android 12)
- Xiaomi Redmi 5A (Android 8.1 / MIUI) — install via release APK only
- OnePlus/OPPO CPH1919 (Android 12) — Camera2 TEMPLATE_PREVIEW fallback
  applied

Minimum Android version / Versi Android minimum: 7.0 (API 24)

---

## Known Device Compatibility / Kompatibilitas Perangkat

Some OPPO/OnePlus devices reject Camera2 TEMPLATE_RECORD. The app
automatically falls back to TEMPLATE_PREVIEW when this occurs.
Recording output is identical — both templates write to the same
MediaRecorder surface.

Beberapa perangkat OPPO/OnePlus menolak TEMPLATE_RECORD pada Camera2.
Aplikasi secara otomatis beralih ke TEMPLATE_PREVIEW ketika hal ini
terjadi. Output rekaman tetap identik — kedua template menulis ke
surface MediaRecorder yang sama.

Xiaomi Redmi 5A (MIUI Android 8.1) does not support ADB debug install.
Use release APK installed manually via file manager.

Xiaomi Redmi 5A (MIUI Android 8.1) tidak mendukung instalasi debug via
ADB. Gunakan release APK yang diinstal manual via file manager.

---

## Output

Videos are saved to / Video disimpan di:
  /storage/emulated/0/DCIM/SpyVideoCam/

File naming format / Format penamaan file:
  chunk_001_20260421_143022.mp4

---

## Tech Stack

- Flutter 3.x (Dart)
- Kotlin (native Android plugins)
- Camera2 API + MediaRecorder (native Kotlin, background recording)
- permission_handler
- device_info_plus
- wakelock_plus
- flutter_foreground_task
- AlarmManager (scheduled recording / rekam terjadwal)

---

## Permissions Required / Izin yang Diperlukan

- CAMERA
- RECORD_AUDIO
- FOREGROUND_SERVICE / FOREGROUND_SERVICE_CAMERA
- SCHEDULE_EXACT_ALARM (Android 12+ / API 31+)
- MANAGE_EXTERNAL_STORAGE (Android 11+ / API 30+)
- READ_MEDIA_VIDEO (Android 13+ / API 33+)
- RECEIVE_BOOT_COMPLETED (alarm restore / pemulihan alarm)
- WAKE_LOCK

---

## Getting Started / Memulai

1. Clone this repository / Clone repositori ini
   git clone https://github.com/remtekindo/spy_videocam.git

2. Install dependencies / Instal dependensi
   flutter pub get

3. Initial clean (recommended / disarankan)
   flutter clean

4. Run on device / Jalankan di perangkat
   flutter run

---

## Project Structure / Struktur Proyek

lib/
  main.dart                  — entry point, permission bootstrap
  screens/
    home_screen.dart          — main UI / UI utama
  services/
    recording_service.dart    — camera, chunk rotation, wakelock
    scheduler_service.dart    — Dart-side schedule bridge
  widgets/
    recording_popup.dart      — active recording overlay
    schedule_popup.dart       — time picker dialog

android/app/src/main/kotlin/com/remtekindo/cctv/
  MainActivity.kt             — MethodChannel + EventChannel handler
  VideoForegroundService.kt   — foreground service + CameraRecorderPlugin
  CameraRecorderPlugin.kt     — Camera2 + MediaRecorder, chunk rotation
  SchedulerService.kt         — AlarmManager + BootReceiver

---

## Contributing / Kontribusi

Pull requests are welcome. For major changes, please open an issue first
to discuss what you would like to change.

Pull request dipersilakan. Untuk perubahan besar, buka issue terlebih
dahulu untuk mendiskusikan perubahan yang ingin Anda buat.

---

## License / Lisensi

This project is licensed under the GNU General Public License v3.0.
See the LICENSE file for details.

Proyek ini dilisensikan di bawah GNU General Public License v3.0.
Lihat file LICENSE untuk detailnya.

---

## Related / Terkait

- **[LICENSE](LICENSE)** — License / Lisensi
- **[CHANGELOG.md](CHANGELOG.md)** — Full version history / Riwayat versi lengkap
- **[PROJECT_EVOLUTION.md](PROJECT_EVOLUTION.md)** — Architecture evolution /
  Evolusi arsitektur

---

## Company / Perusahaan

**Remtekindo**

---

*Last updated / Terakhir diperbarui: April 21, 2026*