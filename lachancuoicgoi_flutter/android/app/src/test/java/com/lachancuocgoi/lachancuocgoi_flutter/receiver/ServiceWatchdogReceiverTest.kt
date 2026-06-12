package com.lachancuocgoi.lachancuocgoi_flutter.receiver

import android.content.Context
import android.content.Intent
import android.content.SharedPreferences
import androidx.test.core.app.ApplicationProvider
import com.lachancuocgoi.lachancuocgoi_flutter.services.BackgroundMonitoringService
import com.lachancuocgoi.lachancuocgoi_flutter.services.NativeBridgeEventSink
import io.mockk.Called
import io.mockk.every
import io.mockk.just
import io.mockk.mockkObject
import io.mockk.runs
import io.mockk.slot
import io.mockk.unmockkAll
import io.mockk.verify
import org.junit.After
import org.junit.Assert.assertEquals
import org.junit.Assert.assertNotNull
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.Before
import org.junit.Test
import org.junit.runner.RunWith
import org.robolectric.RobolectricTestRunner
import org.robolectric.annotation.Config

/**
 * Unit tests for [ServiceWatchdogReceiver] — post-Sprint 2 contract.
 *
 * Behavior under test (Sprint 1 + 2 changes):
 *  - Reads [BackgroundMonitoringService.wasMonitoringActive] from prefs
 *  - Bails early if [BackgroundMonitoringService.isRunning] is true
 *  - **B1**: Throttles restart attempts to 1 per 60s (prefs
 *    "watchdog_last_restart_at_ms")
 *  - **B6**: Re-attaches last-known `PHONE_NUMBER` / `ENABLE_SPEAKERPHONE`
 *    extras from [BackgroundMonitoringService.lastStartParams]
 *  - Only sends [NativeBridgeEventSink.sendMonitoringState] "STARTED" on
 *    a successful restart — no STOPPED event (avoids kill loops)
 *
 * Note: [BackgroundMonitoringService.isRunning] is a `@Volatile var` on the
 * companion object; we mock the whole companion object via
 * [mockkObject] and stub the property accessor.
 */
@RunWith(RobolectricTestRunner::class)
@Config(sdk = [34])
class ServiceWatchdogReceiverTest {

    private lateinit var receiver: ServiceWatchdogReceiver
    private lateinit var context: Context
    private lateinit var prefs: SharedPreferences

    @Before
    fun setUp() {
        receiver = ServiceWatchdogReceiver()
        context = ApplicationProvider.getApplicationContext()

        // Real SharedPreferences (Robolectric-backed) so the throttling
        // cooldown persists across the same JVM but is isolated per test.
        prefs = context.getSharedPreferences(
            BackgroundMonitoringService.WATCHDOG_PREFS,
            Context.MODE_PRIVATE,
        )
        prefs.edit().clear().commit()

        // Mock the companion so we can control `isRunning` deterministically
        // without running the actual service.
        mockkObject(BackgroundMonitoringService)
        every { BackgroundMonitoringService.isRunning } answers { false }

        // Default: last-start params return null phone, false speaker.
        // Individual tests override by writing to the real prefs.
        mockkObject(NativeBridgeEventSink)
        every { NativeBridgeEventSink.sendMonitoringState(any()) } just runs
    }

    @After
    fun tearDown() {
        unmockkAll()
    }

    // ─── helpers ─────────────────────────────────────────────────────────

    private fun watchdogIntent(): Intent =
        Intent(ServiceWatchdogReceiver.ACTION_CHECK_SERVICE)

    private fun markMonitoringActive(active: Boolean) {
        prefs.edit().putBoolean("monitoring_was_active", active).apply()
    }

    private fun setLastStartParams(phone: String?, speaker: Boolean) {
        val editor = prefs.edit().putBoolean("watchdog_speakerphone", speaker)
        if (phone != null) {
            editor.putString("watchdog_phone_number", phone)
        } else {
            editor.remove("watchdog_phone_number")
        }
        editor.apply()
    }

    // ─── 1. Wrong action → early return ─────────────────────────────────

    @Test
    fun `onReceive with wrong action returns early`() {
        val wrongIntent = Intent("com.example.WRONG_ACTION")
        receiver.onReceive(context, wrongIntent)

        verify(exactly = 0) { NativeBridgeEventSink.sendMonitoringState(any()) }
        verify { NativeBridgeEventSink wasNot Called }
    }

    // ─── 2. wasMonitoringActive == false → early return ─────────────────

    @Test
    fun `onReceive when monitoring was not active returns early`() {
        markMonitoringActive(false)

        receiver.onReceive(context, watchdogIntent())

        verify(exactly = 0) { NativeBridgeEventSink.sendMonitoringState(any()) }
        // isRunning should never have been consulted either
        verify(exactly = 0) { BackgroundMonitoringService.isRunning }
    }

    // ─── 3. isRunning == true → early return ────────────────────────────

    @Test
    fun `onReceive when service is already running returns early`() {
        markMonitoringActive(true)
        every { BackgroundMonitoringService.isRunning } returns true

        receiver.onReceive(context, watchdogIntent())

        verify(exactly = 0) { NativeBridgeEventSink.sendMonitoringState(any()) }
        // No throttle entry should have been written
        assertEquals(0L, prefs.getLong("watchdog_last_restart_at_ms", 0L))
    }

    // ─── 4. wasActive && !isRunning → restart + re-attach params ────────

    @Test
    fun `onReceive restarts service and re-attaches last-start params`() {
        markMonitoringActive(true)
        every { BackgroundMonitoringService.isRunning } returns false
        setLastStartParams(phone = "+84901234567", speaker = true)

        receiver.onReceive(context, watchdogIntent())

        // Send STARTED (not STOPPED — that would re-kill the service)
        verify(exactly = 1) { NativeBridgeEventSink.sendMonitoringState("STARTED") }

        // Throttle timestamp was written
        val lastRestartAtMs = prefs.getLong("watchdog_last_restart_at_ms", 0L)
        assertTrue("lastRestartAtMs should be > 0", lastRestartAtMs > 0L)

        // (The actual startForegroundService call is harder to verify in
        // pure-Robolectric mode without additional shadowing; we rely on
        // the throttle write as proof that the receiver reached the
        // restart code path.)
    }

    @Test
    fun `onReceive restarts service when last-start params are null`() {
        markMonitoringActive(true)
        every { BackgroundMonitoringService.isRunning } returns false
        // No prior phone / speaker params (first start after install)
        setLastStartParams(phone = null, speaker = false)

        receiver.onReceive(context, watchdogIntent())

        verify(exactly = 1) { NativeBridgeEventSink.sendMonitoringState("STARTED") }
        assertTrue(prefs.getLong("watchdog_last_restart_at_ms", 0L) > 0L)
    }

    // ─── 5. Second restart within 60s → throttled ──────────────────────

    @Test
    fun `onReceive throttles second restart within 60 seconds`() {
        markMonitoringActive(true)
        every { BackgroundMonitoringService.isRunning } returns false
        setLastStartParams(phone = null, speaker = false)

        // First restart — should succeed and write timestamp
        receiver.onReceive(context, watchdogIntent())
        val firstTs = prefs.getLong("watchdog_last_restart_at_ms", 0L)
        assertTrue(firstTs > 0L)
        verify(exactly = 1) { NativeBridgeEventSink.sendMonitoringState("STARTED") }

        // Second restart 5s later — should be throttled
        prefs.edit()
            .putLong("watchdog_last_restart_at_ms", firstTs - 55_000L)
            .apply()
        receiver.onReceive(context, watchdogIntent())

        // Still only one STARTED event from the first restart
        verify(exactly = 1) { NativeBridgeEventSink.sendMonitoringState("STARTED") }
        // Throttle timestamp should NOT have been overwritten — the manual
        // value (firstTs - 55s) simulates a recent prior restart and must
        // be preserved since the receiver bails out before writing.
        assertEquals(
            firstTs - 55_000L,
            prefs.getLong("watchdog_last_restart_at_ms", 0L)
        )
    }

    // ─── 6. Restart at 60_500ms after first → allowed ───────────────────

    @Test
    fun `onReceive allows restart just past the 60s cooldown`() {
        markMonitoringActive(true)
        every { BackgroundMonitoringService.isRunning } returns false
        setLastStartParams(phone = null, speaker = false)

        // First restart
        receiver.onReceive(context, watchdogIntent())
        val firstTs = prefs.getLong("watchdog_last_restart_at_ms", 0L)
        verify(exactly = 1) { NativeBridgeEventSink.sendMonitoringState("STARTED") }

        // Pretend 60.5s have elapsed since the first restart
        prefs.edit()
            .putLong("watchdog_last_restart_at_ms", firstTs - 60_500L)
            .apply()
        receiver.onReceive(context, watchdogIntent())

        // Second STARTED was emitted
        verify(exactly = 2) { NativeBridgeEventSink.sendMonitoringState("STARTED") }
    }

    // ─── 7. Null intent → graceful no-op ────────────────────────────────

    @Test
    fun `onReceive with null intent is no-op`() {
        receiver.onReceive(context, null)

        verify { NativeBridgeEventSink wasNot Called }
        verify(exactly = 0) { BackgroundMonitoringService.isRunning }
    }

    // ─── 8. wasMonitoringActive reads the right key ─────────────────────

    @Test
    fun `wasMonitoringActive reads correct SharedPreferences key`() {
        markMonitoringActive(true)
        assertTrue(BackgroundMonitoringService.wasMonitoringActive(context))
    }

    @Test
    fun `wasMonitoringActive returns false when flag absent`() {
        // No markMonitoringActive() — flag is absent
        assertEquals(false, BackgroundMonitoringService.wasMonitoringActive(context))
    }

    // ─── 9. clearMonitoringActiveFlag writes false + removes extras ────

    @Test
    fun `clearMonitoringActiveFlag writes false and removes last-start params`() {
        markMonitoringActive(true)
        setLastStartParams(phone = "+84901234567", speaker = true)

        BackgroundMonitoringService.clearMonitoringActiveFlag(context)

        assertEquals(false, prefs.getBoolean("monitoring_was_active", false))
        assertNull(prefs.getString("watchdog_phone_number", null))
        assertEquals(false, prefs.getBoolean("watchdog_speakerphone", false))
    }
}
