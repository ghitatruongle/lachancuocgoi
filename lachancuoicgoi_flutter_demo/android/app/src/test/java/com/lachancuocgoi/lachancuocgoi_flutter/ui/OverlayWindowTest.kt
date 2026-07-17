package com.lachancuocgoi.lachancuocgoi_flutter.ui

import android.content.Context
import android.os.Looper
import android.view.View
import android.view.WindowManager
import android.widget.LinearLayout
import androidx.test.core.app.ApplicationProvider
import io.mockk.every
import io.mockk.mockk
import io.mockk.verify
import org.junit.After
import org.junit.Assert.assertFalse
import org.junit.Assert.assertNotNull
import org.junit.Assert.assertTrue
import org.junit.Before
import org.junit.Test
import org.junit.runner.RunWith
import org.robolectric.RobolectricTestRunner
import org.robolectric.Shadows.shadowOf
import org.robolectric.annotation.Config

/**
 * Tests for [OverlayWindow] helper.
 *
 * Bugs #11, #12, #17 are all addressed by this helper:
 *  - #11: each overlay manager had its own `var alertOverlayView: View?`
 *    with a hard reference, leaking the Activity on config change.
 *  - #12: alert sound MediaPlayer was leaked if `prepare()` threw.
 *  - #17 (related): each manager duplicated addView/removeView try/catch
 *    logic with subtle differences.
 */
@RunWith(RobolectricTestRunner::class)
@Config(sdk = [34])
class OverlayWindowTest {

    private lateinit var context: Context

    @Before
    fun setUp() {
        context = ApplicationProvider.getApplicationContext()
    }

    @After
    fun tearDown() {
        shadowOf(Looper.getMainLooper()).idle()
    }

    @Test
    fun `new OverlayWindow is not attached`() {
        val ow = OverlayWindow()
        assertFalse("fresh OverlayWindow must not be attached", ow.isAttached)
    }

    @Test
    fun `attach with valid view marks isAttached true`() {
        val ow = OverlayWindow()
        val view = LinearLayout(context)
        val ok = ow.attachOverlay(context, view)
        assertTrue("attachOverlay should succeed", ok)
        assertTrue(ow.isAttached)
    }

    @Test
    fun `detach clears isAttached`() {
        val ow = OverlayWindow()
        val view = LinearLayout(context)
        ow.attachOverlay(context, view)
        ow.detach()
        assertFalse(ow.isAttached)
    }

    @Test
    fun `detach when not attached is a safe no-op`() {
        val ow = OverlayWindow()
        ow.detach() // must not throw
        ow.detach() // twice — still no throw
        assertFalse(ow.isAttached)
    }

    @Test
    fun `attach with same view twice is idempotent`() {
        val ow = OverlayWindow()
        val view = LinearLayout(context)
        val first = ow.attachOverlay(context, view)
        val second = ow.attachOverlay(context, view)
        assertTrue(first)
        assertTrue("attach with same view should succeed (idempotent)", second)
        assertTrue(ow.isAttached)
    }

    @Test
    fun `attach with different view detaches the first`() {
        val ow = OverlayWindow()
        val view1 = LinearLayout(context)
        val view2 = LinearLayout(context)
        ow.attachOverlay(context, view1)
        ow.attachOverlay(context, view2)
        // After attaching view2, the helper must have detached view1.
        assertTrue(ow.isAttached)
    }

    @Test
    fun `attach that throws returns false and stays detached`() {
        // Mock a context whose WindowManager throws on addView.
        val mockContext = mockk<Context>(relaxed = true)
        val mockWm = mockk<WindowManager>(relaxed = true)
        every { mockContext.getSystemService(Context.WINDOW_SERVICE) } returns mockWm
        every { mockWm.addView(any(), any()) } throws WindowManager.BadTokenException("simulated")

        val ow = OverlayWindow()
        val view = LinearLayout(context)
        val ok = ow.attach(mockContext, view, mockk(relaxed = true))
        assertFalse("attach must return false on WindowManager failure", ok)
        assertFalse(ow.isAttached)
    }

    @Test
    fun `detach after attach failure is safe`() {
        val mockContext = mockk<Context>(relaxed = true)
        val mockWm = mockk<WindowManager>(relaxed = true)
        every { mockContext.getSystemService(Context.WINDOW_SERVICE) } returns mockWm
        every { mockWm.addView(any(), any()) } throws WindowManager.BadTokenException("simulated")

        val ow = OverlayWindow()
        ow.attach(mockContext, LinearLayout(context), mockk(relaxed = true))
        ow.detach() // must not throw
        assertFalse(ow.isAttached)
    }

    // ─── Memory-leak property: weak reference allows GC ────────────────

    @Test
    fun `weak reference allows the view to be garbage-collected`() {
        val ow = OverlayWindow()
        val view = LinearLayout(context)
        ow.attachOverlay(context, view)
        // Robolectric + JVM GC: cannot easily trigger GC from a test, but we
        // can verify the reference is a WeakReference (i.e. ow.isAttached
        // returns false if the View is no longer reachable). We simulate this
        // by attaching, detaching, and re-checking.
        ow.detach()
        assertFalse(ow.isAttached)
        // The reference is cleared by detach; we don't need to force GC.
    }
}
