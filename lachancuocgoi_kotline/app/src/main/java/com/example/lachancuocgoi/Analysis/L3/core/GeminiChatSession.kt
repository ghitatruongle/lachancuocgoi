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

class GeminiChatSession(
    private val apiKeyProvider: ApiKeyProvider,
    private val config: GeminiConfig,
    private val keyHealthTracker: KeyHealthTracker? = null
) {
    companion object {
        private const val TAG = "GeminiChatSession"
        private const val MIN_INTERVAL_MS = 1000L
    }

    private var currentChat: Chat? = null
    private var currentKeyIndex = 0
    private var currentModelIndex = 0
    private var hasNotifiedAllExhausted = false

    private val fallbackModels = listOf(
        "gemini-2.5-flash-lite",
        "gemini-3-flash-preview",
        "gemini-2.5-flash",
        "gemini-3.1-flash-lite-preview"
    )

    private val conversationHistory = mutableListOf<String>()

    private var safeHistory: List<Content> = emptyList()

    private val sessionLock = Mutex()

    private var lastCallTime = 0L

    suspend fun <T> sendMessage(
        text: String,
        parser: (String, String) -> T
    ): Result<T> = sessionLock.withLock {

        applyRateLimit()

        val startTime = System.currentTimeMillis()
        val keys = apiKeyProvider.getApiKeys()

        if (keys.isEmpty()) {
            return Result.failure(Exception("No API keys available"))
        }

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

        var lastError: Exception? = null
        var firstKeyAttempted = false

        for (keyIndex in activeIndices) {

            if (activeIndices.size > 1 && !firstKeyAttempted) {
                firstKeyAttempted = true
            } else if (firstKeyAttempted) {
                delay(1000)
            }

            if (keyIndex != currentKeyIndex) {
                currentKeyIndex = keyIndex
                currentModelIndex = 0
                currentChat = null
            }

            for (modelIndex in currentModelIndex until fallbackModels.size) {
                currentModelIndex = modelIndex
                val modelName = fallbackModels[currentModelIndex]

                if (currentChat == null) {
                    currentChat = createNewChat(currentKeyIndex, modelName, safeHistory)
                    Log.d(TAG, "Created/Restored chat session with key $currentKeyIndex, model $modelName")
                }

                safeHistory = currentChat?.history?.filterNotNull() ?: safeHistory

                try {
                    val response = withTimeout(config.timeoutMs) {
                        applyRateLimit()
                        currentChat!!.sendMessage(text)
                    }

                    val responseText = response.text ?: throw Exception("Empty response from Gemini")
                    val parsed = parser(responseText, modelName)

                    conversationHistory.add("User: ${text.take(50)}... | AI: ${responseText.take(50)}...")
                    safeHistory = currentChat?.history?.filterNotNull() ?: safeHistory
                    keyHealthTracker?.markSuccess(currentKeyIndex)

                    val latency = System.currentTimeMillis() - startTime
                    GeminiMetrics.recordCall(success = true, latencyMs = latency)
                    Log.d(TAG, "✓ Message sent successfully in ${latency}ms using $modelName on key $currentKeyIndex")

                    return Result.success(parsed)
                } catch (e: Exception) {
                    lastError = e
                    currentChat = null

                    if (e is kotlinx.coroutines.CancellationException && e !is kotlinx.coroutines.TimeoutCancellationException) {
                        throw e
                    }

                    val msg = e.message?.lowercase() ?: ""
                    val isQuotaError = msg.contains("429") || msg.contains("quota")
                    val isAuthError = msg.contains("403") || msg.contains("api key") || msg.contains("api_key")

                    Log.w(TAG, "Error with key $currentKeyIndex, model $modelName: ${e.message}")

                    if (isAuthError) {
                        keyHealthTracker?.markInvalid(currentKeyIndex, e.message)
                        break
                    } else if (isQuotaError) {

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

            keyHealthTracker?.markQuotaExceeded(currentKeyIndex)
            Log.w(TAG, "All models failed on key $currentKeyIndex. Moving to next key.")
        }

        if (keyHealthTracker?.areAllKeysDown() == true) {
            Log.e(TAG, "ALL keys & models exhausted! Quota resets at 00:00.")
        }

        return Result.failure(lastError ?: Exception("Unknown error during chat session fallback"))
    }

    fun close() {
        currentChat = null
        conversationHistory.clear()
        safeHistory = emptyList()
        Log.d(TAG, "Chat session closed")
    }

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
