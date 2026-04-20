package com.remtekindo.cctv

import android.content.Intent
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {

    private val schedulerChannel = "com.remtekindo.cctv/scheduler"
    private val recorderEventChannel = "com.remtekindo.cctv/recorder_events"

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        // ─── EventChannel — push status recorder ke Flutter ───────────────
        // Dipasang ke VideoForegroundService.eventSink agar CameraRecorderPlugin
        // bisa mengirim status (elapsed, chunk, savedFiles) ke Dart side
        EventChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            recorderEventChannel
        ).setStreamHandler(object : EventChannel.StreamHandler {
            override fun onListen(arguments: Any?, sink: EventChannel.EventSink?) {
                VideoForegroundService.eventSink = sink
            }

            override fun onCancel(arguments: Any?) {
                VideoForegroundService.eventSink = null
            }
        })

        // ─── MethodChannel — terima perintah dari Flutter ─────────────────
        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            schedulerChannel
        ).setMethodCallHandler { call, result ->
            when (call.method) {
                "scheduleRecording" -> {
                    val delayMs = call.argument<Long>("delayMs") ?: 0L
                    val intent = Intent(this, SchedulerService::class.java).apply {
                        action = "SCHEDULE"
                        putExtra("delay_ms", delayMs)
                    }
                    startService(intent)
                    result.success(null)
                }
                "cancelSchedule" -> {
                    val intent = Intent(this, SchedulerService::class.java).apply {
                        action = "CANCEL"
                    }
                    startService(intent)
                    result.success(null)
                }
                "startRecordingNow" -> {
                    VideoForegroundService.startService(this, isScheduled = true)
                    result.success(null)
                }
                "stopRecording" -> {
                    VideoForegroundService.stopService(this)
                    result.success(null)
                }
                else -> result.notImplemented()
            }
        }
    }
}