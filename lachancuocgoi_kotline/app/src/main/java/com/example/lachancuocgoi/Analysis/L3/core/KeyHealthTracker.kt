package com.example.lachancuocgoi.Analysis.L3.core

import android.util.Log
import java.util.Calendar
import java.util.concurrent.atomic.AtomicInteger

class KeyHealthTracker(private val apiKeyProvider: ApiKeyProvider) {

    companion object {
        private const val TAG = "KeyHealthTracker"
    }

    enum class KeyStatus {
        ACTIVE,
        COOLDOWN,
        EXHAUSTED
    }

    data class KeyHealth(
        val index: Int,
        val status: KeyStatus,
        val consecutiveErrors: Int,
        val cooldownUntilMs: Long,
        val lastErrorTimeMs: Long,
        val lastErrorMessage: String?
    )

    private val keyStatuses = mutableMapOf<Int, KeyStatus>()
    private val keyConsecutiveErrors = mutableMapOf<Int, AtomicInteger>()
    private val keyCooldownUntil = mutableMapOf<Int, Long>()
    private val keyLastErrorTime = mutableMapOf<Int, Long>()
    private val keyLastErrorMsg = mutableMapOf<Int, String?>()

    @Volatile
    private var preferredKeyIndex: Int = 0

    @Synchronized
    fun markQuotaExceeded(keyIndex: Int) {
        val cooldownUntil = nextMidnightMs()
        keyStatuses[keyIndex] = KeyStatus.COOLDOWN
        keyCooldownUntil[keyIndex] = cooldownUntil
        keyLastErrorTime[keyIndex] = System.currentTimeMillis()
        keyLastErrorMsg[keyIndex] = "429 Quota exceeded"
        Log.w(TAG, "Key $keyIndex hit quota limit. Cooldown until ${formatTime(cooldownUntil)}")
    }

    @Synchronized
    fun markInvalid(keyIndex: Int, message: String? = null) {
        keyStatuses[keyIndex] = KeyStatus.EXHAUSTED
        keyLastErrorTime[keyIndex] = System.currentTimeMillis()
        keyLastErrorMsg[keyIndex] = message ?: "403 Forbidden / Invalid key"
        Log.e(TAG, "Key $keyIndex is INVALID/REVOKED: $message. Will not retry.")
    }

    @Synchronized
    fun markSuccess(keyIndex: Int) {
        keyStatuses[keyIndex] = KeyStatus.ACTIVE
        keyConsecutiveErrors[keyIndex]?.set(0)
        keyCooldownUntil.remove(keyIndex)
        keyLastErrorMsg.remove(keyIndex)
        preferredKeyIndex = keyIndex
        Log.d(TAG, "Key $keyIndex SUCCESS → ACTIVE")
    }

    @Synchronized
    fun markError(keyIndex: Int, message: String? = null) {
        val errors = keyConsecutiveErrors.getOrPut(keyIndex) { AtomicInteger(0) }
        val count = errors.incrementAndGet()
        keyLastErrorTime[keyIndex] = System.currentTimeMillis()
        keyLastErrorMsg[keyIndex] = message

        if (count >= 3) {
            keyStatuses[keyIndex] = KeyStatus.COOLDOWN
            keyCooldownUntil[keyIndex] = nextMidnightMs()
            Log.w(TAG, "Key $keyIndex has $count consecutive errors → COOLDOWN until 00:00")
        } else {
            Log.d(TAG, "Key $keyIndex error #$count (not yet threshold)")
        }
    }

    @Synchronized
    fun getAvailableKeyIndex(): Int {
        recoverCooldownKeysIfNeeded()

        val keys = apiKeyProvider.getApiKeys()
        if (keys.isEmpty()) return -1

        if (preferredKeyIndex in keys.indices && keyStatuses[preferredKeyIndex] == KeyStatus.ACTIVE) {
            return preferredKeyIndex
        }

        for (offset in keys.indices) {
            val idx = (preferredKeyIndex + offset + 1) % keys.size
            if (keyStatuses[idx] == null || keyStatuses[idx] == KeyStatus.ACTIVE) {
                return idx
            }
        }

        Log.e(TAG, "No ACTIVE keys available! Statuses: $keyStatuses")
        return -1
    }

    @Synchronized
    fun getActiveKeyIndices(): List<Int> {
        recoverCooldownKeysIfNeeded()

        val keys = apiKeyProvider.getApiKeys()
        return keys.indices.filter { idx ->
            val status = keyStatuses[idx]
            status == null || status == KeyStatus.ACTIVE
        }
    }

    @Synchronized
    fun hasActiveKeys(): Boolean {
        recoverCooldownKeysIfNeeded()
        return getAvailableKeyIndex() >= 0
    }

    @Synchronized
    fun areAllKeysDown(): Boolean {
        recoverCooldownKeysIfNeeded()
        return !hasActiveKeys()
    }

    @Synchronized
    fun getHealthSummary(): List<KeyHealth> {
        recoverCooldownKeysIfNeeded()

        val keys = apiKeyProvider.getApiKeys()
        return keys.indices.map { idx ->
            KeyHealth(
                index = idx,
                status = keyStatuses[idx] ?: KeyStatus.ACTIVE,
                consecutiveErrors = keyConsecutiveErrors[idx]?.get() ?: 0,
                cooldownUntilMs = keyCooldownUntil[idx] ?: 0L,
                lastErrorTimeMs = keyLastErrorTime[idx] ?: 0L,
                lastErrorMessage = keyLastErrorMsg[idx]
            )
        }
    }

    @Synchronized
    fun recoverCooldownKeysIfNeeded() {
        val now = System.currentTimeMillis()
        val iterator = keyCooldownUntil.entries.iterator()
        while (iterator.hasNext()) {
            val entry = iterator.next()
            if (now >= entry.value) {
                val idx = entry.key
                val oldStatus = keyStatuses[idx]
                if (oldStatus == KeyStatus.COOLDOWN) {
                    keyStatuses[idx] = KeyStatus.ACTIVE
                    keyConsecutiveErrors[idx]?.set(0)
                    Log.i(TAG, "Key $idx recovered from COOLDOWN → ACTIVE (quota reset at 00:00)")
                }
                iterator.remove()
            }
        }
    }

    private fun nextMidnightMs(): Long {
        val cal = Calendar.getInstance()
        cal.add(Calendar.DAY_OF_MONTH, 1)
        cal.set(Calendar.HOUR_OF_DAY, 0)
        cal.set(Calendar.MINUTE, 0)
        cal.set(Calendar.SECOND, 0)
        cal.set(Calendar.MILLISECOND, 0)
        return cal.timeInMillis
    }

    private fun formatTime(ms: Long): String {
        val cal = Calendar.getInstance()
        cal.timeInMillis = ms
        return "${cal.get(Calendar.HOUR_OF_DAY)}:${cal.get(Calendar.MINUTE)}"
    }
}
