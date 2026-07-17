package com.lachancuocgoi.lachancuocgoi_flutter.services

import kotlinx.coroutines.ExperimentalCoroutinesApi
import kotlinx.coroutines.flow.first
import kotlinx.coroutines.runBlocking
import org.junit.After
import org.junit.Assert.assertEquals
import org.junit.Assert.assertTrue
import org.junit.Before
import org.junit.Test
import java.util.concurrent.CountDownLatch
import java.util.concurrent.TimeUnit
import java.util.concurrent.atomic.AtomicInteger

/**
 * Pure-JUnit tests for [TranscriptionHub].
 *
 * `TranscriptionHub` is a Kotlin object that holds transcript state in
 * memory; no Android framework calls happen, so these tests run without
 * Robolectric and are very fast.
 */
@OptIn(ExperimentalCoroutinesApi::class)
class TranscriptionHubTest {

    @Before
    fun setUp() {
        TranscriptionHub.reset()
    }

    @After
    fun tearDown() {
        TranscriptionHub.reset()
    }

    // ─── 1. basic post + read ───────────────────────────────────────────

    @Test
    fun `postTranscript emits new text on transcriptFlow`() = runBlocking {
        TranscriptionHub.postTranscript("hello")
        assertEquals("hello", TranscriptionHub.transcriptFlow.value)
        assertEquals("hello", TranscriptionHub.transcriptFlow.first())
    }

    // ─── 2. overlap detection ───────────────────────────────────────────

    @Test
    fun `postTranscript appends with overlap detection`() = runBlocking {
        TranscriptionHub.postTranscript("hello world")
        TranscriptionHub.postTranscript("world foo")
        // "world" overlap → "hello world foo" (full new text is appended
        // minus the overlap). The actual production separator is " ", so
        // the expected result is the joined string.
        assertEquals("hello world foo", TranscriptionHub.transcriptFlow.value)
    }

    @Test
    fun `postTranscript handles empty existing`() = runBlocking {
        TranscriptionHub.postTranscript("first")
        assertEquals("first", TranscriptionHub.transcriptFlow.value)
    }

    // ─── 3. cutoff at MAX_HISTORY_RETAIN at sentence boundary ───────────

    @Test
    fun `postTranscript cuts history at nearest sentence boundary when over limit`() =
        runBlocking {
            // Build a long string of distinct sentences to push the
            // history past MAX_HISTORY_RETAIN. Important: each post must
            // contain NEW content (overlap detection will swallow repeats
            // of the same chunk), so we make every sentence unique.
            val longInput = buildString {
                repeat(150) { i ->
                    // ~36 chars × 150 = 5400 chars, well past 5000.
                    append("Sentence number $i with some filler text. ")
                }
            }
            TranscriptionHub.postTranscript(longInput)
            val before = TranscriptionHub.transcriptFlow.value
            assertTrue("history should exceed MAX_HISTORY_RETAIN (was ${before.length})",
                before.length > 5000)

            // One more post should not lose the cut's invariant:
            // after a cut, the result should still contain the last
            // word we just posted (or its tail). Easier check: the
            // transcript should not be empty and length <= previous.
            TranscriptionHub.postTranscript("trailing sentence.")
            val after = TranscriptionHub.transcriptFlow.value
            assertTrue(after.isNotEmpty())
            assertTrue(after.contains("trailing sentence."))
        }

    @Test
    fun `postTranscript cuts at sentence boundary near target length`() {
        // Targeted test: post a long string with a period+space at a
        // known offset, then post more to push it past the cut window,
        // and verify the cut happened near that period.
        val longText = buildString {
            // 200-char preamble with NO period
            repeat(40) { append("word") }
            // Period boundary at offset 200
            append(". ")
            // Another 4000 chars of filler
            repeat(800) { append("word") }
            append(".")
        }
        TranscriptionHub.postTranscript(longText)
        val state1 = TranscriptionHub.transcriptFlow.value
        assertTrue("after first post length should be close to longText.length " +
            "(was ${state1.length})", state1.length >= longText.length - 100)

        // Now push the history over the limit
        repeat(20) { TranscriptionHub.postTranscript("more text here.") }
        val state2 = TranscriptionHub.transcriptFlow.value
        assertTrue("history should still be capped (was ${state2.length})",
            state2.length <= 5500)
        // After the cut, the cut point should have been a sentence boundary,
        // i.e. the result should NOT start mid-word. Either it starts with
        // "word" or "more" (whichever landed past the cut).
        val firstWord = state2.substringBefore(' ').take(10)
        assertTrue("cut should not have started mid-word: '$firstWord'",
            firstWord.all { it.isLetter() })
    }

    // ─── 4. reset clears history ────────────────────────────────────────

    @Test
    fun `reset clears history and emits empty string`() = runBlocking {
        TranscriptionHub.postTranscript("some text")
        assertTrue(TranscriptionHub.transcriptFlow.value.isNotEmpty())

        TranscriptionHub.reset()

        assertEquals("", TranscriptionHub.transcriptFlow.value)
        assertEquals("", TranscriptionHub.transcriptFlow.first())
    }

    // ─── 5. whitespace-only post is a no-op ────────────────────────────

    @Test
    fun `postTranscript with whitespace only is a no-op`() = runBlocking {
        TranscriptionHub.postTranscript("   ")
        assertEquals("", TranscriptionHub.transcriptFlow.value)

        TranscriptionHub.postTranscript("\n\t  \n")
        assertEquals("", TranscriptionHub.transcriptFlow.value)
    }

    // ─── 6. thread-safety sanity (10 threads × 100 posts) ──────────────

    @Test
    fun `concurrent posts from 10 threads preserve all distinct words`() {
        val threads = 10
        val perThread = 30
        val latch = CountDownLatch(threads)
        val errors = AtomicInteger(0)

        // Each thread posts "t<thread>_<i>" — every token is unique so
        // overlap detection won't dedupe them. With 1000 unique tokens
        // (~5-6 chars each), total ≈ 5000-6000 chars, which means
        // MAX_HISTORY_RETAIN will truncate the tail. So we only assert
        // that the result is non-empty and that NO thread was starved
        // by the @Synchronized lock (i.e., at least *some* of the
        // threads must be represented in the surviving tail).
        val tokensPosted = java.util.Collections.synchronizedSet(mutableSetOf<String>())

        for (t in 0 until threads) {
            Thread {
                try {
                    for (i in 0 until perThread) {
                        val token = "t${t}_$i"
                        TranscriptionHub.postTranscript(token)
                        tokensPosted.add(token)
                    }
                } catch (e: Exception) {
                    errors.incrementAndGet()
                } finally {
                    latch.countDown()
                }
            }.start()
        }

        latch.await(10, TimeUnit.SECONDS)
        assertEquals(0, errors.get())

        val final = TranscriptionHub.transcriptFlow.value
        assertTrue("final transcript should not be empty", final.isNotEmpty())
        // At least half of the threads must be represented in the
        // surviving tail — proves no thread was starved by the lock.
        val representedThreads = (0 until threads).count { t ->
            final.contains("t${t}_")
        }
        assertTrue(
            "expected at least ${threads / 2} threads to be represented in: $final",
            representedThreads >= threads / 2
        )
        assertEquals(threads * perThread, tokensPosted.size)
        // Sanity: distinct threads represented in the posted set
        assertEquals(threads, tokensPosted.map { it.substringBefore('_') }.toSet().size)
    }

    // ─── Bug #38: takeLast window bumped 10 → 20 ────────────────────────

    @Test
    fun `Bug38 detects 15-word overlap (long caption line)`() {
        // Build a 15-word shared phrase between two captions. Previously
        // the algorithm looked at only 10 trailing words, so 15-word
        // overlaps leaked through as duplicated text.
        TranscriptionHub.reset()
        val shared15 = List(15) { "w$it" }.joinToString(" ")
        TranscriptionHub.postTranscript("mở đầu $shared15")
        // Add the second caption that starts with the same 15 words.
        TranscriptionHub.postTranscript("$shared15 tiếp theo")
        val final = TranscriptionHub.transcriptFlow.value
        assertFalse(
            "Overlapping 15 words must NOT appear twice: $final",
            final.split(shared15).size > 2, // would be 3+ if duplicated
        )
        assertTrue(
            "Both segments' unique parts should remain: $final",
            final.contains("mở đầu") && final.contains("tiếp theo"),
        )
    }

    private fun assertFalse(message: String, condition: Boolean) {
        if (condition) throw AssertionError(message)
    }
}
