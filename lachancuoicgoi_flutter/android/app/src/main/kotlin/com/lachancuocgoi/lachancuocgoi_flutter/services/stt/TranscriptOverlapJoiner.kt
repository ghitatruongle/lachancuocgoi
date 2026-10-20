package com.lachancuocgoi.lachancuocgoi_flutter.services.stt

object TranscriptOverlapJoiner {

    fun appendWithOverlapDetection(existing: String, newSegment: String): String {
        if (existing.isBlank()) return newSegment

        val existingWords = existing.split(Regex("\\s+")).filter { it.isNotBlank() }
        val newWords = newSegment.split(Regex("\\s+")).filter { it.isNotBlank() }

        if (existingWords.isEmpty() || newWords.isEmpty()) {
            return if (existing.isBlank()) newSegment else "$existing\n$newSegment"
        }

        var bestOverlap = 0

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

