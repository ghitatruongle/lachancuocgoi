package com.lachancuocgoi.lachancuocgoi_flutter.services.stt

/**
 * Pure function for deduplicating transcript overlaps.
 *
 * Extracted from `SpeechToTextManager.kt` (Wave 2 refactor). This is a pure
 * function with no Android dependencies, making it easy to unit test.
 *
 * Bug #34 fix: maxCheck bumped 15 → 30 words to handle longer Vietnamese
 * scam-call phrases.
 */
object TranscriptOverlapJoiner {

    /**
     * Appends [newSegment] to [existing] with overlap detection to avoid
     * duplicate words when both segments share a common tail/head.
     *
     * @param existing The current transcript text.
     * @param newSegment The new segment to append.
     * @return The combined transcript with overlaps deduplicated.
     */
    fun appendWithOverlapDetection(existing: String, newSegment: String): String {
        if (existing.isBlank()) return newSegment

        val existingWords = existing.split(Regex("\\s+")).filter { it.isNotBlank() }
        val newWords = newSegment.split(Regex("\\s+")).filter { it.isNotBlank() }

        if (existingWords.isEmpty() || newWords.isEmpty()) {
            return if (existing.isBlank()) newSegment else "$existing\n$newSegment"
        }

        var bestOverlap = 0
        // Sprint 2 (C2): bumped from 6 → 15 words. 6 was too short for
        // Vietnamese utterances which often repeat 7-12 word phrases
        // (e.g. "tôi đang ở bưu điện huyện ba vì").
        // Bug #34 fix: bumped further 15 → 30 words. Field reports on long
        // scam-call scripts showed 15 was still too short — attackers reuse
        // 18-25 word phrases ("tôi là cán bộ điều tra thuộc cơ quan cảnh
        // sát điều tra bộ công an" is 16 words alone). The cost is bounded
        // (still O(30) per check) and the savings on duplicate-word display
        // are worth it.
        val maxCheck = minOf(existingWords.size, newWords.size, 30)
        for (len in 1..maxCheck) {
            val tailExisting = existingWords.takeLast(len).joinToString(" ").lowercase()
            val headNew = newWords.take(len).joinToString(" ").lowercase()
            if (tailExisting == headNew) {
                bestOverlap = len
            }
        }

        val dedupedNew = if (bestOverlap > 0) {
            newWords.drop(bestOverlap).joinToString(" ")
        } else {
            newSegment
        }

        return if (dedupedNew.isBlank()) existing else "$existing\n$dedupedNew"
    }
}
