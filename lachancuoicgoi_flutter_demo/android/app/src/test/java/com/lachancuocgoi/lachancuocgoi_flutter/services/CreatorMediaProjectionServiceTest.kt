package com.lachancuocgoi.lachancuocgoi_flutter.services

import android.content.Context
import android.content.Intent
import android.media.projection.MediaProjection
import android.media.projection.MediaProjectionManager
import android.os.Build
import android.os.Looper
import androidx.test.core.app.ApplicationProvider
import io.mockk.every
import io.mockk.mockk
import io.mockk.mockkObject
import io.mockk.unmockkObject
import io.mockk.verify
import org.junit.After
import org.junit.Assume
import org.junit.Before
import org.junit.Test
import org.junit.runner.RunWith
import org.robolectric.Robolectric
import org.robolectric.RobolectricTestRunner
import org.robolectric.Shadows.shadowOf
import org.robolectric.annotation.Config
import java.lang.reflect.Field

/**
 * Tests for [CreatorMediaProjectionService].
 *
 * Bug #7: previously, the service did not register a [MediaProjection.Callback]
 *         so if the system revoked the projection (user disabled via Settings,
 *         OS killed the projection, etc.), the service kept running with a
 *         dead projection — capture loop read 0 bytes silently and the user
 *         saw an empty transcript with no error.
 *
 * The fix registers a callback whose `onStop()` tears down the capture loop
 * and sends a `STOPPED` state event.
 */
@RunWith(RobolectricTestRunner::class)
@Config(sdk = [34])
class CreatorMediaProjectionServiceTest {

    private lateinit var context: Context
    private lateinit var service: CreatorMediaProjectionService

    @Before
    fun setUp() {
        Assume.assumeTrue(
            "MediaProjection requires API 21+ but the test exercises modern code paths",
            Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q,
        )
        context = ApplicationProvider.getApplicationContext()

        mockkObject(NativeBridgeEventSink, recordPrivateCalls = false)
        every { NativeBridgeEventSink.sendLog(any(), any(), any()) } returns Unit
        every { NativeBridgeEventSink.sendMonitoringState(any()) } returns Unit
        every { NativeBridgeEventSink.sendTranscript(any(), any()) } returns Unit

        service = Robolectric.buildService(CreatorMediaProjectionService::class.java)
            .create()
            .get()
    }

    @After
    fun tearDown() {
        try {
            // Don't call onDestroy unconditionally — would NPE without a
            // real stopCapture context.
            CreatorMediaProjectionService.isRunning = false
        } catch (_: Exception) { /* ignore */ }
        unmockkObject(NativeBridgeEventSink)
        shadowOf(Looper.getMainLooper()).idle()
    }

    // ─── Bug #7: MediaProjection callback is registered ─────────────────

    @Test
    fun `projectionCallback field exists and is a MediaProjection Callback`() {
        val field: Field = CreatorMediaProjectionService::class.java
            .getDeclaredField("projectionCallback")
        field.isAccessible = true
        val callback = field.get(service)
        assertNotNull("projectionCallback must be initialized", callback)
        assertTrue(
            "projectionCallback must be a MediaProjection.Callback",
            callback is MediaProjection.Callback,
        )
    }

    @Test
    fun `onStop of projectionCallback tears down capture loop`() {
        // Read the callback field.
        val field: Field = CreatorMediaProjectionService::class.java
            .getDeclaredField("projectionCallback")
        field.isAccessible = true
        val callback = field.get(service) as MediaProjection.Callback

        // Set isRunning = true so stopCapture sends STOPPED state.
        CreatorMediaProjectionService.isRunning = true

        // Trigger onStop().
        callback.onStop()
        shadowOf(Looper.getMainLooper()).idle()

        // Verify: STOPPED state was emitted.
        verify(atLeast = 1) {
            NativeBridgeEventSink.sendMonitoringState(match { it.startsWith("STOPPED") })
        }
        // Verify: a warning log was emitted.
        verify(atLeast = 1) {
            NativeBridgeEventSink.sendLog(any(), match { it.contains("thu hồi") }, "WARN")
        }
    }

    @Test
    fun `onStop of projectionCallback is idempotent`() {
        val field: Field = CreatorMediaProjectionService::class.java
            .getDeclaredField("projectionCallback")
        field.isAccessible = true
        val callback = field.get(service) as MediaProjection.Callback

        CreatorMediaProjectionService.isRunning = true

        // First call.
        callback.onStop()
        shadowOf(Looper.getMainLooper()).idle()
        // Second call must not crash (stopSelf after stopSelf is safe).
        callback.onStop()
        shadowOf(Looper.getMainLooper()).idle()

        // No assertion needed — just no exception.
    }

    // ─── Helper ─────────────────────────────────────────────────────────

    private fun assertTrue(message: String, condition: Boolean) {
        if (!condition) throw AssertionError(message)
    }

    private fun assertNotNull(message: String, value: Any?) {
        if (value == null) throw AssertionError(message)
    }
}
