# Changelog — Spy VideoCam
# Format: https://keepachangelog.com
#

All notable changes to this project will be documented in this file.

---

## [v1.1.0] — 2026-04-20

### Added
- HomeScreen: 2-button layout, status card, minimized REC bar.
- RecordingPopup: live duration timer, chunk counter, 6-hour progress bar.
- SchedulePopup: drum wheel time picker, locked date badge, countdown display.
- RecordingService: Camera2 chunk rotation (10 min), wakelock, auto-stop at 6h.
- SchedulerService (Dart): Flutter-Kotlin MethodChannel bridge for scheduling.
- VideoForegroundService.kt: persistent foreground notification with stop action.
- SchedulerService.kt: AlarmManager exact alarm + BootReceiver for boot restore.
- AndroidManifest: full permission declarations including MANAGE_EXTERNAL_STORAGE.
- build.gradle: Updated compileSdk to 36 to support CameraX 1.5.3.
- pubspec.yaml: Integrated permission_handler, device_info_plus, and camera_android_camerax.

### Fixed
- **Build System:** Resolved `CheckAarMetadata` failure by upgrading compileSdk from 34 to 36.
- **Permission Mapping:** Fixed "Permission not found in manifest" for `MANAGE_EXTERNAL_STORAGE` (code 15).
- **Kotlin Conflicts:** Removed duplicate `BootReceiver.kt` that caused build-time errors.
- **Platform Branching:** Updated `requestPermissions()` logic:
  — Android 13+: `Permission.videos`
  — Android 11+: `Permission.manageExternalStorage`
  — Android <10: `Permission.storage`
- **MethodChannel Stability:** Aligned package name `com.remtekindo.cctv` across MainActivity and Services.

---

## [Unreleased]

- Video playback inside app
- Gallery browser for recorded chunks
- Remote viewing via local network stream

---

*For architecture evolution — see `PROJECT_EVOLUTION.md`*

*Last updated: April 20, 2026*