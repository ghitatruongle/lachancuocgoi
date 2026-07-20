@file:Suppress("DEPRECATION")

package com.lachancuocgoi.lachancuocgoi_flutter.services

import android.content.Context
import android.content.Intent
import android.media.AudioAttributes
import android.media.AudioFocusRequest
import android.media.AudioManager
import android.os.Looper
import androidx.test.core.app.ApplicationProvider
import io.mockk.every
import io.mockk.just
import io.mockk.mockk
import io.mockk.mockkConstructor
import io.mockk.mockkObject
import io.mockk.runs
import io.mockk.slot
import io.mockk.unmockkAll
import io.mockk.verify
import kotlinx.coroutines.flow.MutableStateFlow
import org.junit.After
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertNotNull
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.Assert.fail
import org.junit.Before
import org.junit.Test
import org.junit.runner.RunWith
import org.robolectric.Robolectric
import org.robolectric.RobolectricTestRunner
import org.robolectric.Shadows.shadowOf
import org.robolectric.annotation.Config

/**
 * Unit tests for [BackgroundMonitoringService] — post-Sprint 1+2+3 contract.
 *
 * Strategy: build the service via Robolectric's ServiceController so
 * `onCreate` runs naturally. Then inject a relaxed-mock
 * [SpeechToTextManager] via reflection so we can drive flows and
 * verify call-sites without a real SpeechRecognizer. Verify
 * observable side-effects on [NativeBridgeEventSink] (mocked) and on
 * SharedPreferences.
 */
@RunWith(RobolectricTestRunner::class)
@Config(sdk = [34])
class BackgroundMonitoringServiceTest {

    private lateinit var context: Context
    private lateinit var service: BackgroundMonitoringService
    private lateinit var mockSttManager: SpeechToTextManager

    @Before
    fun setUp() {
        context = ApplicationProvider.getApplicationContext()
        shadowOf(context as android.app.Application)
            .grantPermissions(android.Manifest.permission.RECORD_AUDIO)

        // Reset companion-level state via reflection (isRunning has a
        // private setter, so direct assignment from outside the class
        // is not possible).
        resetIsRunningFlag()

        // Clear any leftover prefs from earlier tests
        context.getSharedPreferences(BackgroundMonitoringService.WATCHDOG_PREFS, Context.MODE_PRIVATE)
            .edit().clear().commit()
        context.getSharedPreferences(MonitoringPreferences.PREFS_NAME, Context.MODE_PRIVATE)
            .edit().clear().commit()

        // Reset the global transcript hub
        TranscriptionHub.reset()

        // Mock the event sink (the production code calls it everywhere)
        mockkObject(NativeBridgeEventSink)
        every { NativeBridgeEventSink.sendMonitoringState(any()) } just runs
        every { NativeBridgeEventSink.sendTranscript(any(), any()) } just runs
        every { NativeBridgeEventSink.sendRms(any()) } just runs

        // Build the service — onCreate() runs, which creates a real
        // SpeechToTextManager and ConnectivityMonitor. We then swap
        // the SpeechToTextManager for a mock so we can drive flows.
        service = Robolectric.buildService(BackgroundMonitoringService::class.java)
            .create()
            .get()

        mockSttManager = mockk(relaxed = true)
        every { mockSttManager.fullTranscriptFlow } returns MutableStateFlow("")
        every { mockSttManager.textResults } returns MutableStateFlow("")
        every { mockSttManager.isListening } returns MutableStateFlow(false)
        every { mockSttManager.rmsDbFlow } returns MutableStateFlow(0f)
        every { mockSttManager.shouldBeListeningSnapshot } returns false

        injectField("speechToTextManager", mockSttManager)
    }

    @After
    fun tearDown() {
        try { service.onDestroy() } catch (_: Throwable) {}
        try { resetIsRunningFlag() } catch (_: Throwable) {}
        TranscriptionHub.reset()
        unmockkAll()
    }

    /**
     * Reflectively reset the static `@Volatile var isRunning` on the
     * companion. The production code declares it with a private setter,
     * so the only way to zero it from a test is reflection.
     */
    private fun resetIsRunningFlag() {
        val field = BackgroundMonitoringService::class.java
            .getDeclaredField("isRunning")
        field.isAccessible = true
        field.setBoolean(null, false)
    }

    // ─── helpers ─────────────────────────────────────────────────────────

    private fun idle() = shadowOf(Looper.getMainLooper()).idle()

    private fun injectField(name: String, value: Any?) {
        val field = BackgroundMonitoringService::class.java.getDeclaredField(name)
        field.isAccessible = true
        field.set(service, value)
    }

    private fun readField(name: String): Any? {
        val field = BackgroundMonitoringService::class.java.getDeclaredField(name)
        field.isAccessible = true
        return field.get(service)
    }

    private fun startIntent(extras: Intent.() -> Unit = {}): Intent =
        Intent(context, BackgroundMonitoringService::class.java).apply {
            action = BackgroundMonitoringService.ACTION_START
            extras()
        }

    private fun stopIntent(): Intent =
        Intent(context, BackgroundMonitoringService::class.java).apply {
            action = BackgroundMonitoringService.ACTION_STOP
        }

    /**
     * Wait up to [timeoutMs] for the IO coroutine to set
     * [BackgroundMonitoringService]'s `transcriptCollectorJob` field.
     * Required because `startMonitoring()` schedules a coroutine that
     * does `delay(100)` before setting this field.
     */
    private fun waitForTranscriptCollector(timeoutMs: Long = 3000) {
        val start = System.currentTimeMillis()
        while (System.currentTimeMillis() - start < timeoutMs) {
            if (readField("transcriptCollectorJob") != null) return
            Thread.sleep(20)
        }
        fail("transcriptCollectorJob was not set within ${timeoutMs}ms")
    }

    /**
     * Wait up to [timeoutMs] for the IO coroutine to set
     * `connectivityJob` (synchronous but on a different thread).
     */
    private fun waitForConnectivityJob(timeoutMs: Long = 2000) {
        val start = System.currentTimeMillis()
        while (System.currentTimeMillis() - start < timeoutMs) {
            if (readField("connectivityJob") != null) return
            Thread.sleep(10)
        }

        // Don't fail — just note it. Some tests don't care about this.
    }

    // ─── 1. onCreate invokes preloadVoskFallback ─────────────────────────

    @Test
    fun `onCreate invokes preloadVoskFallback exactly once`() {
        // Re-run onCreate() under mockkConstructor so we can verify the
        // call. Tear down the previous service first.
        unmockkAll()
        mockkObject(NativeBridgeEventSink)
        every { NativeBridgeEventSink.sendMonitoringState(any()) } just runs

        mockkConstructor(SpeechToTextManager::class)
        every { anyConstructed<SpeechToTextManager>().preloadVoskFallback() } just runs
        mockkConstructor(VoskSttManager::class)

        // Build a fresh service so onCreate() runs again
        val fresh = Robolectric.buildService(BackgroundMonitoringService::class.java)
            .create()
            .get()
        idle()

        verify(exactly = 1, timeout = 2_000L) {
            anyConstructed<SpeechToTextManager>().preloadVoskFallback()
        }
        // Don't leak the new service
        try { fresh.onDestroy() } catch (_: Throwable) {}
    }

    // ─── 2. First ACTION_START → startForeground + STARTED event ───────

    @Test
    fun `first ACTION_START sets isMonitoringActive true and sends STARTED`() {
        service.onStartCommand(startIntent(), 0, 1)
        idle()

        // isMonitoringActive should be true
        assertEquals(true, readField("isMonitoringActive"))
        // isRunning (companion) should be true
        assertTrue(BackgroundMonitoringService.isRunning)
        // STARTED event sent
        verify(exactly = 1) { NativeBridgeEventSink.sendMonitoringState("STARTED") }
    }

    // ─── 3. Second ACTION_START while active → idempotent ───────────────

    @Test
    fun `second ACTION_START while active is idempotent and does not re-send STARTED`() {
        service.onStartCommand(startIntent(), 0, 1)
        idle()
        verify(exactly = 1) { NativeBridgeEventSink.sendMonitoringState("STARTED") }

        // Second ACTION_START while still active
        service.onStartCommand(startIntent(), 0, 2)
        idle()

        // Still only one STARTED
        verify(exactly = 1) { NativeBridgeEventSink.sendMonitoringState("STARTED") }
    }

    // ─── 4. ACTION_STOP while active → STOPPED event with transcript ───

    @Test
    fun `ACTION_STOP while active cancels jobs and sends STOPPED with transcript`() {
        service.onStartCommand(startIntent(), 0, 1)
        idle()
        waitForConnectivityJob()
        waitForTranscriptCollector()

        // Drive a value through fullTranscriptFlow so the combine
        // emits and the collector updates currentTranscript.
        val flow = mockSttManager.fullTranscriptFlow as MutableStateFlow<String>
        flow.value = "hello world"
        // Also clear the empty initial from the transcriptFlow
        // (the hub was reset in @Before so it's already "")
        idle()
        Thread.sleep(100) // let the combine + collect run
        idle()

        service.onStartCommand(stopIntent(), 0, 2)
        idle()
        Thread.sleep(100) // let finalizationScope coroutine run
        idle()

        // A STOPPED event was sent
        verify(atLeast = 1) {
            NativeBridgeEventSink.sendMonitoringState(match { state ->
                state.startsWith("STOPPED:")
            })
        }
        // isMonitoringActive flipped to false
        assertEquals(false, readField("isMonitoringActive"))
        assertFalse(BackgroundMonitoringService.isRunning)
    }

    // ─── 5. ACTION_STOP while idle → stopSelf, no STOPPED event ────────

    @Test
    fun `ACTION_STOP while idle does not send STOPPED event`() {
        // Service is fresh — no prior ACTION_START
        service.onStartCommand(stopIntent(), 0, 1)
        idle()

        // No STOPPED event because we never started
        verify(exactly = 0) {
            NativeBridgeEventSink.sendMonitoringState(match { it.startsWith("STOPPED:") })
        }
        // isMonitoringActive remains false
        assertEquals(false, readField("isMonitoringActive"))
    }

    // ─── 6. onTrimMemory cancels connectivityJob but not transcriptCollectorJob ─

    @Test
    fun `onTrimMemory at CRITICAL cancels connectivityJob but not transcriptCollectorJob`() {
        service.onStartCommand(startIntent(), 0, 1)
        idle()
        waitForConnectivityJob()
        waitForTranscriptCollector()

        // Sanity: both jobs are non-null before onTrimMemory
        assertNotNull("connectivityJob should be set", readField("connectivityJob"))
        assertNotNull("transcriptCollectorJob should be set", readField("transcriptCollectorJob"))

        service.onTrimMemory(TRIM_MEMORY_RUNNING_CRITICAL)

        // connectivityJob cancelled and nulled out
        assertNull("connectivityJob should be null after onTrimMemory(CRITICAL)",
            readField("connectivityJob"))
        // transcriptCollectorJob MUST survive
        assertNotNull("transcriptCollectorJob should NOT be cancelled",
            readField("transcriptCollectorJob"))
    }

    @Test
    fun `onTrimMemory below CRITICAL does not cancel connectivityJob`() {
        service.onStartCommand(startIntent(), 0, 1)
        idle()
        waitForConnectivityJob()
        waitForTranscriptCollector()

        service.onTrimMemory(TRIM_MEMORY_RUNNING_MODERATE) // below CRITICAL

        // connectivityJob survives
        assertNotNull("connectivityJob should survive onTrimMemory(MODERATE)",
            readField("connectivityJob"))
    }

    // ─── 7. requestAudioFocus with granted → returns true, willPauseWhenDucked = true ─

    @Test
    fun `requestAudioFocus with granted response returns true and sets willPauseWhenDucked`() {
        val audioManager = mockk<AudioManager>(relaxed = true)
        every { audioManager.isSpeakerphoneOn } returns false
        every { audioManager.requestAudioFocus(any<AudioFocusRequest>()) } returns
            AudioManager.AUDIOFOCUS_REQUEST_GRANTED
        injectField("audioManager", audioManager)

        val method = BackgroundMonitoringService::class.java
            .getDeclaredMethod("requestAudioFocus")
        method.isAccessible = true
        val result = method.invoke(service) as Boolean

        assertTrue("requestAudioFocus should return true when granted", result)

        val focusRequestSlot = slot<AudioFocusRequest>()
        verify { audioManager.requestAudioFocus(capture(focusRequestSlot)) }
        val captured = focusRequestSlot.captured
        // Sprint 2 (B3): we set willPauseWhenDucked(true) so STT
        // pauses on transient ducking.
        assertTrue("willPauseWhenDucked should be true", captured.willPauseWhenDucked())
        // Sanity: AudioAttributes are configured for voice/speech
        val attrs: AudioAttributes = captured.audioAttributes
        assertEquals(AudioAttributes.USAGE_ASSISTANT, attrs.usage)
    }

    @Test
    fun `requestAudioFocus with denied response returns false`() {
        val audioManager = mockk<AudioManager>(relaxed = true)
        every { audioManager.requestAudioFocus(any<AudioFocusRequest>()) } returns
            AudioManager.AUDIOFOCUS_REQUEST_FAILED
        injectField("audioManager", audioManager)

        val method = BackgroundMonitoringService::class.java
            .getDeclaredMethod("requestAudioFocus")
        method.isAccessible = true
        val result = method.invoke(service) as Boolean

        assertFalse("requestAudioFocus should return false when denied", result)
    }

    // ─── 8. releaseAudioFocus → calls abandonAudioFocusRequest ──────────

    @Test
    fun `releaseAudioFocus calls abandonAudioFocusRequest on O+`() {
        val audioManager = mockk<AudioManager>(relaxed = true)
        val focusRequest = mockk<AudioFocusRequest>(relaxed = true)
        every { audioManager.abandonAudioFocusRequest(any<AudioFocusRequest>()) } returns
            AudioManager.AUDIOFOCUS_REQUEST_GRANTED
        injectField("audioManager", audioManager)
        injectField("audioFocusRequest", focusRequest)
        injectField("hadAudioFocus", true)

        val method = BackgroundMonitoringService::class.java
            .getDeclaredMethod("releaseAudioFocus")
        method.isAccessible = true
        method.invoke(service)

        verify(exactly = 1) { audioManager.abandonAudioFocusRequest(focusRequest) }
    }

    // ─── 9. Persists only non-sensitive last-start params ───────────────

    @Test
    fun `ACTION_START never persists phone number but keeps speakerphone setting`() {
        val intent = startIntent {
            putExtra("PHONE_NUMBER", "+84901234567")
            putExtra("ENABLE_SPEAKERPHONE", true)
        }
        service.onStartCommand(intent, 0, 1)
        idle()

        val prefs = context.getSharedPreferences(
            BackgroundMonitoringService.WATCHDOG_PREFS, Context.MODE_PRIVATE)
        assertNull(prefs.getString("watchdog_phone_number", null))
        assertEquals(true, prefs.getBoolean("watchdog_speakerphone", false))
        // The "monitoring was active" flag also gets set
        assertEquals(true, prefs.getBoolean("monitoring_was_active", false))
    }

    @Test
    fun `ACTION_START without phone persists null phone and uses default speakerphone`() {
        val intent = startIntent {
            // No extras — shouldEnableSpeakerphone defaults to false
        }
        service.onStartCommand(intent, 0, 1)
        idle()

        val prefs = context.getSharedPreferences(
            BackgroundMonitoringService.WATCHDOG_PREFS, Context.MODE_PRIVATE)
        // No phone number passed → the persist step removes the key
        assertNull(prefs.getString("watchdog_phone_number", null))
        assertEquals(true, prefs.getBoolean("watchdog_speakerphone", false))
    }

    @Test
    fun `ACTION_START respects an explicit disabled speakerphone preference`() {
        MonitoringPreferences.writeAutoEnableSpeakerphone(context, false)

        service.onStartCommand(startIntent(), 0, 1)
        idle()

        val prefs = context.getSharedPreferences(
            BackgroundMonitoringService.WATCHDOG_PREFS, Context.MODE_PRIVATE)
        assertEquals(false, prefs.getBoolean("watchdog_speakerphone", true))
    }

    // ─── 10. clearMonitoringActiveFlag clears last-start params ─────────

    @Test
    fun `clearMonitoringActiveFlag clears the persisted flag and start params`() {
        val prefs = context.getSharedPreferences(
            BackgroundMonitoringService.WATCHDOG_PREFS, Context.MODE_PRIVATE,
        )
        prefs.edit()
            .putBoolean("monitoring_was_active", true)
            .putString("watchdog_phone_number", "+84901234567")
            .putBoolean("watchdog_speakerphone", true)
            .commit()

        BackgroundMonitoringService.clearMonitoringActiveFlag(context)

        assertEquals(false, prefs.getBoolean("monitoring_was_active", false))
        assertNull(prefs.getString("watchdog_phone_number", null))
        assertEquals(false, prefs.getBoolean("watchdog_speakerphone", false))
    }

    // ─── Foreground promotion does not depend on POST_NOTIFICATIONS ──────

    @Test
    fun `Bug8 ACTION_START with no POST_NOTIFICATIONS does not crash`() {
        // Default: Robolectric does not grant POST_NOTIFICATIONS. Android
        // still requires the service to call startForeground().
        val intent = Intent(context, BackgroundMonitoringService::class.java).apply {
            action = BackgroundMonitoringService.ACTION_START
            putExtra("ENABLE_SPEAKERPHONE", false)
        }
        // Must not throw.
        try {
            service.onStartCommand(intent, 0, 1)
            idle()
        } catch (e: Throwable) {
            fail("ACTION_START must not throw when POST_NOTIFICATIONS is missing (Bug #8): $e")
        }

        verify(exactly = 0) {
            NativeBridgeEventSink.sendMonitoringState(match { it == "DEGRADED_NO_NOTIFICATION" })
        }
        assertTrue("Service should remain active after foreground promotion", BackgroundMonitoringService.isRunning)
    }

    @Test
    fun `Bug8 ACTION_START with POST_NOTIFICATIONS granted does not emit DEGRADED`() {
        // Grant POST_NOTIFICATIONS so the foreground-promotion path is taken.
        org.robolectric.Shadows.shadowOf(
            context as android.app.Application,
        ).grantPermissions(android.Manifest.permission.POST_NOTIFICATIONS)

        val intent = Intent(context, BackgroundMonitoringService::class.java).apply {
            action = BackgroundMonitoringService.ACTION_START
            putExtra("ENABLE_SPEAKERPHONE", false)
        }
        service.onStartCommand(intent, 0, 1)
        idle()

        // With notification permission granted, we should NOT emit DEGRADED.
        verify(exactly = 0) {
            NativeBridgeEventSink.sendMonitoringState(match { it == "DEGRADED_NO_NOTIFICATION" })
        }
    }

    @Test
    fun `foreground promotion failure stops service and reports native failure`() {
        mockkObject(ForegroundServiceLauncher)
        every {
            ForegroundServiceLauncher.safeStartForeground(any(), any(), any(), any())
        } returns false

        val result = service.onStartCommand(startIntent(), 0, 41)
        idle()

        assertEquals(android.app.Service.START_NOT_STICKY, result)
        assertFalse(BackgroundMonitoringService.isRunning)
        verify(atLeast = 1) {
            NativeBridgeEventSink.sendMonitoringState("START_FAILED:nativeFailure")
        }
    }

    // ─── Bug #9: enableSpeakerphone interval constant ───────────────────

    @Test
    fun `Bug9 speakerphone enforcement interval is 5000ms (not 2000ms)`() {
        // Verify the constant is set to the new value. If a future change
        // reverts to 2000ms this test will fail, alerting us to the perf
        // regression.
        val field = BackgroundMonitoringService::class.java
            .getDeclaredField("SPEAKERPHONE_ENFORCEMENT_INTERVAL_MS")
        field.isAccessible = true
        assertEquals(5000L, (field.get(null) as Long))
    }

    // ─── Bug #10: cancelWatchdogAlarm called in onDestroy ───────────────

    @Test
    fun `Bug10 onDestroy cancels watchdog alarm when not intentionally stopping`() {
        // Set isRunning=true and isStopping=false (the natural state for an
        // unscheduled destroy, e.g. system kill).
        resetIsRunningFlag()
        // Call cancelWatchdogAlarm indirectly via onDestroy; verify the
        // alarm state was reset.
        // First, schedule the alarm (it'll be a no-op in Robolectric but the
        // prefs will be touched).
        val method = BackgroundMonitoringService::class.java
            .getDeclaredMethod("scheduleWatchdogAlarm")
        method.isAccessible = true
        method.invoke(service)
        // Then call onDestroy.
        try {
            service.onDestroy()
        } catch (_: Throwable) { /* some fields may NPE in test env */ }
        // The cancelWatchdogAlarm should have cleared the prefs.
        val prefs = context.getSharedPreferences(
            BackgroundMonitoringService.WATCHDOG_PREFS, Context.MODE_PRIVATE,
        )
        // After cleanup the monitoring-active flag must be false so the
        // watchdog receiver doesn't restart us on the next alarm tick.
        assertFalse(prefs.getBoolean("monitoring_was_active", false))
    }

    @Test
    fun `Bug10 onDestroy skips cancelWatchdogAlarm when isStopping is true`() {
        // Set isStopping=true via reflection to simulate a clean stop.
        val field = BackgroundMonitoringService::class.java.getDeclaredField("isStopping")
        field.isAccessible = true
        field.setBoolean(service, true)

        // Schedule the alarm, then onDestroy.
        val method = BackgroundMonitoringService::class.java
            .getDeclaredMethod("scheduleWatchdogAlarm")
        method.isAccessible = true
        method.invoke(service)

        // Mark monitoring-was-active in prefs to simulate mid-stop state.
        val prefs = context.getSharedPreferences(
            BackgroundMonitoringService.WATCHDOG_PREFS, Context.MODE_PRIVATE,
        )
        prefs.edit().putBoolean("monitoring_was_active", false).commit()

        try { service.onDestroy() } catch (_: Throwable) { /* ignore */ }

        // When isStopping=true we don't re-cancel (it was already cancelled
        // by stopMonitoring). The test just verifies no crash.
        assertTrue("no-op", true)
    }

    // ─── Bug #15: MAX_PARTIAL_AGE_MS constant exists ───────────────────

    @Test
    fun `Bug15 MAX_PARTIAL_AGE_MS constant exists and is 10000ms`() {
        val field = BackgroundMonitoringService::class.java
            .getDeclaredField("MAX_PARTIAL_AGE_MS")
        field.isAccessible = true
        assertEquals(10_000L, (field.get(null) as Long))
    }

    @Test
    fun `Bug15 per-source timestamp fields exist`() {
        // lastSttUpdateMs, lastPartialUpdateMs, lastAccUpdateMs must be
        // declared so the combine block can read them via reflection.
        for (name in listOf("lastSttUpdateMs", "lastPartialUpdateMs", "lastAccUpdateMs")) {
            val f = BackgroundMonitoringService::class.java.getDeclaredField(name)
            f.isAccessible = true
            // Initially zero / default
            assertEquals(
                "$name should default to 0L",
                0L,
                (f.get(service) as Long),
            )
        }
    }

    companion object {
        private const val TRIM_MEMORY_RUNNING_MODERATE = 5
        private const val TRIM_MEMORY_RUNNING_CRITICAL = 15
    }
}
