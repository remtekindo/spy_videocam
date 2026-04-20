import 'dart:async';
import 'dart:io';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:flutter/services.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:wakelock_plus/wakelock_plus.dart';

enum RecordingState { idle, recording, stopping }

class RecordingSession {
  final DateTime startTime;
  final bool isScheduled;
  final Duration maxDuration;
  int chunkIndex;
  int savedFiles;
  Duration elapsed;

  RecordingSession({
    required this.startTime,
    required this.isScheduled,
    required this.maxDuration,
    this.chunkIndex = 1,
    this.savedFiles = 0,
    this.elapsed = Duration.zero,
  });
}

/// RecordingService — Dart side
///
/// Tidak lagi memegang CameraController. Semua rekaman dilakukan
/// oleh CameraRecorderPlugin (Kotlin) via VideoForegroundService.
///
/// Flutter hanya:
/// 1. Kirim perintah start/stop via MethodChannel (scheduler channel)
/// 2. Terima status (elapsed, chunk, savedFiles) via EventChannel
/// 3. Expose stream ke UI (RecordingPopup, HomeScreen)
class RecordingService {
  static final RecordingService _instance = RecordingService._internal();
  factory RecordingService() => _instance;
  RecordingService._internal();

  static const _schedulerChannel = MethodChannel('com.remtekindo.cctv/scheduler');
  static const _recorderEvents = EventChannel('com.remtekindo.cctv/recorder_events');

  StreamSubscription? _eventSub;
  Timer? _elapsedTimer;

  RecordingState _state = RecordingState.idle;
  RecordingSession? _session;

  static const Duration maxAllowedDuration = Duration(hours: 6);
  // Diekspos ke RecordingPopup untuk progress bar
  static const Duration chunkDuration = Duration(minutes: 10);

  final StreamController<RecordingSession?> _sessionStream =
      StreamController<RecordingSession?>.broadcast();
  final StreamController<RecordingState> _stateStream =
      StreamController<RecordingState>.broadcast();

  Stream<RecordingSession?> get sessionStream => _sessionStream.stream;
  Stream<RecordingState> get stateStream => _stateStream.stream;
  RecordingState get state => _state;
  RecordingSession? get session => _session;

  /// Meminta izin kamera & audio sesuai API level Android.
  /// Storage/media permission diurus terpisah dan tidak memblokir rekaman.
  Future<bool> requestPermissions() async {
    if (!Platform.isAndroid) {
      final camera = await Permission.camera.request();
      final audio = await Permission.microphone.request();
      return camera.isGranted && audio.isGranted;
    }

    final androidInfo = await DeviceInfoPlugin().androidInfo;
    final sdkInt = androidInfo.version.sdkInt;

    final results = await [
      Permission.camera,
      Permission.microphone,
    ].request();

    final cameraGranted = results[Permission.camera]?.isGranted ?? false;
    final audioGranted = results[Permission.microphone]?.isGranted ?? false;

    if (sdkInt >= 33) {
      await Permission.videos.request();
    } else if (sdkInt >= 30) {
      if (!(await Permission.manageExternalStorage.isGranted)) {
        await Permission.manageExternalStorage.request();
      }
    } else {
      await Permission.storage.request();
    }

    return cameraGranted && audioGranted;
  }

  Future<void> startRecording({required bool isScheduled}) async {
    if (_state != RecordingState.idle) return;

    final granted = await requestPermissions();
    if (!granted) throw Exception('Izin kamera/audio ditolak');

    await WakelockPlus.enable();

    _session = RecordingSession(
      startTime: DateTime.now(),
      isScheduled: isScheduled,
      maxDuration: maxAllowedDuration,
    );

    _setState(RecordingState.recording);
    _sessionStream.add(_session);

    // Mulai VideoForegroundService — rekaman dilakukan sepenuhnya di native
    await _schedulerChannel.invokeMethod('startRecordingNow');

    // Dengarkan status dari CameraRecorderPlugin via EventChannel
    _listenToNativeEvents();
  }

  void _listenToNativeEvents() {
    _eventSub?.cancel();
    _eventSub = _recorderEvents.receiveBroadcastStream().listen(
      (event) {
        if (event is Map && _session != null) {
          final type = event['type'] as String?;
          final elapsedMs = event['elapsedMs'] as int? ?? 0;
          final chunkIndex = event['chunkIndex'] as int? ?? 1;
          final savedFiles = event['savedFiles'] as int? ?? 0;

          _session!.elapsed = Duration(milliseconds: elapsedMs);
          _session!.chunkIndex = chunkIndex;
          _session!.savedFiles = savedFiles;
          _sessionStream.add(_session);

          if (type == 'stopped') {
            _finalizeStop();
          }
        }
      },
      onError: (error) {
        // Native error — hentikan sesi di Dart side
        _finalizeStop();
      },
    );
  }

  Future<void> stopRecording() async {
    if (_state != RecordingState.recording) return;
    _setState(RecordingState.stopping);

    // Kirim perintah stop ke native — native akan push event 'stopped'
    // yang akan trigger _finalizeStop() via _listenToNativeEvents
    try {
      await _schedulerChannel.invokeMethod('stopRecording');
    } catch (_) {
      // Jika channel gagal, finalize langsung
      _finalizeStop();
    }
  }

  void _finalizeStop() {
    _eventSub?.cancel();
    _eventSub = null;
    _elapsedTimer?.cancel();

    WakelockPlus.disable();

    _session = null;
    _sessionStream.add(null);
    _setState(RecordingState.idle);
  }

  void _setState(RecordingState s) {
    _state = s;
    _stateStream.add(s);
  }

  void dispose() {
    _eventSub?.cancel();
    _elapsedTimer?.cancel();
    _sessionStream.close();
    _stateStream.close();
  }
}