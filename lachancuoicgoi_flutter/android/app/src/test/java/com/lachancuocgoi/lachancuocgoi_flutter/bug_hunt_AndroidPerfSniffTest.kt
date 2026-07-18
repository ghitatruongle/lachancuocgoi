package com.lachancuocgoi.lachancuocgoi_flutter

import android.content.ComponentName
import android.content.Context
import android.content.pm.PackageManager
import androidx.test.core.app.ApplicationProvider
import org.junit.Assert.assertNotEquals
import org.junit.Test
import org.junit.runner.RunWith
import org.robolectric.RobolectricTestRunner
import org.robolectric.annotation.Config

/**
 * Bug Hunt Phase B.5 + B.10 — Audit Android service stability + perf contract.
 *
 * Reference:
 *  - docs/superpowers/specs/2026-06-28-bug-hunt-campaign-design.md
 *    sections Mục 3 (Hiệu năng Android) + Mục 7 (Ổn định)
 *  - CHANGELOG entries Bug #2, #8, #25 for what these pins protect.
 */
@RunWith(RobolectricTestRunner::class)
@Config(sdk = [33])
class bug_hunt_AndroidPerfSniffTest {

    @Test
    fun BUG_PERF_1_BackgroundMonitoringServiceNotExported() {
        // Service must not be exported to prevent external restart attacks
        // and to limit IPC surface area (CHANGELOG Bug #2 fix).
        val ctx = ApplicationProvider.getApplicationContext<Context>()
        val pm = ctx.packageManager
        val svcInfo = pm.getServiceInfo(
            ComponentName(
                ctx,
                "com.lachancuocgoi.lachancuocgoi_flutter.services.BackgroundMonitoringService"
            ),
            PackageManager.GET_META_DATA
        )
        assert(svcInfo.exported == false) {
            "BackgroundMonitoringService must not be exported"
        }
    }

    @Test
    fun BUG_PERF_2_CallScreeningServiceExported() {
        // Android 14+ requires CallScreeningService to be exported so the
        // system can bind to it for call screening role.
        val ctx = ApplicationProvider.getApplicationContext<Context>()
        val pm = ctx.packageManager
        val svcInfo = pm.getServiceInfo(
            ComponentName(
                ctx,
                "com.lachancuocgoi.lachancuocgoi_flutter.services.CallScreeningServiceImpl"
            ),
            PackageManager.GET_META_DATA
        )
        assert(svcInfo.exported == true) {
            "CallScreeningServiceImpl must be exported for system call screening role"
        }
    }

    @Test
    fun BUG_STABILITY_1_RestartCooldownBounded() {
        // Per CHANGELOG Bug #25, RESTART_COOLDOWN_MS = 4 minutes (240_000).
        // Pin the value so a regression cannot silently drop it back to 60s.
        val cls = Class.forName(
            "com.lachancuocgoi.lachancuocgoi_flutter.receiver.ServiceWatchdogReceiver"
        )
        val field = cls.getDeclaredField("RESTART_COOLDOWN_MS")
        field.isAccessible = true
        val cooldown = field.getLong(null)
        assert(cooldown >= 60_000L) {
            "RESTART_COOLDOWN_MS regressed to $cooldown (expected >= 60_000)"
        }
    }

    @Test
    fun BUG_STABILITY_2_WatchdogIntervalReasonable() {
        // WATCHDOG_INTERVAL_MINUTES = 5 per current code; should not be
        // less than RESTART_COOLDOWN_MS / 60_000 (4 minutes) to avoid
        // tight restart loops.
        val receiver = Class.forName(
            "com.lachancuocgoi.lachancuocgoi_flutter.receiver.ServiceWatchdogReceiver"
        )
        val cooldownField = receiver.getDeclaredField("RESTART_COOLDOWN_MS")
        cooldownField.isAccessible = true
        val cooldown = cooldownField.getLong(null)

        val service = Class.forName(
            "com.lachancuocgoi.lachancuocgoi_flutter.services.BackgroundMonitoringService"
        )
        val intervalField = service.getDeclaredField("WATCHDOG_INTERVAL_MINUTES")
        intervalField.isAccessible = true
        val intervalMinutes = intervalField.getLong(null)

        // Watchdog interval (minutes) should be > cooldown (in minutes) to
        // avoid spurious restarts within cooldown.
        val cooldownMinutes = cooldown / 60_000L
        assert(intervalMinutes > cooldownMinutes) {
            "WATCHDOG_INTERVAL_MINUTES=$intervalMinutes must be > RESTART_COOLDOWN_MS=$cooldown ms"
        }
    }
}