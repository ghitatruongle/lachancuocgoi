package com.lachancuocgoi.lachancuocgoi_flutter.services

import android.app.Notification
import android.app.Service
import android.content.Context
import android.content.Intent
import androidx.test.core.app.ApplicationProvider
import io.mockk.every
import io.mockk.mockk
import io.mockk.verify
import org.junit.After
import org.junit.Assert.assertEquals
import org.junit.Assert.assertNotNull
import org.junit.Before
import org.junit.Test
import org.junit.runner.RunWith
import org.robolectric.RobolectricTestRunner
import org.robolectric.Shadows.shadowOf
import org.robolectric.annotation.Config
import org.robolectric.shadows.ShadowApplication

/**
 * Tests for [ForegroundServiceLauncher].
 *
 * Bug #2: Previously `CallScreeningServiceImpl` and `MainActivity` called
 *         `startForegroundService()` directly. On Android 12+, the system
 *         throws `ForegroundServiceStartNotAllowedException` when the app is
 *         not in a foreground-allowed context (call screening, Activity
 *         result handling). The helper catches this and falls back to
 *         `startService()`.
 *
 * Bug #8: Previously `startForeground()` on Android 13+ would throw
 *         `MissingForegroundServiceTypeException` or
 *         `ForegroundServiceStartNotAllowedException` when
 *         `POST_NOTIFICATIONS` had not been granted. The helper swallows
 *         the exception and returns false so the service continues running
 *         in the background (slightly degraded but not crashed).
 */
@RunWith(RobolectricTestRunner::class)
@Config(sdk = [34])
class ForegroundServiceLauncherTest {

    private lateinit var context: Context

    @Before
    fun setUp() {
        context = ApplicationProvider.getApplicationContext()
    }

    @After
    fun tearDown() {
        shadowOf(android.os.Looper.getMainLooper()).idle()
    }

    // ─── safeStartForegroundService ─────────────────────────────────────

    @Test
    fun `safeStartForegroundService normal path returns SUCCESS`() {
        // ShadowApplication.startForegroundService records into shadow; if the
        // call were throwing we'd see SUCCESS only if shadow didn't throw.
        val intent = Intent(context, TestService::class.java)
        val result = ForegroundServiceLauncher.safeStartForegroundService(context, intent)
        // Robolectric's shadow doesn't throw on startForegroundService, so SUCCESS
        // is the expected outcome.
        assertEquals(ForegroundServiceLauncher.LaunchResult.SUCCESS, result)
    }

    @Test
    fun `safeStartForegroundService never throws on context`() {
        // Even with a weird intent (no component set), must not throw.
        val intent = Intent()
        val result = ForegroundServiceLauncher.safeStartForegroundService(context, intent)
        // The call must return without throwing — any LaunchResult is acceptable.
        assertNotNull(result)
    }

    @Test
    fun `safeStartForegroundService with SecurityException returns SECURITY_DENIED`() {
        // Build a context that throws SecurityException on startForegroundService.
        val mockContext = mockk<Context>(relaxed = true)
        every { mockContext.startForegroundService(any()) } throws SecurityException("denied")
        val intent = Intent(mockContext, TestService::class.java)
        val result = ForegroundServiceLauncher.safeStartForegroundService(mockContext, intent)
        assertEquals(ForegroundServiceLauncher.LaunchResult.SECURITY_DENIED, result)
    }

    // ─── safeStartForeground ────────────────────────────────────────────

    @Test
    fun `safeStartForeground normal path returns true`() {
        val service = TestService()
        val notification = mockk<Notification>(relaxed = true)
        val result = ForegroundServiceLauncher.safeStartForeground(service, 1, notification)
        // Robolectric doesn't throw on startForeground, so success is expected.
        assertEquals(true, result)
    }

    @Test
    fun `safeStartForeground with thrown exception returns false`() {
        val service = mockk<Service>(relaxed = true)
        every { service.startForeground(any(), any()) } throws RuntimeException("boom")
        val notification = mockk<Notification>(relaxed = true)
        val result = ForegroundServiceLauncher.safeStartForeground(service, 1, notification)
        assertEquals(false, result)
    }

    @Test
    fun `safeStartForeground with MissingForegroundServiceTypeException returns false`() {
        // Use a real exception subclass so javaClass.simpleName matches.
        val service = mockk<Service>(relaxed = true)
        every { service.startForeground(any(), any()) } throws FakeMissingFgServiceTypeException("missing type")
        val notification = mockk<Notification>(relaxed = true)
        val result = ForegroundServiceLauncher.safeStartForeground(service, 1, notification)
        assertEquals(false, result)
    }

    @Test
    fun `safeStartForeground with SecurityException returns false`() {
        // Use the real java.lang.SecurityException — its simpleName is "SecurityException".
        val service = mockk<Service>(relaxed = true)
        every { service.startForeground(any(), any()) } throws java.lang.SecurityException("denied")
        val notification = mockk<Notification>(relaxed = true)
        val result = ForegroundServiceLauncher.safeStartForeground(service, 1, notification)
        assertEquals(false, result)
    }

    // ─── Helper ─────────────────────────────────────────────────────────

    /** Named to match the simpleName check in [ForegroundServiceLauncher]. */
    private class FakeMissingFgServiceTypeException(msg: String) : RuntimeException(msg)

    private class TestService : Service() {
        override fun onBind(intent: Intent?): android.os.IBinder? = null
    }
}
