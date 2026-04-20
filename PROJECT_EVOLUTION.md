## Project Evolution — Spy VideoCam

> This document records the architectural decisions, technical rationale, and development trajectory of Spy VideoCam. It is intended to help contributors understand not just what was built, but why.

**Repo:** `spy_videocam`  
**Data source:** Full Git history + session logs (init to Apr 20, 2026)

---

## Overview

Spy VideoCam was born out of a practical need: repurposing idle Android
devices as functional security cameras without purchasing dedicated
hardware. The goal from day one was simplicity — a single APK, no cloud
dependency, no account required.

---

## v1.1.0 — Initial Release (April 2026)

### Background

The project started as an internal tool under Remtekindo's hardware
ecosystem. The first working version was built iteratively across three
development sessions, each addressing a distinct layer of the stack.

### Session 1 — UI and Service Foundation

The first session established the full Flutter UI and the Dart-side
service layer:

- HomeScreen with two primary actions: manual recording and scheduled
  recording. A minimized recording bar allows the user to return to the
  home screen without interrupting an active session.
- RecordingPopup as a blocking overlay during active recording. The back
  button is intentionally disabled — the session can only be ended via
  the Stop button to prevent accidental interruption.
- SchedulePopup with a drum wheel time picker. The date is locked to
  today to keep the interaction surface minimal and reduce user error.
- RecordingService as a singleton managing the full recording lifecycle:
  camera initialization, 10-minute chunk rotation, elapsed timer,
  wakelock, and a 6-hour hard stop.
- SchedulerService as a thin Dart bridge to the native AlarmManager via
  MethodChannel.

#### Why chunk rotation?

A single continuous video file over several hours creates practical
problems: large files are harder to transfer, a single write failure
loses everything, and some file systems have size limits. Chunking at
10 minutes keeps individual files manageable and limits data loss to at
most one chunk on failure.

#### Why 6 hours max?

Six hours covers the most common CCTV use cases (overnight parking,
a workday, a shift) without requiring the app to manage indefinite
recording. The wakelock is acquired with a matching 6-hour timeout to
align with this limit.

#### Why ResolutionPreset.low?

Battery and storage. A device repurposed as a CCTV unit is typically
plugged in but has limited internal storage. 360p is sufficient for
identifying people and objects at typical indoor distances. Users with
specific resolution requirements can change this constant.

### Session 2 — Native Android Layer

The second session built the native Kotlin layer required for reliable
background operation:

- VideoForegroundService keeps the recording alive when the app is
  backgrounded. Android aggressively kills background processes on
  modern versions — a foreground service with a persistent notification
  is the only reliable mechanism.
- SchedulerService.kt uses AlarmManager with setExactAndAllowWhileIdle
  to fire even when the device is in Doze mode. A plain Handler or
  Dart Timer would be silenced by the system in low-power states.
- BootReceiver restores any pending scheduled alarm after a device
  reboot. Without this, a scheduled recording set before shutdown would
  silently disappear.

#### Why AlarmManager over WorkManager?

WorkManager is designed for deferrable background work and gives the
system latitude to delay execution. For a scheduled recording that must
start at a specific time, that latitude is unacceptable. AlarmManager
with RTC_WAKEUP provides exact timing guarantees.

### Session 3 — Build Fixes and Permission Layer

The third session resolved build and runtime issues that emerged during
device testing:

- compileSdk was raised to 36 to satisfy the minimum requirement of
  camera_android_camerax 1.5.3, which provides more stable Camera2
  access than the legacy camera plugin.
- A duplicate Kotlin BootReceiver file in a secondary folder was causing
  a build conflict. The duplicate was removed.
- requestPermissions() in RecordingService was rewritten to branch on
  Android API level. The original implementation requested
  Permission.storage unconditionally and used its result as a gate for
  starting recording. On Android 13+, Permission.storage returns denied
  by design — the system expects Permission.videos instead. This caused
  the "Izin kamera/audio ditolak" exception regardless of whether the
  user had actually granted camera and audio access.
- The fix separates concerns: camera and audio are the only gates for
  recording. Storage permissions are requested for their appropriate
  API level but their result does not block the recording flow.

---

## Architectural Decisions

### Single APK, no backend

Spy VideoCam deliberately has no server component, no cloud upload, and
no remote viewing. This keeps the trust surface small — the user's video
never leaves the device unless they choose to move it manually.

### Singleton services

RecordingService and SchedulerService are implemented as Dart singletons.
This ensures a single source of truth for recording state across the UI
(HomeScreen, RecordingPopup, minimized bar) without introducing a state
management library. The trade-off is that the services are not easily
unit-testable in isolation — a known limitation for a future refactor.

### MethodChannel over platform plugins

The scheduling bridge uses a raw MethodChannel rather than a published
Flutter plugin. This was a pragmatic choice: no existing plugin covers
exact-time AlarmManager scheduling with boot restore in a single
package. The channel is narrow and well-defined, making it easy to
replace with a plugin if one becomes available.

---

## Known Limitations (v1.1.0)

- No video playback inside the app. Files must be accessed via the
  device gallery or a file manager.
- No in-app gallery or file browser for recorded chunks.
- BLE auto-reconnect in background is unverified on all target devices.
- RecordingService is monolithic — camera, timer, storage, and state
  management are all in one class. A future version should split these
  into focused units.
- No unit tests. The recording lifecycle and permission logic have not
  been tested in isolation.

---

## Roadmap

v1.2.0
- In-app gallery: browse and delete recorded chunks
- Video playback inside the app

v1.3.0
- Local network stream: view live feed from another device on the same
  Wi-Fi network

v2.0.0
- Multi-device support: manage multiple camera devices from one control
  app
- Optional cloud backup integration

---

## Contributing

See README.md for contribution guidelines. For architectural changes or
new features, please open an issue first to align on direction before
submitting a pull request.

---

Copyright (C) 2026 Remtekindo
Licensed under the GNU General Public License v3.0