package com.lachancuocgoi.lachancuocgoi_flutter.services

import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.asStateFlow
import java.util.Locale

object TranscriptionHub {
    private val _transcriptFlow = MutableStateFlow("")
    val transcriptFlow = _transcriptFlow.asStateFlow()

    private var fullHistory = ""
    // Bug fix (review): MAX_COMPARE_LENGTH was 1000 but takeLast was bumped
    // to 20 words (Bug #38). With 20 words × ~50 chars/word = ~1000 chars,
    // the 1000-char window was barely enough. Increased to 2000 to ensure
    // the full 20-word tail is always available for overlap detection.
    private const val MAX_COMPARE_LENGTH = 2000
    // Longer retain so early scam setup (authority intro) survives long calls.
    private const val MAX_HISTORY_RETAIN = 12000
    // Pre-compile regex to avoid re-compilation on every postTranscript call.
    private val WHITESPACE_REGEX = Regex("\\s+")

    @Synchronized
    fun postTranscript(newText: String) {
        val cleanedNewText = newText.trim()
        if (cleanedNewText.isEmpty()) return

        // Giới hạn bộ nhớ lịch sử — giữ tối đa MAX_HISTORY_RETAIN chars từ cuối
        if (fullHistory.length > MAX_HISTORY_RETAIN) {
            val targetLength = MAX_HISTORY_RETAIN - MAX_COMPARE_LENGTH
            if (targetLength > 0 && targetLength < fullHistory.length) {
                val safeCutPoint = findCutPoint(fullHistory, targetLength)
                fullHistory = fullHistory.substring(safeCutPoint)
            } else {
                fullHistory = fullHistory.takeLast(MAX_HISTORY_RETAIN)
            }
        }

        val historyToCompare = if (fullHistory.length > MAX_COMPARE_LENGTH) {
            fullHistory.substring(fullHistory.length - MAX_COMPARE_LENGTH)
        } else {
            fullHistory
        }

        val wordsHistory = historyToCompare.split(WHITESPACE_REGEX).filter { it.isNotBlank() }.takeLast(20)
        val wordsNew = cleanedNewText.split(WHITESPACE_REGEX).filter { it.isNotBlank() }

        var overlapIndex = 0
        // Bug #38 fix: 10 → 20. Same reasoning as SpeechToTextManager — long
        // Vietnamese sentences (accessibility captions from system Live
        // Caption) often exceed 10 words, so 10 was missing real overlaps
        // and showing the same caption twice.
        for (i in 1..wordsNew.size.coerceAtMost(wordsHistory.size)) {
            val historySub = wordsHistory.takeLast(i).joinToString(" ").lowercase(Locale.ROOT)
            val newSub = wordsNew.take(i).joinToString(" ").lowercase(Locale.ROOT)
            if (historySub == newSub) {
                overlapIndex = i
            }
        }

        val actualNewContent = if (overlapIndex > 0) {
            wordsNew.drop(overlapIndex).joinToString(" ")
        } else {
            cleanedNewText
        }

        if (actualNewContent.isNotBlank()) {
            fullHistory = (fullHistory + " " + actualNewContent).trim()
            _transcriptFlow.value = fullHistory
        }
    }

    @Synchronized
    fun reset() {
        fullHistory = ""
        _transcriptFlow.value = ""
    }

    /**
     * Sprint 2 (C3): when we have to drop the front of [text] because
     * the buffer is over [MAX_HISTORY_RETAIN], prefer to cut just after
     * the next sentence boundary (`.` `?` `!` or Vietnamese `。`) so we
     * don't split a sentence in half. If no boundary exists within
     * `targetLength..targetLength+200`, fall back to the next space
     * (preserves the previous behaviour).
     */
    private fun findCutPoint(text: String, targetLength: Int): Int {
        val boundaryChars = charArrayOf('.', '?', '!', '。')
        val searchEnd = minOf(text.length - 1, targetLength + 200)
        for (i in targetLength..searchEnd) {
            val c = text[i]
            if (c in boundaryChars) {
                // Cut just after the punctuation + any trailing spaces.
                var endIdx = i + 1
                while (endIdx < text.length && text[endIdx] == ' ') endIdx++
                return endIdx
            }
        }
        val spaceIdx = text.indexOf(' ', targetLength)
        return if (spaceIdx != -1 && spaceIdx < text.length - 1) spaceIdx + 1 else targetLength
    }
}
