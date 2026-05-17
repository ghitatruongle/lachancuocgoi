package com.example.lachancuocgoi.Analysis.L3.core

import java.util.concurrent.atomic.AtomicInteger
import java.util.concurrent.atomic.AtomicLong

/**
 * Metrics tracker cho Gemini API usage.
 * Thread-safe với atomic operations.
 */
object GeminiMetrics {
    
    private val totalCalls = AtomicInteger(0)
    private val successCalls = AtomicInteger(0)
    private val failureCalls = AtomicInteger(0)
    private val cacheHits = AtomicInteger(0)
    private val cacheMisses = AtomicInteger(0)
    private val totalLatency = AtomicLong(0)
    
    // Per-key metrics
    private val callsPerKey = java.util.concurrent.ConcurrentHashMap<Int, AtomicInteger>()
    private val errorsPerKey = java.util.concurrent.ConcurrentHashMap<Int, AtomicInteger>()
    
    /**
     * Record một API call.
     */
    fun recordCall(success: Boolean, latencyMs: Long, keyIndex: Int = -1) {
        totalCalls.incrementAndGet()
        if (success) {
            successCalls.incrementAndGet()
        } else {
            failureCalls.incrementAndGet()
            if (keyIndex >= 0) {
                errorsPerKey.getOrPut(keyIndex) { AtomicInteger(0) }.incrementAndGet()
            }
        }
        totalLatency.addAndGet(latencyMs)
        if (keyIndex >= 0) {
            callsPerKey.getOrPut(keyIndex) { AtomicInteger(0) }.incrementAndGet()
        }
    }
    
    /**
     * Record cache hit.
     */
    fun recordCacheHit() {
        cacheHits.incrementAndGet()
    }
    
    /**
     * Record cache miss.
     */
    fun recordCacheMiss() {
        cacheMisses.incrementAndGet()
    }
    
    /**
     * Get snapshot của metrics hiện tại.
     */
    fun getSnapshot(): MetricsSnapshot {
        val calls = totalCalls.get()
        val hits = cacheHits.get()
        val misses = cacheMisses.get()
        val totalRequests = hits + misses
        
        // Per-key summary
        val keySummary = callsPerKey.map { (idx, counter) ->
            val errors = errorsPerKey[idx]?.get() ?: 0
            KeyMetricSummary(index = idx, calls = counter.get(), errors = errors)
        }.sortedBy { it.index }
        
        return MetricsSnapshot(
            totalApiCalls = calls,
            successCalls = successCalls.get(),
            failureCalls = failureCalls.get(),
            cacheHits = hits,
            cacheMisses = misses,
            averageLatencyMs = if (calls > 0) totalLatency.get() / calls else 0,
            cacheHitRate = if (totalRequests > 0) hits.toFloat() / totalRequests else 0f,
            perKeyMetrics = keySummary
        )
    }
    
    /**
     * Reset tất cả metrics (for testing).
     */
    fun reset() {
        totalCalls.set(0)
        successCalls.set(0)
        failureCalls.set(0)
        cacheHits.set(0)
        cacheMisses.set(0)
        totalLatency.set(0)
        callsPerKey.clear()
        errorsPerKey.clear()
    }
}

/**
 * Snapshot của metrics tại một thời điểm.
 */
data class KeyMetricSummary(
    val index: Int,
    val calls: Int,
    val errors: Int
) {
    val errorRate: Float get() = if (calls > 0) errors.toFloat() / calls else 0f
}

data class MetricsSnapshot(
    val totalApiCalls: Int,
    val successCalls: Int,
    val failureCalls: Int,
    val cacheHits: Int,
    val cacheMisses: Int,
    val averageLatencyMs: Long,
    val cacheHitRate: Float,
    val perKeyMetrics: List<KeyMetricSummary> = emptyList()
) {
    val successRate: Float
        get() = if (totalApiCalls > 0) successCalls.toFloat() / totalApiCalls else 0f
    
    val failureRate: Float
        get() = if (totalApiCalls > 0) failureCalls.toFloat() / totalApiCalls else 0f
    
    override fun toString(): String {
        val keyLines = if (perKeyMetrics.isNotEmpty()) {
            perKeyMetrics.joinToString("\n") { km ->
                "  Key ${km.index}: ${km.calls} calls, ${km.errors} errors (${(km.errorRate * 100).toInt()}%)"
            }
        } else ""
        return """
            Gemini Metrics:
            - API Calls: $totalApiCalls (✓ $successCalls, ✗ $failureCalls)
            - Success Rate: ${(successRate * 100).toInt()}%
            - Cache: $cacheHits hits, $cacheMisses misses
            - Cache Hit Rate: ${(cacheHitRate * 100).toInt()}%
            - Avg Latency: ${averageLatencyMs}ms
            $keyLines
        """.trimIndent()
    }
}
