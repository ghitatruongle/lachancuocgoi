package com.example.lachancuocgoi.Analysis.L3.core

import android.util.Log
import com.google.ai.client.generativeai.GenerativeModel
import com.google.ai.client.generativeai.type.generationConfig
import kotlinx.coroutines.withTimeout

class GeminiClient(
    private val apiKeyProvider: ApiKeyProvider,
    private val config: GeminiConfig,
    private val keyHealthTracker: KeyHealthTracker? = null,
    private val onAllKeysExhausted: (() -> Unit)? = null
) {
    companion object {
        private const val TAG = "GeminiClient"
        private const val MIN_INTERVAL_MS = 1000L
        private const val CIRCUIT_BREAKER_THRESHOLD = 5
        private const val CIRCUIT_BREAKER_TIMEOUT_MS = 30_000L
    }

    private enum class CircuitState { CLOSED, OPEN, HALF_OPEN }

    @Volatile private var circuitState = CircuitState.CLOSED
    @Volatile private var consecutiveFailures = 0
    @Volatile private var circuitOpenedAt = 0L

    private var hasNotifiedAllExhausted = false

    @Volatile
    private var lastCallTimestamp = 0L

    private fun shouldAllowRequest(): Boolean {
        return when (circuitState) {
            CircuitState.CLOSED -> true
            CircuitState.HALF_OPEN -> true
            CircuitState.OPEN -> {
                val elapsed = System.currentTimeMillis() - circuitOpenedAt
                if (elapsed >= CIRCUIT_BREAKER_TIMEOUT_MS) {
                    circuitState = CircuitState.HALF_OPEN
                    Log.d(TAG, "Circuit Breaker: HALF_OPEN (testing)")
                    true
                } else {
                    false
                }
            }
        }
    }

    private fun recordSuccess() {
        consecutiveFailures = 0
        if (circuitState == CircuitState.HALF_OPEN) {
            circuitState = CircuitState.CLOSED
            Log.d(TAG, "Circuit Breaker: CLOSED (recovered)")
        }
    }

    private fun recordFailure() {
        consecutiveFailures++
        if (consecutiveFailures >= CIRCUIT_BREAKER_THRESHOLD) {
            circuitState = CircuitState.OPEN
            circuitOpenedAt = System.currentTimeMillis()
            Log.w(TAG, "Circuit Breaker: OPENED (pausing for ${CIRCUIT_BREAKER_TIMEOUT_MS}ms)")
        }
    }

    suspend fun <T> query(
        prompt: String,
        parser: (String, String) -> T
    ): Result<T> {
        if (!shouldAllowRequest()) {
            Log.w(TAG, "Circuit Breaker: Request blocked, retry after timeout")
            return Result.failure(Exception("Circuit breaker open. Retry after ${CIRCUIT_BREAKER_TIMEOUT_MS}ms"))
        }

        val now = System.currentTimeMillis()
        val elapsed = now - lastCallTimestamp
        if (elapsed < MIN_INTERVAL_MS) {
            val waitMs = MIN_INTERVAL_MS - elapsed
            Log.d(TAG, "Rate limiting: waiting ${waitMs}ms before next call")
            kotlinx.coroutines.delay(waitMs)
        }
        lastCallTimestamp = System.currentTimeMillis()

        val startTime = System.currentTimeMillis()
        val keys = apiKeyProvider.getApiKeys()

        if (keys.isEmpty()) {
            return Result.failure(Exception("No API keys available"))
        }

        val activeIndices: List<Int> = keyHealthTracker?.getActiveKeyIndices() ?: keys.indices.toList()

        if (activeIndices.isEmpty()) {
            notifyAllKeysExhausted()
            return Result.failure(Exception("All API keys are in COOLDOWN/EXHAUSTED. Quota resets at 00:00."))
        }

        var lastException: Exception? = null
        hasNotifiedAllExhausted = false

        val fallbackModels = listOf(
            "gemini-3.1-flash-lite",
            "gemini-2.5-flash-lite",
            "gemini-3-flash",
            "gemini-2.5-flash"
        )

        for (keyIndex in activeIndices) {
            val apiKey = keys[keyIndex]
            var keySuccess = false

            for (modelName in fallbackModels) {
                try {
                    val model = createModel(apiKey, modelName)
                    val responseText = queryWithTimeout(model, prompt)
                    val parsed = parser(responseText, modelName)

                    keyHealthTracker?.markSuccess(keyIndex)
                    recordSuccess()
                    val latency = System.currentTimeMillis() - startTime
                    GeminiMetrics.recordCall(success = true, latencyMs = latency, keyIndex = keyIndex)
                    Log.d(TAG, "Query successful with key $keyIndex using model $modelName in ${latency}ms")
                    return Result.success(parsed)

                } catch (e: Exception) {
                    recordFailure()

                    if (e is kotlinx.coroutines.CancellationException) {
                        if (e is kotlinx.coroutines.TimeoutCancellationException) {
                            Log.w(TAG, "Timeout Exception with key $keyIndex model $modelName - Network issues")
                            keyHealthTracker?.markError(keyIndex, e.message)
                            lastException = e
                            break
                        }
                        throw e
                    }

                    Log.e(TAG, "Error with key $keyIndex model $modelName: ${e.message}")
                    lastException = e

                    val msg = e.message?.lowercase() ?: ""
                    val isQuotaError = msg.contains("429") || msg.contains("quota")
                    val isAuthError = msg.contains("403") || msg.contains("api key") || msg.contains("api_key")
                    val isModelNotFound = msg.contains("404") || msg.contains("not found")

                    if (isAuthError) {

                        keyHealthTracker?.markInvalid(keyIndex, e.message)
                        break
                    } else if (isQuotaError || isModelNotFound) {

                        Log.w(TAG, "Quota limit or not found on model $modelName, falling back to next model...")
                        continue
                    } else {

                        keyHealthTracker?.markError(keyIndex, e.message)
                        Log.w(TAG, "Lỗi mạng hoặc server. Dừng thử model tiếp theo trên key này.")
                        break
                    }
                }
            }

            val finalMsg = lastException?.message?.lowercase() ?: ""
            if (finalMsg.contains("429") || finalMsg.contains("quota")) {
                keyHealthTracker?.markQuotaExceeded(keyIndex)
            }
        }

        if (keyHealthTracker?.areAllKeysDown() == true) {
            notifyAllKeysExhausted()
        }

        val latency = System.currentTimeMillis() - startTime
        GeminiMetrics.recordCall(success = false, latencyMs = latency)
        return Result.failure(lastException ?: Exception("All API keys failed"))
    }

    private fun notifyAllKeysExhausted() {
        if (!hasNotifiedAllExhausted) {
            hasNotifiedAllExhausted = true
            Log.e(TAG, "ALL keys exhausted! Quota resets at 00:00.")
            onAllKeysExhausted?.invoke()
        }
    }

    private fun createModel(apiKey: String, modelName: String): GenerativeModel {
        val genConfig = generationConfig {
            temperature = config.temperature
            topK = config.topK
            topP = config.topP
            config.responseMimeType?.let { responseMimeType = it }
        }

        return GenerativeModel(
            modelName = modelName,
            apiKey = apiKey,
            generationConfig = genConfig
        )
    }

    private suspend fun queryWithTimeout(
        model: GenerativeModel,
        prompt: String
    ): String {
        val response = withTimeout(config.timeoutMs) {
            model.generateContent(prompt)
        }

        return response.text ?: throw Exception("Empty response from Gemini")
    }
}
