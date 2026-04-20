package com.remtekindo.cctv

import android.app.AlarmManager
import android.app.PendingIntent
import android.app.Service
import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.os.Build
import android.os.IBinder

class BootReceiver : BroadcastReceiver() {
    override fun onReceive(context: Context, intent: Intent) {
        if (intent.action != Intent.ACTION_BOOT_COMPLETED &&
            intent.action != "android.intent.action.QUICKBOOT_POWERON") return

        val prefs = context.getSharedPreferences("cctv_schedule", Context.MODE_PRIVATE)
        val scheduledTime = prefs.getLong("scheduled_time_ms", -1L)
        if (scheduledTime == -1L) return

        val now = System.currentTimeMillis()
        if (scheduledTime > now) {
            SchedulerService.setAlarm(context, scheduledTime)
        } else {
            prefs.edit().remove("scheduled_time_ms").apply()
        }
    }
}

class SchedulerReceiver : BroadcastReceiver() {
    override fun onReceive(context: Context, intent: Intent) {
        context.getSharedPreferences("cctv_schedule", Context.MODE_PRIVATE)
            .edit().remove("scheduled_time_ms").apply()

        VideoForegroundService.startService(context, isScheduled = true)
    }
}

class SchedulerService : Service() {
    companion object {
        private const val ALARM_REQUEST_CODE = 9001

        fun setAlarm(context: Context, triggerAtMs: Long) {
            val intent = Intent(context, SchedulerReceiver::class.java)
            val pending = PendingIntent.getBroadcast(
                context,
                ALARM_REQUEST_CODE,
                intent,
                PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
            )

            val alarm = context.getSystemService(Context.ALARM_SERVICE) as AlarmManager
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
                alarm.setExactAndAllowWhileIdle(AlarmManager.RTC_WAKEUP, triggerAtMs, pending)
            } else {
                alarm.setExact(AlarmManager.RTC_WAKEUP, triggerAtMs, pending)
            }

            context.getSharedPreferences("cctv_schedule", Context.MODE_PRIVATE)
                .edit().putLong("scheduled_time_ms", triggerAtMs).apply()
        }

        fun cancelAlarm(context: Context) {
            val intent = Intent(context, SchedulerReceiver::class.java)
            val pending = PendingIntent.getBroadcast(
                context,
                ALARM_REQUEST_CODE,
                intent,
                PendingIntent.FLAG_NO_CREATE or PendingIntent.FLAG_IMMUTABLE
            )
            pending?.let {
                val alarm = context.getSystemService(Context.ALARM_SERVICE) as AlarmManager
                alarm.cancel(it)
                it.cancel()
            }
            context.getSharedPreferences("cctv_schedule", Context.MODE_PRIVATE)
                .edit().remove("scheduled_time_ms").apply()
        }
    }

    override fun onBind(intent: Intent?): IBinder? = null

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        val action = intent?.action ?: return START_NOT_STICKY
        when (action) {
            "SCHEDULE" -> {
                val delayMs = intent.getLongExtra("delay_ms", -1L)
                if (delayMs > 0) {
                    setAlarm(this, System.currentTimeMillis() + delayMs)
                }
            }
            "CANCEL" -> cancelAlarm(this)
        }
        stopSelf()
        return START_NOT_STICKY
    }
}