import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'dart:io';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:flutter_foreground_task/flutter_foreground_task.dart';
import 'screens/home_screen.dart';

/// Meminta izin awal saat app pertama kali dibuka.
/// Logic ini konsisten dengan requestPermissions() di RecordingService —
/// keduanya menggunakan API-aware branching yang sama.
Future<void> requestPermissions() async {
  if (!Platform.isAndroid) return;

  final androidInfo = await DeviceInfoPlugin().androidInfo;
  final sdkInt = androidInfo.version.sdkInt;

  // Camera & microphone — wajib untuk rekam
  await [
    Permission.camera,
    Permission.microphone,
  ].request();

  // Storage permission — sesuai API level
  if (sdkInt >= 33) {
    // Android 13+: izin granular media
    await Permission.videos.request();
  } else if (sdkInt >= 30) {
    // Android 11–12: manageExternalStorage untuk akses DCIM penuh
    if (!(await Permission.manageExternalStorage.isGranted)) {
      await Permission.manageExternalStorage.request();
    }
  } else {
    // Android 10 ke bawah
    await Permission.storage.request();
  }

  // Exact alarm — diperlukan untuk rekam terjadwal di Android 12+
  // Blok ini terpisah dari storage permission di atas
  if (sdkInt >= 31) {
    await Permission.scheduleExactAlarm.request();
  }
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Minta semua izin di awal agar dialog tidak muncul saat user menekan rekam
  await requestPermissions();

  SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
  runApp(const SpyVideoCamApp());
}

class SpyVideoCamApp extends StatelessWidget {
  const SpyVideoCamApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Spy VideoCam',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF1A1A1A),
          brightness: Brightness.light,
        ),
        useMaterial3: true,
        fontFamily: 'sans-serif',
      ),
      home: const WithForegroundTask(child: HomeScreen()),
    );
  }
}