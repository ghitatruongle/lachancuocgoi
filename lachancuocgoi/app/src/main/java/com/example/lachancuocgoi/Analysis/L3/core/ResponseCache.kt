package com.example.lachancuocgoi.Analysis.L3.core

import com.example.lachancuocgoi.RiskLevel
import java.security.MessageDigest

/**
 * Simple LRU cache cho Gemini responses.
 *
 * Features:
 * - LRU eviction khi đạt maxSize
 * - Dynamic TTL based on risk level (RED=30s, ORANGE=2min, YELLOW/GREEN=5min)
 * - Thread-safe với synchronized
 *
 * @param maxSize Số lượng entries tối đa
 */
class ResponseCache<T>(
    private val maxSize: Int = 100
) {

    companion object {
        private const val TTL_RED_MS = 30_000L      // 30 seconds for RED (high risk changes fast)
        private const val TTL_ORANGE_MS = 120_000L // 2 minutes for ORANGE
        private const val TTL_DEFAULT_MS = 300_000L // 5 minutes default (GREEN/YELLOW)
    }

    private val cache = object : LinkedHashMap<String, CacheEntry<T>>(
        maxSize,
        0.75f,
        true
    ) {
        override fun removeEldestEntry(eldest: MutableMap.MutableEntry<String, CacheEntry<T>>): Boolean {
            return size > maxSize
        }
    }

    private fun getTtlForRisk(riskLevel: RiskLevel?): Long {
        return when (riskLevel) {
            RiskLevel.RED -> TTL_RED_MS
            RiskLevel.ORANGE -> TTL_ORANGE_MS
            else -> TTL_DEFAULT_MS
        }
    }

    @Synchronized
    fun get(key: String, riskLevel: RiskLevel? = null): T? {
        val hashedKey = hashKey(key)
        val entry = cache[hashedKey] ?: return null

        val ttl = getTtlForRisk(riskLevel)
        val now = System.currentTimeMillis()
        return if (now - entry.timestamp < ttl) {
            entry.value
        } else {
            cache.remove(hashedKey)
            null
        }
    }

    @Synchronized
    fun put(key: String, value: T, riskLevel: RiskLevel? = null) {
        val hashedKey = hashKey(key)
        val ttl = getTtlForRisk(riskLevel)
        cache[hashedKey] = CacheEntry(value, System.currentTimeMillis(), ttl)
    }

    private fun hashKey(text: String): String {
        val normalized = text.trim().lowercase()
        val bytes = MessageDigest.getInstance("SHA-256").digest(normalized.toByteArray())
        return bytes.joinToString("") { "%02x".format(it) }
    }

    @Synchronized
    fun getStats(): CacheStats {
        return CacheStats(
            size = cache.size,
            maxSize = maxSize
        )
    }

    @Synchronized
    fun clear() {
        cache.clear()
    }

    private data class CacheEntry<T>(
        val value: T,
        val timestamp: Long,
        val ttlMs: Long
    )
}

/**
 * Statistics về cache usage.
 */
data class CacheStats(
    val size: Int,
    val maxSize: Int
) {
    val usagePercent: Float
        get() = if (maxSize > 0) (size.toFloat() / maxSize) * 100 else 0f
}
