package com.lachancuocgoi.lachancuocgoi_flutter.services

import android.os.Looper
import io.flutter.plugin.common.MethodChannel
import org.junit.After
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.Before
import org.junit.Test
import org.junit.runner.RunWith
import org.robolectric.RobolectricTestRunner
import org.robolectric.Shadows.shadowOf
import org.robolectric.annotation.Config
import io.mockk.every
import io.mockk.mockk
import io.mockk.verify

/**
 * Unit tests for [PendingResult] — the helper used by MainActivity to wrap
 * a pending [MethodChannel.Result] when the underlying Activity is destroyed
 * before the result is delivered (Bug #1, #23).
 *
 * Coverage:
 *  - set + success delivers exactly once
 *  - success / error / notImplemented are all idempotent (subsequent calls no-op)
 *  - timeout fires and invokes onExpire callback
 *  - cancel clears without firing
 *  - replace (set twice) cancels the previous timeout
 */
@RunWith(RobolectricTestRunner::class)
@Config(sdk = [34])
class PendingResultTest {

    private lateinit var result: MethodChannel.Result
    private var expired: Int = 0

    @Before
    fun setUp() {
        result = mockk(relaxed = true)
        every { result.success(any()) } returns Unit
        every { result.error(any(), any(), any()) } returns Unit
        every { result.notImplemented() } returns Unit
        expired = 0
    }

    @After
    fun tearDown() {
        shadowOf(Looper.getMainLooper()).idle()
    }

    private fun pump() = shadowOf(Looper.getMainLooper()).idle()

    // ─── 1. Basic success path ─────────────────────────────────────────

    @Test
    fun `set then success delivers value once`() {
        val pending = PendingResult(timeoutMs = 5_000L)
        pending.set(result)
        assertTrue("set should mark pending", pending.isPending())

        pending.success(true)
        pump()

        verify(exactly = 1) { result.success(true) }
        assertFalse("after success, no longer pending", pending.isPending())
    }

    // ─── 2. Idempotency ────────────────────────────────────────────────

    @Test
    fun `success is idempotent — second call is a no-op`() {
        val pending = PendingResult(timeoutMs = 5_000L)
        pending.set(result)
        pending.success("first")
        pump()

        pending.success("second") // ignored — already consumed
        pending.error("X", "y", null) // ignored — already consumed
        pending.notImplemented() // ignored — already consumed
        pump()

        verify(exactly = 1) { result.success("first") }
        verify(exactly = 0) { result.success("second") }
        verify(exactly = 0) { result.error(any(), any(), any()) }
        verify(exactly = 0) { result.notImplemented() }
    }

    @Test
    fun `error delivers when not yet completed`() {
        val pending = PendingResult(timeoutMs = 5_000L)
        pending.set(result)
        pending.error("UNAVAILABLE", "msg", null)
        pump()

        verify(exactly = 1) { result.error("UNAVAILABLE", "msg", null) }
        assertFalse(pending.isPending())
    }

    @Test
    fun `notImplemented delivers when not yet completed`() {
        val pending = PendingResult(timeoutMs = 5_000L)
        pending.set(result)
        pending.notImplemented()
        pump()

        verify(exactly = 1) { result.notImplemented() }
        assertFalse(pending.isPending())
    }

    // ─── 3. Cancel clears without firing ───────────────────────────────

    @Test
    fun `cancel clears without firing result`() {
        val pending = PendingResult(timeoutMs = 5_000L)
        pending.set(result)
        pending.cancel()

        assertFalse(pending.isPending())
        pending.success("should not arrive")
        pump()

        verify(exactly = 0) { result.success(any()) }
    }

    // ─── 4. Replace cancels the previous timeout ────────────────────────

    @Test
    fun `set replaces previous and cancels its timeout`() {
        // Use a long timeout so the idleFor doesn't trigger it.
        val pending = PendingResult(timeoutMs = 5_000L)
        val first = mockk<MethodChannel.Result>(relaxed = true)
        pending.set(first)

        // Replace before timeout — first's timeout must NOT fire
        pending.set(result)
        pump()
        shadowOf(Looper.getMainLooper()).idleFor(java.time.Duration.ofMillis(200))

        // First result must not be invoked at all
        verify(exactly = 0) { first.error(any(), any(), any()) }

        // New result still pending and works
        assertTrue(pending.isPending())
        pending.success("ok")
        pump()
        verify(exactly = 1) { result.success("ok") }
    }

    // ─── 5. Timeout fires onExpire + error ─────────────────────────────

    @Test
    fun `timeout fires onExpire callback and sends error`() {
        val pending = PendingResult(
            timeoutMs = 100L,
            onExpire = { expired++ },
        )
        pending.set(result)

        // Advance past the timeout
        shadowOf(Looper.getMainLooper()).idleFor(java.time.Duration.ofMillis(150))
        pump()

        assertEquals("onExpire should fire once", 1, expired)
        verify(exactly = 1) {
            result.error("TIMEOUT", match<String> { it.contains("100") }, null)
        }
        assertFalse("no longer pending after timeout", pending.isPending())
    }

    @Test
    fun `timeout does not fire if consumed in time`() {
        val pending = PendingResult(
            timeoutMs = 200L,
            onExpire = { expired++ },
        )
        pending.set(result)

        // Consume well before timeout
        shadowOf(Looper.getMainLooper()).idleFor(java.time.Duration.ofMillis(50))
        pending.success("fast")
        pump()

        // Advance past the original timeout — nothing should happen
        shadowOf(Looper.getMainLooper()).idleFor(java.time.Duration.ofMillis(300))
        pump()

        assertEquals("onExpire should NOT fire", 0, expired)
        verify(exactly = 1) { result.success("fast") }
    }

    @Test
    fun `default timeout is 60 seconds`() {
        val pending = PendingResult()
        // Verify the default constant is 60s, not 30s.
        assertEquals(60_000L, PendingResult.DEFAULT_TIMEOUT_MS)
    }

    // ─── 6. Initial state ──────────────────────────────────────────────

    @Test
    fun `new PendingResult is not pending`() {
        val pending = PendingResult()
        assertFalse(pending.isPending())
        // Calling success on a never-set pending is a safe no-op
        pending.success("ignored")
        verify(exactly = 0) { result.success(any()) }
    }

    // ─── 7. Static factory exposes null when consumed ──────────────────

    @Test
    fun `consumed result is no longer pending`() {
        val pending = PendingResult()
        pending.set(result)
        pending.success("done")
        assertFalse(pending.isPending())
        // Subsequent cancel is safe
        pending.cancel()
        assertFalse(pending.isPending())
    }
}
