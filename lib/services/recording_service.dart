import 'dart:async';
import 'dart:io';
import 'package:camera/camera.dart';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:path_provider/path_provider.dart';
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

class RecordingService {
  static final RecordingService _instance = RecordingService._internal();
  factory RecordingService() => _instance;
  RecordingService._internal();

  CameraController? _cameraController;
  Timer? _chunkTimer;
  Timer? _elapsedTimer;
  Timer? _maxDurationTimer;

  RecordingState _state = RecordingState.idle;
  RecordingSession? _session;

  static const Duration chunkDuration = Duration(minutes: 10);
  static const Duration maxAllowedDuration = Duration(hours: 6);

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
      // Non-Android: cukup minta camera & microphone
      final camera = await Permission.camera.request();
      final audio = await Permission.microphone.request();
      return camera.isGranted && audio.isGranted;
    }

    final androidInfo = await DeviceInfoPlugin().androidInfo;
    final sdkInt = androidInfo.version.sdkInt;

    // Minta camera & microphone — wajib untuk rekam
    final results = await [
      Permission.camera,
      Permission.microphone,
    ].request();

    final cameraGranted = results[Permission.camera]?.isGranted ?? false;
    final audioGranted = results[Permission.microphone]?.isGranted ?? false;

    // Storage permission — sesuai API level, tapi tidak memblokir rekaman
    // jika ditolak (file tetap bisa disimpan ke DCIM via path langsung)
    if (sdkInt >= 33) {
      // Android 13+: gunakan izin granular media
      await Permission.videos.request();
    } else if (sdkInt >= 30) {
      // Android 11–12: manageExternalStorage untuk akses DCIM penuh
      if (!(await Permission.manageExternalStorage.isGranted)) {
        await Permission.manageExternalStorage.request();
      }
    } else {
      // Android 10 ke bawah: READ/WRITE_EXTERNAL_STORAGE
      await Permission.storage.request();
    }

    // Hanya camera & audio yang menjadi penentu boleh rekam atau tidak
    return cameraGranted && audioGranted;
  }

  Future<void> initCamera() async {
    if (_cameraController != null) return;
    final cameras = await availableCameras();
    if (cameras.isEmpty) throw Exception('Tidak ada kamera tersedia');

    final back = cameras.firstWhere(
      (c) => c.lensDirection == CameraLensDirection.back,
      orElse: () => cameras.first,
    );

    _cameraController = CameraController(
      back,
      ResolutionPreset.low, // 360p untuk hemat baterai
      enableAudio: true,
      imageFormatGroup: ImageFormatGroup.jpeg,
    );

    await _cameraController!.initialize();
  }

  Future<void> startRecording({required bool isScheduled}) async {
    if (_state != RecordingState.idle) return;

    final granted = await requestPermissions();
    if (!granted) throw Exception('Izin kamera/audio ditolak');

    await initCamera();
    await WakelockPlus.enable();

    _session = RecordingSession(
      startTime: DateTime.now(),
      isScheduled: isScheduled,
      maxDuration: maxAllowedDuration,
    );

    _setState(RecordingState.recording);
    _sessionStream.add(_session);

    await _startChunk();
    _startElapsedTimer();
    _startMaxDurationTimer();
  }

  Future<void> _startChunk() async {
    if (_cameraController == null || _state != RecordingState.recording) return;

    final dir = await _getOutputDirectory();
    final timestamp = _formatTimestamp(DateTime.now());
    final chunkIdx = _session!.chunkIndex.toString().padLeft(3, '0');
    final path = '${dir.path}/chunk_${chunkIdx}_$timestamp.mp4';

    await _cameraController!.startVideoRecording();

    _chunkTimer?.cancel();
    _chunkTimer = Timer(chunkDuration, () async {
      await _rotateChunk(path);
    });
  }

  Future<void> _rotateChunk(String currentPath) async {
    if (_state != RecordingState.recording) return;

    try {
      final file = await _cameraController!.stopVideoRecording();
      await _saveToGallery(file.path, currentPath);

      _session!.savedFiles++;
      _session!.chunkIndex++;
      _sessionStream.add(_session);

      await _startChunk();
    } catch (e) {
      // ignore chunk rotation error, lanjut chunk baru
    }
  }

  void _startElapsedTimer() {
    _elapsedTimer?.cancel();
    _elapsedTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (_session != null && _state == RecordingState.recording) {
        _session!.elapsed = DateTime.now().difference(_session!.startTime);
        _sessionStream.add(_session);
      }
    });
  }

  void _startMaxDurationTimer() {
    _maxDurationTimer?.cancel();
    _maxDurationTimer = Timer(maxAllowedDuration, () async {
      await stopRecording();
    });
  }

  Future<void> stopRecording() async {
    if (_state != RecordingState.recording) return;
    _setState(RecordingState.stopping);

    _chunkTimer?.cancel();
    _elapsedTimer?.cancel();
    _maxDurationTimer?.cancel();

    try {
      if (_cameraController != null &&
          _cameraController!.value.isRecordingVideo) {
        final file = await _cameraController!.stopVideoRecording();
        final dir = await _getOutputDirectory();
        final timestamp = _formatTimestamp(DateTime.now());
        final chunkIdx = _session!.chunkIndex.toString().padLeft(3, '0');
        final path = '${dir.path}/chunk_${chunkIdx}_$timestamp.mp4';
        await _saveToGallery(file.path, path);
        _session!.savedFiles++;
      }
    } catch (_) {}

    await _cameraController?.dispose();
    _cameraController = null;
    await WakelockPlus.disable();

    _session = null;
    _sessionStream.add(null);
    _setState(RecordingState.idle);
  }

  Future<Directory> _getOutputDirectory() async {
    Directory? dir;
    if (Platform.isAndroid) {
      dir = Directory('/storage/emulated/0/DCIM/SpyVideoCam');
    } else {
      dir = await getApplicationDocumentsDirectory();
    }
    if (!dir.existsSync()) dir.createSync(recursive: true);
    return dir;
  }

  Future<void> _saveToGallery(String tempPath, String finalPath) async {
    final tempFile = File(tempPath);
    if (await tempFile.exists()) {
      await tempFile.copy(finalPath);
      await tempFile.delete();
    }
  }

  String _formatTimestamp(DateTime dt) {
    return '${dt.year}${_pad(dt.month)}${_pad(dt.day)}_'
        '${_pad(dt.hour)}${_pad(dt.minute)}${_pad(dt.second)}';
  }

  String _pad(int n) => n.toString().padLeft(2, '0');

  void _setState(RecordingState s) {
    _state = s;
    _stateStream.add(s);
  }

  void dispose() {
    _chunkTimer?.cancel();
    _elapsedTimer?.cancel();
    _maxDurationTimer?.cancel();
    _sessionStream.close();
    _stateStream.close();
    _cameraController?.dispose();
  }
}