package com.lachancuocgoi.lachancuocgoi_flutter.services

import android.Manifest
import android.app.Application
import android.content.Context
import androidx.test.core.app.ApplicationProvider
import com.lachancuocgoi.lachancuocgoi_flutter.services.stt.SttState
import io.mockk.every
import io.mockk.mockkStatic
import io.mockk.unmockkAll
import org.junit.After
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Before
import org.junit.Test
import org.junit.runner.RunWith
import org.robolectric.Shadows.shadowOf
import org.robolectric.RobolectricTestRunner
import org.robolectric.annotation.Config
import java.lang.reflect.Method

/**
 * Unit tests for [SpeechToTextManager] — focus on the
 * [SpeechToTextManager.appendWithOverlapDetection] algorithm and the
 * Vosk-preload / pause-resume contract.
 *
 * The SpeechRecognizer pipeline is NOT exercised (it requires a real
 * device with Google SpeechService). For those tests, see
 * [SttEngineContractTest].
 */
@RunWith(RobolectricTestRunner::class)
@Config(sdk = [34])
class SpeechToTextManagerTest {

    private lateinit var context: Context
    private lateinit var manager: SpeechToTextManager

    @Before
    fun setUp() {
        context = ApplicationProvider.getApplicationContext()
        shadowOf(context as Application).grantPermissions(Manifest.permission.RECORD_AUDIO)
        // Pretend Google STT is unavailable so startListening() short-circuits
        mockkStatic(android.speech.SpeechRecognizer::class)
        every {
            android.speech.SpeechRecognizer.isRecognitionAvailable(any())
        } returns false

        manager = SpeechToTextManager(context)
    }

    @After
    fun tearDown() {
        try { manager.destroy() } catch (_: Throwable) {}
        unmockkAll()
    }

    /**
     * Invoke the private `appendWithOverlapDetection(existing, newSegment)`
     * via reflection. Marked private in production; not modified.
     */
    private fun appendOverlap(existing: String, newSegment: String): String {
        val method: Method = SpeechToTextManager::class.java
            .getDeclaredMethod(
                "appendWithOverlapDetection",
                String::class.java,
                String::class.java,
            )
        method.isAccessible = true
        return method.invoke(manager, existing, newSegment) as String
    }

    // ─── 1. basic overlap of 1 word ────────────────────────────────────

    @Test
    fun `appendWithOverlapDetection detects single-word overlap`() {
        val result = appendOverlap("hello world", "world foo")
        // Overlap = "world" → new content = "foo"
        // Production uses "\n" as separator (see appendWithOverlapDetection)
        assertEquals("hello world\nfoo", result)
    }

    // ─── 2. full-prefix overlap ────────────────────────────────────────

    @Test
    fun `appendWithOverlapDetection with full-prefix overlap returns just new tail`() {
        val result = appendOverlap("hello", "hello world")
        // existing fully covers new prefix; best overlap = 1
        assertEquals("hello\nworld", result)
    }

    // ─── 3. overlap of 2 words ─────────────────────────────────────────

    @Test
    fun `appendWithOverlapDetection detects 2-word overlap`() {
        val result = appendOverlap("a b c d e f g", "f g h")
        // Overlap of 2 ("f g") → new content = "h"
        assertEquals("a b c d e f g\nh", result)
    }

    // ─── 4. empty existing ─────────────────────────────────────────────

    @Test
    fun `appendWithOverlapDetection with empty existing returns newSegment`() {
        assertEquals("x", appendOverlap("", "x"))
    }

    // ─── 5. empty new segment ──────────────────────────────────────────

    @Test
    fun `appendWithOverlapDetection with empty newSegment returns existing with trailing newline`() {
        // The algorithm returns "$existing\n$newSegment" when the new
        // segment is empty (newWords.isEmpty() branch).
        assertEquals("x\n", appendOverlap("x", ""))
    }

    // ─── 6. 15-word overlap (Sprint 2 C2) ──────────────────────────────

    @Test
    fun `appendWithOverlapDetection detects 15-word overlap (C2 boundary)`() {
        // existing has 15 words, new has 16 — old code (maxCheck=6) would
        // find NO overlap (head="alpha beta gamma delta epsilon zeta"
        // never matches a 6-word tail of the 15-word existing).
        val existing = "alpha beta gamma delta epsilon zeta eta theta iota kappa lambda mu nu xi omicron"
        val newSegment = "alpha beta gamma delta epsilon zeta eta theta iota kappa lambda mu nu xi omicron pi"
        val result = appendOverlap(existing, newSegment)
        // The 15-word overlap should be detected; the only new content
        // is "pi".
        assertEquals("$existing\npi", result)
    }

    @Test
    fun `appendWithOverlapDetection detects 16-word overlap (cap now 30)`() {
        // Existing and new share 16 words. With Bug #34 fix (maxCheck=30),
        // the overlap IS detected and deduplicated.
        val existing = "w1 w2 w3 w4 w5 w6 w7 w8 w9 w10 w11 w12 w13 w14 w15 w16"
        val newSegment = "w1 w2 w3 w4 w5 w6 w7 w8 w9 w10 w11 w12 w13 w14 w15 w16 w17"
        val result = appendOverlap(existing, newSegment)
        assertEquals("$existing\nw17", result)
    }

    // ─── 7. clearTranscript resets state ───────────────────────────────

    @Test
    fun `clearTranscript resets flows to empty strings`() {
        // Even without driving onResults, clearTranscript should be a
        // safe operation that zeroes the flows.
        manager.clearTranscript()
        assertEquals("", manager.fullTranscriptFlow.value)
        assertEquals("", manager.textResults.value)
    }

    // ─── 8. preloadVoskFallback is safe to call multiple times ─────────

    @Test
    fun `preloadVoskFallback can be called multiple times without error`() {
        manager.preloadVoskFallback()
        manager.preloadVoskFallback()
        manager.preloadVoskFallback()
        // No exception → pass
    }

    // ─── 9. startVoskPrimaryIfReady returns false when not preloaded ───

    @Test
    fun `startVoskPrimaryIfReady returns false when not preloaded`() {
        // Fresh manager — never called preloadVoskFallback
        val fresh = SpeechToTextManager(context)
        val result = fresh.startVoskPrimaryIfReady()
        assertFalse("should return false when Vosk is not preloaded", result)
        fresh.destroy()
    }

    @Test
    fun `startVoskPrimaryIfReady returns false after preload but model not ready`() {
        // We can't synchronously make the Vosk model ready in a unit
        // test (it requires the StorageService.unpack callback to
        // fire), so right after preload the model is not ready and
        // startVoskPrimaryIfReady() should return false.
        manager.preloadVoskFallback()
        val result = manager.startVoskPrimaryIfReady()
        assertFalse("should return false when model isn't ready yet", result)
    }

    // ─── 10. pauseListening / resumeListening are safe to call ─────────

    @Test
    fun `pauseListening is safe to call without an active recognizer`() {
        // Should not throw even though we're not actively listening
        manager.pauseListening()
        // Allow main-handler post to run
        shadowOf(android.os.Looper.getMainLooper()).idle()
    }

    @Test
    fun `resumeListening without shouldBeListening is a no-op`() {
        // shouldBeListening starts as false. resumeListening() should
        // bail without throwing.
        manager.resumeListening()
        shadowOf(android.os.Looper.getMainLooper()).idle()
    }

    @Test
    fun `resumeListening with shouldBeListening=true re-calls startListening`() {
        // Set shouldBeListening = true via reflection so resumeListening goes to startListening
        val field = SpeechToTextManager::class.java.getDeclaredField("shouldBeListening")
        field.isAccessible = true
        field.setBoolean(manager, true)

        manager.pauseListening()
        shadowOf(android.os.Looper.getMainLooper()).idle()
        manager.resumeListening()
        shadowOf(android.os.Looper.getMainLooper()).idle()
        // The "not available" error should have been emitted
        val stt = manager.sttState.value
        assertTrue("expected SttState.Error, got $stt", stt is SttState.Error)
    }

    // ─── 11. Bug #3: isRestarting must reset even when createSpeechRecognizer throws ──

    /**
     * Reads the private `isRestarting` flag via reflection.
     */
    private fun readIsRestarting(): Boolean {
        val field = SpeechToTextManager::class.java.getDeclaredField("isRestarting")
        field.isAccessible = true
        return field.getBoolean(manager)
    }

    @Test
    fun `Bug3 isRestarting is reset after createSpeechRecognizer throws`() {
        // 1) Override the previous setUp: enable Google STT this time.
        unmockkAll()
        mockkStatic(android.speech.SpeechRecognizer::class)
        every { android.speech.SpeechRecognizer.isRecognitionAvailable(any()) } returns true
        every {
            android.speech.SpeechRecognizer.createSpeechRecognizer(any())
        } throws RuntimeException("simulated device failure")

        // 2) Trigger startListening() — the inner block catches the throw and
        //    the finally clause MUST reset isRestarting.
        manager.startListening()
        shadowOf(android.os.Looper.getMainLooper()).idle()

        // 3) The bug would manifest as isRestarting being left at true.
        assertFalse(
            "isRestarting must reset to false even when createSpeechRecognizer throws (Bug #3)",
            readIsRestarting(),
        )
    }

    @Test
    fun `Bug3 isRestarting is reset after createSpeechRecognizer returns null`() {
        // Override setUp: Google STT available, but createSpeechRecognizer
        // returns null (some OEMs do this on broken builds).
        unmockkAll()
        mockkStatic(android.speech.SpeechRecognizer::class)
        every { android.speech.SpeechRecognizer.isRecognitionAvailable(any()) } returns true
        every { android.speech.SpeechRecognizer.createSpeechRecognizer(any()) } returns null

        manager.startListening()
        shadowOf(android.os.Looper.getMainLooper()).idle()

        assertFalse(
            "isRestarting must reset to false when createSpeechRecognizer returns null (Bug #3)",
            readIsRestarting(),
        )
    }

    @Test
    fun `Bug3 a second startListening after failure still proceeds (does not skip)`() {
        // Regression test for Bug #3: a failure in the first startListening
        // must NOT cause the next call to be skipped by the isRestarting guard.
        unmockkAll()
        mockkStatic(android.speech.SpeechRecognizer::class)
        // First call: throw. Second call: succeed (return a mock).
        var firstCall = true
        every { android.speech.SpeechRecognizer.isRecognitionAvailable(any()) } returns true
        every { android.speech.SpeechRecognizer.createSpeechRecognizer(any()) } answers {
            if (firstCall) {
                firstCall = false
                throw RuntimeException("first-call failure")
            }
            null // then null, just to exercise both branches
        }

        manager.startListening()
        shadowOf(android.os.Looper.getMainLooper()).idle()
        // Second call must not be blocked by stale isRestarting=true.
        assertFalse("must allow retry", readIsRestarting())
        manager.startListening()
        shadowOf(android.os.Looper.getMainLooper()).idle()
        assertFalse("must still not be blocked after retry", readIsRestarting())
    }

    // ─── Bug #34: overlap detection cap bumped 15 → 30 words ───────────

    @Test
    fun `Bug34 detects 20-word overlap (long scam phrase)`() {
        // Build a 20-word "tail" of the existing transcript and an identical
        // 20-word "head" of the new segment. The algorithm should drop
        // those 20 words from the new segment.
        val tail20 = List(20) { "w$it" }.joinToString(" ")
        val newHead20 = List(20) { "w$it" }.joinToString(" ")
        val existing = "xin chào ông $tail20"
        val newSegment = "$newHead20 rồi tiếp tục nói"
        val result = appendOverlap(existing, newSegment)
        // The 20 overlapping words should be dropped; only "rồi tiếp tục nói"
        // should be appended after the existing.
        assertTrue(
            "Expected deduped new content; got: $result",
            result.endsWith("rồi tiếp tục nói"),
        )
        // Overlapping words should appear exactly once (in the existing part),
        // not twice (which would happen without deduplication).
        val firstIdx = result.indexOf("w0 w1 w2")
        val secondIdx = result.indexOf("w0 w1 w2", firstIdx + 1)
        assertFalse(
            "Original overlapping words should NOT appear twice; got: $result",
            secondIdx >= 0,
        )
    }

    @Test
    fun `Bug34 still caps at 30 words (no false positives)`() {
        // 31+ word overlap should be capped at 30 (bestOverlap = 30, drop 30,
        // still 1 trailing word left to dedupe by tail match). This is just
        // a regression guard — the algorithm must not crash on long input.
        val tail30 = (1..30).joinToString(" ") { "t$it" }
        val newHead30 = (1..30).joinToString(" ") { "t$it" }
        val existing = "intro $tail30"
        val newSegment = "$newHead30 extra"
        val result = appendOverlap(existing, newSegment)
        // 30 words deduped, "extra" appended.
        assertTrue(result.endsWith("extra"))
    }
}
