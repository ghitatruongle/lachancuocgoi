package com.example.lachancuocgoi.Analysis.L3

import android.util.Log
import com.example.lachancuocgoi.Analysis.L3.core.*
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.withContext

class GeminiSummarizer(
    private val apiKeyProvider: ApiKeyProvider = BuildConfigApiKeyProvider(),
    private val keyHealthTracker: KeyHealthTracker? = null
) {

    companion object {
        private const val TAG = "GeminiSummarizer"
        private const val MIN_WORDS = 5
    }

    private val geminiClient = GeminiClient(
        apiKeyProvider = apiKeyProvider,
        config = GeminiConfig.forSummarization(),
        keyHealthTracker = keyHealthTracker
    )

    suspend fun summarize(text: String): String = withContext(Dispatchers.IO) {

        val trimmed = text.trim()
        val wordCount = trimmed.split(Regex("\\s+")).size

        if (wordCount < MIN_WORDS) {
            return@withContext "Không đủ nội dung để tóm tắt (cần ít nhất $MIN_WORDS từ)"
        }

        val prompt = createPrompt(trimmed)

        val result = geminiClient.query(prompt) { responseText, _ ->
            responseText.trim()
        }

        return@withContext result.getOrElse { error ->
            Log.e(TAG, "Summarization failed: ${error.message}", error)
            "Lỗi tóm tắt: ${error.message}"
        }
    }

    private fun createPrompt(text: String): String {
        return PromptBuilder.buildSummarizationPrompt(text)
    }
}
