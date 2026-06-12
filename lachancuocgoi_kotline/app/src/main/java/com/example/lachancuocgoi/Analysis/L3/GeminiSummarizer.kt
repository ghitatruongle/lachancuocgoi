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
    
    // ============ NEW: Sử dụng GeminiClient thống nhất ============
    private val geminiClient = GeminiClient(
        apiKeyProvider = apiKeyProvider,
        config = GeminiConfig.forSummarization(),
        keyHealthTracker = keyHealthTracker
    )
    
    /**
     * Tóm tắt đoạn hội thoại thành 1 câu ngắn gọn.
     * 
     * @param text Nội dung cuộc gọi cần tóm tắt
     * @return Tóm tắt 1 câu hoặc error message
     */
    suspend fun summarize(text: String): String = withContext(Dispatchers.IO) {
        // Validation
        val trimmed = text.trim()
        val wordCount = trimmed.split(Regex("\\s+")).size
        
        if (wordCount < MIN_WORDS) {
            return@withContext "Không đủ nội dung để tóm tắt (cần ít nhất $MIN_WORDS từ)"
        }
        
        // Create prompt
        val prompt = createPrompt(trimmed)
        
        // Query Gemini thông qua unified client
        val result = geminiClient.query(prompt) { responseText, _ ->
            responseText.trim()  // Parser đơn giản - chỉ trim whitespace
        }
        
        // Handle result
        return@withContext result.getOrElse { error ->
            Log.e(TAG, "Summarization failed: ${error.message}", error)
            "Lỗi tóm tắt: ${error.message}"
        }
    }
    
    /**
     * Tạo prompt cho summarization task.
     */
    private fun createPrompt(text: String): String {
        return PromptBuilder.buildSummarizationPrompt(text)
    }
}
