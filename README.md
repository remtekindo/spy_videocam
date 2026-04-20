# Readme — Spy VideoCam

> **Turn your old Android phone into a CCTV camera.**

[![Version](https://img.shields.io/badge/version-1.1.0-blue)](CHANGELOG.md)
[![Platform](https://img.shields.io/badge/platform-Android-green)](https://developer.android.com)
[![Flutter](https://img.shields.io/badge/Flutter-3.x-blue)](https://flutter.dev)
[![Status](https://img.shields.io/badge/status-prototype-orange)](CHANGELOG.md)

---

Spy VideoCam is an open-source Android application built with Flutter that
transforms any spare Android device into a security camera. It supports
manual recording, scheduled recording, background operation, and automatic
chunk rotation to prevent file size limits.

---

## Features

- Manual recording — start instantly, stop anytime
- Scheduled recording — set a start time, recording begins automatically
- Chunk rotation — video split every 10 minutes automatically
- Max duration — auto-stop after 6 hours
- Background operation — continues recording when app is minimized
- Foreground service — persistent notification with stop action
- Boot restore — scheduled alarm restored after device reboot
- API-aware permissions — handles Android 10 through 14+

---

## Supported Devices

Tested on:
- Samsung Galaxy A05 (Android 13)
- Samsung Galaxy Note 10+ (Android 12)
- Xiaomi Redmi 5A (Android 8 / MIUI)

Minimum Android version: 7.0 (API 24)

---

## Output

Videos are saved to:
  /storage/emulated/0/DCIM/SpyVideoCam/

File naming format:
  chunk_001_20250420_143022.mp4

---

## Tech Stack

- Flutter 3.x (Dart)
- Kotlin (native Android plugins)
- camera_android_camerax
- permission_handler
- device_info_plus
- wakelock_plus
- flutter_foreground_task
- AlarmManager (scheduled recording)

---

## Permissions Required

- CAMERA
- RECORD_AUDIO
- FOREGROUND_SERVICE / FOREGROUND_SERVICE_CAMERA
- MANAGE_EXTERNAL_STORAGE (Android 11+)
- READ_MEDIA_VIDEO (Android 13+)
- RECEIVE_BOOT_COMPLETED (alarm restore)
- WAKE_LOCK

---

## Getting Started

1. Clone this repository
   `git clone https://github.com/remtekindo/spy_videocam.git`

2. Install dependencies
   `flutter pub get`

3. Initial Clean (Recommended)
   `flutter clean`

4. Run on device
   `flutter run`

---

## Project Structure

lib/
  main.dart                  — entry point, permission bootstrap
  screens/
    home_screen.dart          — main UI
  services/
    recording_service.dart    — camera, chunk rotation, wakelock
    scheduler_service.dart    — Dart-side schedule bridge
  widgets/
    recording_popup.dart      — active recording overlay
    schedule_popup.dart       — time picker dialog

android/app/src/main/kotlin/com/remtekindo/cctv/
  MainActivity.kt             — MethodChannel handler
  VideoForegroundService.kt   — foreground service + WakeLock
  SchedulerService.kt         — AlarmManager + BootReceiver

---

## Contributing

Pull requests are welcome. For major changes, please open an issue first
to discuss what you would like to change.

---

## License

This project is licensed under the GNU General Public License v3.0.
See the LICENSE file for details.

---

## Related

- **[LICENSE.md](LICENSE.md)** — License
- **[CHANGELOG.md](CHANGELOG.md)** — Full version history
- **[PROJECT_EVOLUTION](PROJECT_EVOLUTION.md)** — Architecture evolution

---

## Company

**Remtekindo**  

---

*Last updated: April 20, 2026*