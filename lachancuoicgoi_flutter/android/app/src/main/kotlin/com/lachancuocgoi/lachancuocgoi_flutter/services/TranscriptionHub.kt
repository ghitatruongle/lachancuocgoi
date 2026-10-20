package com.lachancuocgoi.lachancuocgoi_flutter.services

import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.asStateFlow
import java.util.Locale

object TranscriptionHub {
    private val _transcriptFlow = MutableStateFlow("")
    val transcriptFlow = _transcriptFlow.asStateFlow()

    private var fullHistory = ""

    private const val MAX_COMPARE_LENGTH = 2000

    private const val MAX_HISTORY_RETAIN = 12000

    private val WHITESPACE_REGEX = Regex("\\s+")

    @Synchronized
    fun postTranscript(newText: String) {
        val cleanedNewText = newText.trim()
        if (cleanedNewText.isEmpty()) return

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

    private fun findCutPoint(text: String, targetLength: Int): Int {
        val boundaryChars = charArrayOf('.', '?', '!', '。')
        val searchEnd = minOf(text.length - 1, targetLength + 200)
        for (i in targetLength..searchEnd) {
            val c = text[i]
            if (c in boundaryChars) {

                var endIdx = i + 1
                while (endIdx < text.length && text[endIdx] == ' ') endIdx++
                return endIdx
            }
        }
        val spaceIdx = text.indexOf(' ', targetLength)
        return if (spaceIdx != -1 && spaceIdx < text.length - 1) spaceIdx + 1 else targetLength
    }
}

