package com.lachancuocgoi.lachancuocgoi_flutter.services

import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.asStateFlow
import java.util.Locale

object TranscriptionHub {
    private val _transcriptFlow = MutableStateFlow("")
    val transcriptFlow = _transcriptFlow.asStateFlow()

    private var fullHistory = ""
    private const val MAX_COMPARE_LENGTH = 1000
    private const val MAX_HISTORY_RETAIN = 5000

    @Synchronized
    fun postTranscript(newText: String) {
        val cleanedNewText = newText.trim()
        if (cleanedNewText.isEmpty()) return

        // Giới hạn bộ nhớ lịch sử — cắt tại ranh giới từ
        if (fullHistory.length > MAX_HISTORY_RETAIN) {
            val cutPoint = fullHistory.length - MAX_COMPARE_LENGTH
            val safeCutPoint = fullHistory.indexOf(' ', cutPoint).let { spaceIdx ->
                if (spaceIdx != -1) spaceIdx + 1 else cutPoint
            }
            fullHistory = fullHistory.substring(safeCutPoint)
        }

        val historyToCompare = if (fullHistory.length > MAX_COMPARE_LENGTH) {
            fullHistory.substring(fullHistory.length - MAX_COMPARE_LENGTH)
        } else {
            fullHistory
        }

        val wordsHistory = historyToCompare.split(Regex("\\s+")).filter { it.isNotBlank() }.takeLast(10)
        val wordsNew = cleanedNewText.split(Regex("\\s+")).filter { it.isNotBlank() }

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

    fun reset() {
        fullHistory = ""
        _transcriptFlow.value = ""
    }
}
