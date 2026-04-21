package com.remtekindo.cctv

import android.annotation.SuppressLint
import android.content.Context
import android.hardware.camera2.*
import android.media.MediaRecorder
import android.os.Build
import android.os.Handler
import android.os.HandlerThread
import android.util.Log
import io.flutter.plugin.common.EventChannel
import java.io.File
import java.text.SimpleDateFormat
import java.util.*

/**
 * CameraRecorderPlugin
 *
 * Mengelola Camera2 + MediaRecorder sepenuhnya di native layer.
 * Flutter tidak lagi punya akses langsung ke kamera — semua rekaman
 * berjalan di sini, termasuk saat layar mati atau app di background.
 *
 * Komunikasi ke Flutter:
 * - EventChannel "com.remtekindo.cctv/recorder_events" untuk push status
 * - MethodChannel "com.remtekindo.cctv/scheduler" untuk terima perintah
 *   start/stop (sudah ada di MainActivity)
 *
 * Output: /storage/emulated/0/DCIM/SpyVideoCam/chunk_NNN_YYYYMMDD_HHmmss.mp4
 *
 * Catatan kompatibilitas:
 * Beberapa device OPPO/OnePlus menolak TEMPLATE_RECORD via Camera2.
 * Kode ini mencoba TEMPLATE_RECORD terlebih dahulu, lalu fallback ke
 * TEMPLATE_PREVIEW jika gagal. Keduanya menghasilkan rekaman yang valid
 * karena output tetap ke MediaRecorder surface.
 */
class CameraRecorderPlugin(private val context: Context) {

    companion object {
        private const val TAG = "CameraRecorderPlugin"
        private const val OUTPUT_DIR = "/storage/emulated/0/DCIM/SpyVideoCam"
        private const val CHUNK_DURATION_MS = 10 * 60 * 1000L  // 10 menit
        private const val MAX_DURATION_MS = 6 * 60 * 60 * 1000L  // 6 jam
    }

    // ─── Camera2 ────────────────────────────────────────────────────────
    private var cameraDevice: CameraDevice? = null
    private var captureSession: CameraCaptureSession? = null
    private var mediaRecorder: MediaRecorder? = null

    private val cameraThread = HandlerThread("CameraThread").also { it.start() }
    private val cameraHandler = Handler(cameraThread.looper)

    // ─── State ───────────────────────────────────────────────────────────
    private var isRecording = false
    private var isScheduled = false
    private var chunkIndex = 1
    private var savedFiles = 0
    private var sessionStartMs = 0L
    private var chunkStartMs = 0L

    // ─── Timers ──────────────────────────────────────────────────────────
    private val chunkHandler = Handler(android.os.Looper.getMainLooper())
    private val elapsedHandler = Handler(android.os.Looper.getMainLooper())
    private val maxDurationHandler = Handler(android.os.Looper.getMainLooper())

    private val chunkRunnable = Runnable { rotateChunk() }
    private val elapsedRunnable = object : Runnable {
        override fun run() {
            if (isRecording) {
                pushStatus()
                elapsedHandler.postDelayed(this, 1000)
            }
        }
    }
    private val maxDurationRunnable = Runnable { stopRecording() }

    // ─── EventChannel sink ───────────────────────────────────────────────
    var eventSink: EventChannel.EventSink? = null

    // ─── Public API ──────────────────────────────────────────────────────

    @SuppressLint("MissingPermission")
    fun startRecording(scheduled: Boolean) {
        if (isRecording) return
        isScheduled = scheduled
        chunkIndex = 1
        savedFiles = 0
        sessionStartMs = System.currentTimeMillis()

        ensureOutputDir()

        val cameraManager = context.getSystemService(Context.CAMERA_SERVICE) as CameraManager
        val cameraId = getBackCameraId(cameraManager) ?: run {
            pushError("Kamera belakang tidak ditemukan")
            return
        }

        cameraManager.openCamera(cameraId, object : CameraDevice.StateCallback() {
            override fun onOpened(camera: CameraDevice) {
                cameraDevice = camera
                startChunk()
            }

            override fun onDisconnected(camera: CameraDevice) {
                camera.close()
                cameraDevice = null
                if (isRecording) pushError("Kamera terputus")
            }

            override fun onError(camera: CameraDevice, error: Int) {
                camera.close()
                cameraDevice = null
                pushError("Error kamera: $error")
            }
        }, cameraHandler)
    }

    fun stopRecording() {
        if (!isRecording) return
        isRecording = false

        cancelTimers()

        try {
            captureSession?.stopRepeating()
            captureSession?.close()
        } catch (e: Exception) {
            Log.w(TAG, "stopRepeating error: ${e.message}")
        }

        try {
            mediaRecorder?.stop()
            mediaRecorder?.reset()
            savedFiles++
        } catch (e: Exception) {
            Log.w(TAG, "mediaRecorder stop error: ${e.message}")
        }

        cameraDevice?.close()
        cameraDevice = null
        captureSession = null

        pushStopped()
    }

    fun dispose() {
        stopRecording()
        cameraThread.quitSafely()
    }

    // ─── Internal ────────────────────────────────────────────────────────

    private fun startChunk() {
        val camera = cameraDevice ?: return
        chunkStartMs = System.currentTimeMillis()

        val outputPath = buildOutputPath()
        mediaRecorder = buildMediaRecorder(outputPath)

        try {
            mediaRecorder!!.prepare()
        } catch (e: Exception) {
            pushError("MediaRecorder prepare error: ${e.message}")
            return
        }

        val surface = mediaRecorder!!.surface

        camera.createCaptureSession(
            listOf(surface),
            object : CameraCaptureSession.StateCallback() {
                override fun onConfigured(session: CameraCaptureSession) {
                    captureSession = session

                    // Coba TEMPLATE_RECORD dulu, fallback ke TEMPLATE_PREVIEW
                    // untuk device OPPO/OnePlus yang menolak TEMPLATE_RECORD
                    val request = try {
                        camera.createCaptureRequest(CameraDevice.TEMPLATE_RECORD)
                            .apply { addTarget(surface) }
                            .build()
                    } catch (e: CameraAccessException) {
                        Log.w(TAG, "TEMPLATE_RECORD gagal (${e.message}), fallback ke TEMPLATE_PREVIEW")
                        try {
                            camera.createCaptureRequest(CameraDevice.TEMPLATE_PREVIEW)
                                .apply { addTarget(surface) }
                                .build()
                        } catch (e2: CameraAccessException) {
                            pushError("Tidak bisa membuat capture request: ${e2.message}")
                            return
                        }
                    }

                    try {
                        session.setRepeatingRequest(request, null, cameraHandler)
                        mediaRecorder?.start()
                        isRecording = true

                        if (chunkIndex == 1) {
                            startTimers()
                            pushStatus()
                        }
                    } catch (e: Exception) {
                        pushError("setRepeatingRequest error: ${e.message}")
                    }
                }

                override fun onConfigureFailed(session: CameraCaptureSession) {
                    pushError("CaptureSession configure gagal")
                }
            },
            cameraHandler
        )
    }

    private fun rotateChunk() {
        if (!isRecording) return

        try {
            captureSession?.stopRepeating()
            captureSession?.close()
            mediaRecorder?.stop()
            mediaRecorder?.reset()
            savedFiles++
            chunkIndex++
        } catch (e: Exception) {
            Log.w(TAG, "rotateChunk error: ${e.message}")
        }

        captureSession = null
        pushStatus()
        startChunk()
        chunkHandler.postDelayed(chunkRunnable, CHUNK_DURATION_MS)
    }

    private fun buildMediaRecorder(outputPath: String): MediaRecorder {
        return if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
            MediaRecorder(context)
        } else {
            @Suppress("DEPRECATION")
            MediaRecorder()
        }.apply {
            setAudioSource(MediaRecorder.AudioSource.MIC)
            setVideoSource(MediaRecorder.VideoSource.SURFACE)
            setOutputFormat(MediaRecorder.OutputFormat.MPEG_4)
            setAudioEncoder(MediaRecorder.AudioEncoder.AAC)
            setVideoEncoder(MediaRecorder.VideoEncoder.H264)
            setVideoSize(640, 480)
            setVideoFrameRate(24)
            setVideoEncodingBitRate(1_500_000)
            setAudioEncodingBitRate(128_000)
            setAudioSamplingRate(44100)
            setOutputFile(outputPath)
        }
    }

    private fun buildOutputPath(): String {
        val ts = SimpleDateFormat("yyyyMMdd_HHmmss", Locale.US).format(Date())
        val idx = chunkIndex.toString().padStart(3, '0')
        return "$OUTPUT_DIR/chunk_${idx}_$ts.mp4"
    }

    private fun ensureOutputDir() {
        val dir = File(OUTPUT_DIR)
        if (!dir.exists()) dir.mkdirs()
    }

    private fun getBackCameraId(manager: CameraManager): String? {
        for (id in manager.cameraIdList) {
            val chars = manager.getCameraCharacteristics(id)
            if (chars.get(CameraCharacteristics.LENS_FACING) ==
                CameraCharacteristics.LENS_FACING_BACK) return id
        }
        return null
    }

    // ─── Timers ──────────────────────────────────────────────────────────

    private fun startTimers() {
        chunkHandler.postDelayed(chunkRunnable, CHUNK_DURATION_MS)
        elapsedHandler.post(elapsedRunnable)
        maxDurationHandler.postDelayed(maxDurationRunnable, MAX_DURATION_MS)
    }

    private fun cancelTimers() {
        chunkHandler.removeCallbacks(chunkRunnable)
        elapsedHandler.removeCallbacks(elapsedRunnable)
        maxDurationHandler.removeCallbacks(maxDurationRunnable)
    }

    // ─── EventChannel push ───────────────────────────────────────────────

    private fun pushStatus() {
        val elapsed = System.currentTimeMillis() - sessionStartMs
        val map = mapOf(
            "type" to "status",
            "isRecording" to isRecording,
            "isScheduled" to isScheduled,
            "chunkIndex" to chunkIndex,
            "savedFiles" to savedFiles,
            "elapsedMs" to elapsed,
        )
        android.os.Handler(android.os.Looper.getMainLooper()).post {
            eventSink?.success(map)
        }
    }

    private fun pushStopped() {
        val map = mapOf(
            "type" to "stopped",
            "isRecording" to false,
            "chunkIndex" to chunkIndex,
            "savedFiles" to savedFiles,
            "elapsedMs" to (System.currentTimeMillis() - sessionStartMs),
        )
        android.os.Handler(android.os.Looper.getMainLooper()).post {
            eventSink?.success(map)
        }
    }

    private fun pushError(message: String) {
        Log.e(TAG, message)
        android.os.Handler(android.os.Looper.getMainLooper()).post {
            eventSink?.error("RECORDER_ERROR", message, null)
        }
    }
}