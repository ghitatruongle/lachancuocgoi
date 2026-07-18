package com.lachancuocgoi.lachancuocgoi_flutter.services.stt

import org.junit.Assert.assertEquals
import org.junit.Test

/**
 * Unit tests for [TranscriptOverlapJoiner] (Wave 4).
 *
 * Wave 2 refactor extracted this pure function from SpeechToTextManager.
 * Verifies it preserves original behavior including Bug #34 fix (30-word overlap).
 */
class TranscriptOverlapJoinerTest {

    @Test
    fun `empty existing returns new segment`() {
        val result = TranscriptOverlapJoiner.appendWithOverlapDetection("", "hello world")
        assertEquals("hello world", result)
    }

    @Test
    fun `blank existing returns new segment`() {
        val result = TranscriptOverlapJoiner.appendWithOverlapDetection("   ", "hello world")
        assertEquals("hello world", result)
    }

    @Test
    fun `no overlap returns combined`() {
        val existing = "chuyển khoản"
        val newSegment = "ngân hàng"
        val result = TranscriptOverlapJoiner.appendWithOverlapDetection(existing, newSegment)
        assertEquals("chuyển khoản\nngân hàng", result)
    }

    @Test
    fun `single word overlap is removed`() {
        val existing = "chuyển"
        val newSegment = "chuyển khoản"
        val result = TranscriptOverlapJoiner.appendWithOverlapDetection(existing, newSegment)
        assertEquals("chuyển\nkhoản", result)
    }

    @Test
    fun `multiple word overlap is removed for Bug 34 up to 30 words`() {
        val existing = "tôi là cán bộ điều tra thuộc cơ quan cảnh sát"
        val newSegment = "cơ quan cảnh sát điều tra bộ công an"
        val result = TranscriptOverlapJoiner.appendWithOverlapDetection(existing, newSegment)
        // Should detect "cơ quan cảnh sát" overlap and remove it
        assertEquals(
            "tôi là cán bộ điều tra thuộc cơ quan cảnh sát\nđiều tra bộ công an",
            result,
        )
    }

    @Test
    fun `long Vietnamese scam phrase overlap works`() {
        // 16-word overlap (long Vietnamese scam phrase)
        val phrase = listOf(
            "tôi", "là", "cán", "bộ", "điều", "tra", "thuộc", "cơ",
            "quan", "cảnh", "sát", "điều", "tra", "bộ", "công", "an",
        )
        val existing = phrase.joinToString(" ")
        val newSegment = phrase.joinToString(" ") + " hà nội"
        val result = TranscriptOverlapJoiner.appendWithOverlapDetection(existing, newSegment)
        // Full 16-word overlap should be removed
        assertEquals("$existing\nhà nội", result)
    }

    @Test
    fun `case insensitive matching works`() {
        val existing = "Chuyển Khoản"
        val newSegment = "chuyển khoản ngân hàng"
        val result = TranscriptOverlapJoiner.appendWithOverlapDetection(existing, newSegment)
        // Should match "chuyển khoản" (case-insensitive) and remove overlap
        assertEquals("Chuyển Khoản\nngân hàng", result)
    }

    @Test
    fun `no words in either returns combined with newline`() {
        val result = TranscriptOverlapJoiner.appendWithOverlapDetection("", "")
        assertEquals("", result)
    }

    @Test
    fun `overlap longer than new segment keeps new as-is`() {
        val existing = "chuyển khoản ngân hàng"
        val newSegment = "chuyển"
        val result = TranscriptOverlapJoiner.appendWithOverlapDetection(existing, newSegment)
        // No overlap found (new is subset of existing but tail doesn't match head)
        assertEquals("chuyển khoản ngân hàng\nchuyển", result)
    }
}
