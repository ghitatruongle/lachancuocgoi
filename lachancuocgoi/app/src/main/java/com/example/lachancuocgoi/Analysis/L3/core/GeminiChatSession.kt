package com.example.lachancuocgoi.Analysis.L3.core

import android.util.Log
import com.example.lachancuocgoi.Analysis.AnalysisResult
import com.example.lachancuocgoi.RiskLevel
import com.google.ai.client.generativeai.Chat
import com.google.ai.client.generativeai.GenerativeModel
import com.google.ai.client.generativeai.type.generationConfig
import com.google.ai.client.generativeai.type.Content
import kotlinx.coroutines.sync.Mutex
import kotlinx.coroutines.sync.withLock
import kotlinx.coroutines.delay
import kotlinx.coroutines.withTimeout

/**
 * Quản lý conversation session với Gemini API.
 * 
 * Features:
 * - Maintain single chat session cho mỗi cuộc gọi
 * - Auto-switch API keys với context preservation
 * - Rate limiting để tránh quota exhaustion
 * - Thread-safe operations với Mutex
 */
class GeminiChatSession(
    private val apiKeyProvider: ApiKeyProvider,
    private val config: GeminiConfig,
    private val keyHealthTracker: KeyHealthTracker? = null
) {
    companion object {
        private const val TAG = "GeminiChatSession"
        private const val MIN_INTERVAL_MS = 1000L  // Minimum 1s between calls
    }
    
    // Current active chat session
    private var currentChat: Chat? = null
    private var currentKeyIndex = 0
    private var currentModelIndex = 0
    private var hasNotifiedAllExhausted = false
    
    // Priority order for Gemini models
    private val fallbackModels = listOf(
        "gemini-2.5-flash-lite",
        "gemini-3-flash-preview",
        "gemini-2.5-flash",
        "gemini-3.1-flash-lite-preview"
    )

    // Track conversation for context preservation
    private val conversationHistory = mutableListOf<String>()
    
    // Lưu lịch sử an toàn của SDK để tránh lỗi Corrupted State
    private var safeHistory: List<Content> = emptyList()
    
    // Thread safety
    private val sessionLock = Mutex()
    
    // Rate limiting
    private var lastCallTime = 0L
    
    /**
     * Gửi message trong chat session hiện tại.
     * 
     * @param text Message content (prompt)
     * @param parser Function để parse response text thành result type
     * @return Result<T> chứa parsed value hoặc error
     */
    suspend fun <T> sendMessage(
        text: String,
        parser: (String, String) -> T
    ): Result<T> = sessionLock.withLock {
        // Rate limiting
        applyRateLimit()
        
        val startTime = System.currentTimeMillis()
        val keys = apiKeyProvider.getApiKeys()
        
        if (keys.isEmpty()) {
            return Result.failure(Exception("No API keys available"))
        }

        // Lấy danh sách key ưu tiên
        val activeIndices = mutableListOf<Int>()
        val bestKey = keyHealthTracker?.getAvailableKeyIndex()
        if (bestKey != null && bestKey >= 0) {
            activeIndices.add(bestKey)
        } else {
            activeIndices.add(currentKeyIndex)
        }
        val otherKeys = keyHealthTracker?.getActiveKeyIndices()?.filter { it != activeIndices[0] } 
            ?: (0 until keys.size).filter { it != activeIndices[0] }
        activeIndices.addAll(otherKeys)

        if (activeIndices.isEmpty() && keyHealthTracker != null) {
            return Result.failure(Exception("All API keys are exhausted or in cooldown"))
        }

        // Bắt đầu vòng lặp fallback (tương tự L3Analyzer)
        var lastError: Exception? = null
        var firstKeyAttempted = false

        for (keyIndex in activeIndices) {
            // Refresh timeout nếu phải chuyển API key
            if (activeIndices.size > 1 && !firstKeyAttempted) {
                firstKeyAttempted = true
            } else if (firstKeyAttempted) {
                delay(1000)
            }

            // Nếu đang dùng key mới so với session hiện tại, reset model index về 0
            if (keyIndex != currentKeyIndex) {
                currentKeyIndex = keyIndex
                currentModelIndex = 0
                currentChat = null
            }

            for (modelIndex in currentModelIndex until fallbackModels.size) {
                currentModelIndex = modelIndex
                val modelName = fallbackModels[currentModelIndex]

                // Create or restore chat
                if (currentChat == null) {
                    currentChat = createNewChat(currentKeyIndex, modelName, safeHistory)
                    Log.d(TAG, "Created/Restored chat session with key $currentKeyIndex, model $modelName")
                }

                // Lưu lịch sử an toàn trước khi gọi
                safeHistory = currentChat?.history?.filterNotNull() ?: safeHistory

                try {
                    val response = withTimeout(config.timeoutMs) {
                        applyRateLimit()
                        currentChat!!.sendMessage(text)
                    }

                    val responseText = response.text ?: throw Exception("Empty response from Gemini")
                    val parsed = parser(responseText, modelName)

                    // Track history and mark success
                    conversationHistory.add("User: ${text.take(50)}... | AI: ${responseText.take(50)}...")
                    safeHistory = currentChat?.history?.filterNotNull() ?: safeHistory
                    keyHealthTracker?.markSuccess(currentKeyIndex)

                    val latency = System.currentTimeMillis() - startTime
                    GeminiMetrics.recordCall(success = true, latencyMs = latency)
                    Log.d(TAG, "✓ Message sent successfully in ${latency}ms using $modelName on key $currentKeyIndex")

                    return Result.success(parsed)
                } catch (e: Exception) {
                    lastError = e
                    currentChat = null // Hủy session đang dính lỗi
                    
                    if (e is kotlinx.coroutines.CancellationException && e !is kotlinx.coroutines.TimeoutCancellationException) {
                        throw e
                    }

                    val msg = e.message?.lowercase() ?: ""
                    val isQuotaError = msg.contains("429") || msg.contains("quota")
                    val isAuthError = msg.contains("403") || msg.contains("api key") || msg.contains("api_key")

                    Log.w(TAG, "Error with key $currentKeyIndex, model $modelName: ${e.message}")

                    if (isAuthError) {
                        keyHealthTracker?.markInvalid(currentKeyIndex, e.message)
                        break // Bỏ qua các model khác, nhảy sang key mới
                    } else if (isQuotaError) {
                        // Thử model tiếp theo trên CÙNG 1 key
                        continue 
                    } else if (e is NullPointerException) {
                        Log.w(TAG, "NPE từ SDK. Thử model/key khác.")
                        keyHealthTracker?.markError(currentKeyIndex, e.message)
                        break
                    } else {
                        keyHealthTracker?.markError(currentKeyIndex, e.message)
                        Log.w(TAG, "Lỗi mạng/server (Không phải Quota). Abort.")
                        return Result.failure(e)
                    }
                }
            }

            // Nếu vòng lặp model kết thúc mà vẫn fail, tức là key này đã kiệt quệ => Qua key khác
            keyHealthTracker?.markQuotaExceeded(currentKeyIndex)
            Log.w(TAG, "All models failed on key $currentKeyIndex. Moving to next key.")
        }

        if (keyHealthTracker?.areAllKeysDown() == true) {
            Log.e(TAG, "ALL keys & models exhausted! Quota resets at 00:00.")
        }

        return Result.failure(lastError ?: Exception("Unknown error during chat session fallback"))
    }
    
    /**
     * Đóng chat session hiện tại.
     */
    fun close() {
        currentChat = null
        conversationHistory.clear()
        safeHistory = emptyList() // Clear an toàn
        Log.d(TAG, "Chat session closed")
    }
    
    /**
     * Tạo Chat instance mới với API key, model name, và khôi phục Context.
     */
    private fun createNewChat(keyIndex: Int, modelName: String, history: List<Content> = emptyList()): Chat {
        val keys = apiKeyProvider.getApiKeys()
        val apiKey = keys[keyIndex]
        
        val genConfig = generationConfig {
            temperature = config.temperature
            topK = config.topK
            topP = config.topP
            config.responseMimeType?.let { responseMimeType = it }
        }
        
        val model = GenerativeModel(
            modelName = modelName,
            apiKey = apiKey,
            generationConfig = genConfig
        )
        
        return model.startChat(history)
    }
    
    /**
     * Apply rate limiting để tránh quota exhaustion.
     */
    private suspend fun applyRateLimit() {
        val now = System.currentTimeMillis()
        val timeSinceLastCall = now - lastCallTime
        
        if (timeSinceLastCall < MIN_INTERVAL_MS) {
            val waitTime = MIN_INTERVAL_MS - timeSinceLastCall
            delay(waitTime)
        }
        
        lastCallTime = System.currentTimeMillis()
    }
}