package com.lachancuocgoi.lachancuocgoi_flutter.helpers

import android.app.AlarmManager
import android.app.PendingIntent
import android.content.Context
import android.content.Intent
import android.util.Log
import com.lachancuocgoi.lachancuocgoi_flutter.receiver.ServiceWatchdogReceiver

class WatchdogScheduler(private val service: android.app.Service) {

    private val alarmManager: AlarmManager =
        service.getSystemService(Context.ALARM_SERVICE) as AlarmManager

    private fun watchdogIntent(): Intent =
        Intent(service, ServiceWatchdogReceiver::class.java).apply {
            action = ServiceWatchdogReceiver.ACTION_CHECK_SERVICE
        }

    fun scheduleExact(intervalMinutes: Int) {
        val intent = watchdogIntent()
        val pendingIntent = PendingIntent.getBroadcast(
            service, 1, intent,
            PendingIntent.FLAG_IMMUTABLE or PendingIntent.FLAG_UPDATE_CURRENT,
        )
        val triggerAt = System.currentTimeMillis() + intervalMinutes * 60 * 1000L
        try {

            alarmManager.setAlarmClock(
                AlarmManager.AlarmClockInfo(triggerAt, pendingIntent),
                pendingIntent,
            )
        } catch (e: SecurityException) {
            Log.w(TAG, "Cannot schedule exact alarm, falling back", e)
            alarmManager.setAndAllowWhileIdle(
                AlarmManager.RTC_WAKEUP, triggerAt, pendingIntent,
            )
        }
        Log.d(TAG, "Exact watchdog alarm scheduled at +${intervalMinutes}m.")
    }

    fun scheduleInexact(intervalMinutes: Int) {
        val intent = watchdogIntent()
        val pendingIntent = PendingIntent.getBroadcast(
            service, 0, intent,
            PendingIntent.FLAG_IMMUTABLE or PendingIntent.FLAG_UPDATE_CURRENT,
        )
        val intervalMs = intervalMinutes * 60 * 1000L
        alarmManager.setInexactRepeating(
            AlarmManager.RTC_WAKEUP,
            System.currentTimeMillis() + intervalMs,
            intervalMs,
            pendingIntent,
        )
        Log.d(TAG, "Watchdog alarm scheduled every ${intervalMinutes}m.")
    }

    fun cancel() {
        val intent = watchdogIntent()
        for (requestCode in intArrayOf(0, 1)) {
            val pendingIntent = PendingIntent.getBroadcast(
                service, requestCode, intent,
                PendingIntent.FLAG_IMMUTABLE or
                    PendingIntent.FLAG_UPDATE_CURRENT or
                    PendingIntent.FLAG_NO_CREATE,
            )
            pendingIntent?.let {
                alarmManager.cancel(it)
                it.cancel()
            }
        }
        Log.d(TAG, "Watchdog alarm cancelled (request codes 0 and 1).")
    }

    companion object {
        private const val TAG = "WatchdogScheduler"
    }
}

