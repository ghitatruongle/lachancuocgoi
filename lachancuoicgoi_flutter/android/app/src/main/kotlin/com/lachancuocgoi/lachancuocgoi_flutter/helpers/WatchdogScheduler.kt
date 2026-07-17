package com.lachancuocgoi.lachancuocgoi_flutter.helpers

import android.app.AlarmManager
import android.app.PendingIntent
import android.content.Context
import android.content.Intent
import android.util.Log
import com.lachancuocgoi.lachancuocgoi_flutter.receiver.ServiceWatchdogReceiver

/**
 * Watchdog scheduler extracted from `BackgroundMonitoringService.kt` (Wave 3 refactor).
 *
 * Owns AlarmManager scheduling for the [ServiceWatchdogReceiver] heartbeat and
 * the SharedPreferences persistence of the "monitoring was active" flag plus
 * the last-known start params (phone number, speakerphone). The persisted flag
 * is what lets the watchdog receiver decide to resurrect the service after a
 * system kill; the params let the resurrection re-attach the same session.
 *
 * Public constants and the static accessors ([wasMonitoringActive],
 * [lastStartParams], [clearMonitoringActiveFlag]) deliberately stay on the
 * service companion, because [ServiceWatchdogReceiver] reads them from there.
 * This class only relocates the *instance* scheduling/persistence methods,
 * which previously lived as private methods on the service and were only ever
 * called through `this`.
 *
 * @param service the owning service, used as both [Context] and the AlarmManager
 *                client. All prefs are opened with
 *                [BackgroundMonitoringService.WATCHDOG_PREFS].
 */
class WatchdogScheduler(private val service: android.app.Service) {

    private val alarmManager: AlarmManager =
        service.getSystemService(Context.ALARM_SERVICE) as AlarmManager

    private fun watchdogIntent(): Intent =
        Intent(service, ServiceWatchdogReceiver::class.java).apply {
            action = ServiceWatchdogReceiver.ACTION_CHECK_SERVICE
        }

    /**
     * Schedule the higher-priority exact watchdog. Uses [AlarmManager.setAlarmClock]
     * which is exempt from the SCHEDULE_EXACT_ALARM permission and survives Doze.
     * Intended for the post-`onTaskRemoved` path where reliability matters most.
     */
    fun scheduleExact(intervalMinutes: Int) {
        val intent = watchdogIntent()
        val pendingIntent = PendingIntent.getBroadcast(
            service, 1, intent,
            PendingIntent.FLAG_IMMUTABLE or PendingIntent.FLAG_UPDATE_CURRENT,
        )
        val triggerAt = System.currentTimeMillis() + intervalMinutes * 60 * 1000L
        try {
            // Bug fix: always use setAlarmClock (exempt from SCHEDULE_EXACT_ALARM
            // permission). Previously, code checked canScheduleExactAlarms()
            // which is redundant for setAlarmClock() and caused fallback to
            // less reliable setAndAllowWhileIdle().
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

    /**
     * Schedule the battery-friendly inexact repeating watchdog. Intended for the
     * steady-state heartbeat during normal monitoring.
     */
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

    /**
     * Cancel both alarm request codes (0 = inexact, 1 = exact). Previously only
     * code 0 was cancelled, leaking the higher-priority setAlarmClock PendingIntent.
     */
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
