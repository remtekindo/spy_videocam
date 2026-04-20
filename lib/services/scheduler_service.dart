import 'dart:async';
import 'package:flutter/services.dart';

class SchedulerService {
  static final SchedulerService _instance = SchedulerService._internal();
  factory SchedulerService() => _instance;
  SchedulerService._internal();

  static const _channel = MethodChannel('com.remtekindo.cctv/scheduler');

  // Jadwalkan rekaman pada jam & menit tertentu hari ini
  Future<void> scheduleRecording({
    required int hour,
    required int minute,
  }) async {
    final now = DateTime.now();
    final scheduled = DateTime(now.year, now.month, now.day, hour, minute);

    // Jika jam sudah lewat hari ini, tolak
    if (scheduled.isBefore(now)) {
      throw Exception('Jam yang dipilih sudah lewat hari ini');
    }

    final delayMs = scheduled.difference(now).inMilliseconds;

    try {
      await _channel.invokeMethod('scheduleRecording', {
        'delayMs': delayMs,
        'scheduledTime': scheduled.toIso8601String(),
      });
    } on MissingPluginException {
      // Fallback: gunakan Timer Dart langsung (untuk dev/test di emulator)
      Timer(Duration(milliseconds: delayMs), () {
        _channel.invokeMethod('startRecordingNow').catchError((_) {});
      });
    }
  }

  Future<void> cancelSchedule() async {
    try {
      await _channel.invokeMethod('cancelSchedule');
    } on MissingPluginException {
      // ignore di emulator
    }
  }

  // Format jam untuk display: "10:00 WIB"
  static String formatScheduleTime(int hour, int minute) {
    final h = hour.toString().padLeft(2, '0');
    final m = minute.toString().padLeft(2, '0');
    return '$h:$m WIB';
  }

  // Hitung selisih waktu dari sekarang ke jam yang dipilih
  static Duration timeUntil(int hour, int minute) {
    final now = DateTime.now();
    final target = DateTime(now.year, now.month, now.day, hour, minute);
    if (target.isBefore(now)) return Duration.zero;
    return target.difference(now);
  }
}