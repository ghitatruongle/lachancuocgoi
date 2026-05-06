package com.example.lachancuocgoi.Analysis.L3.core

import android.util.Log
import java.util.Calendar
import java.util.concurrent.atomic.AtomicInteger

/**
 * Theo dõi sức khoẻ của từng API key.
 *
 * Quota Gemini reset lúc 00:00 hàng ngày, nên:
 * - Key hết quota (429) → COOLDOWN đến 00:00 hôm sau
 * - Key sai/revoked (403) → EXHAUSTED (không dùng lại)
 * - Sau 00:00 → tự động phục hồi COOLDOWN keys về ACTIVE
 */
class KeyHealthTracker(private val apiKeyProvider: ApiKeyProvider) {

    companion object {
        private const val TAG = "KeyHealthTracker"
    }

    enum class KeyStatus {
        ACTIVE,       // Key hoạt động bình thường
        COOLDOWN,     // Hết quota — chờ đến 00:00 hôm sau
        EXHAUSTED     // Key bị revoke/invalid — không dùng lại
    }

    data class KeyHealth(
        val index: Int,
        val status: KeyStatus,
        val consecutiveErrors: Int,
        val cooldownUntilMs: Long,   // Thời điểm key có thể dùng lại (00:00 hôm sau)
        val lastErrorTimeMs: Long,
        val lastErrorMessage: String?
    )

    // Per-key state
    private val keyStatuses = mutableMapOf<Int, KeyStatus>()
    private val keyConsecutiveErrors = mutableMapOf<Int, AtomicInteger>()
    private val keyCooldownUntil = mutableMapOf<Int, Long>()
    private val keyLastErrorTime = mutableMapOf<Int, Long>()
    private val keyLastErrorMsg = mutableMapOf<Int, String?>()

    // Current preferred key (key hoạt động tốt nhất gần nhất)
    @Volatile
    private var preferredKeyIndex: Int = 0

    /**
     * Đánh dấu key hết quota (429).
     * Key sẽ ở trạng thái COOLDOWN đến 00:00 hôm sau.
     */
    @Synchronized
    fun markQuotaExceeded(keyIndex: Int) {
        val cooldownUntil = nextMidnightMs()
        keyStatuses[keyIndex] = KeyStatus.COOLDOWN
        keyCooldownUntil[keyIndex] = cooldownUntil
        keyLastErrorTime[keyIndex] = System.currentTimeMillis()
        keyLastErrorMsg[keyIndex] = "429 Quota exceeded"
        Log.w(TAG, "Key $keyIndex hit quota limit. Cooldown until ${formatTime(cooldownUntil)}")
    }

    /**
     * Đánh dấu key bị invalid/revoke (403).
     * Key sẽ ở trạng thái EXHAUSTED — không dùng lại.
     */
    @Synchronized
    fun markInvalid(keyIndex: Int, message: String? = null) {
        keyStatuses[keyIndex] = KeyStatus.EXHAUSTED
        keyLastErrorTime[keyIndex] = System.currentTimeMillis()
        keyLastErrorMsg[keyIndex] = message ?: "403 Forbidden / Invalid key"
        Log.e(TAG, "Key $keyIndex is INVALID/REVOKED: $message. Will not retry.")
    }

    /**
     * Đánh dấu key gọi thành công.
     * Reset errors, chuyển về ACTIVE.
     */
    @Synchronized
    fun markSuccess(keyIndex: Int) {
        keyStatuses[keyIndex] = KeyStatus.ACTIVE
        keyConsecutiveErrors[keyIndex]?.set(0)
        keyCooldownUntil.remove(keyIndex)
        keyLastErrorMsg.remove(keyIndex)
        preferredKeyIndex = keyIndex
        Log.d(TAG, "Key $keyIndex SUCCESS → ACTIVE")
    }

    /**
     * Đánh dấu key gặp lỗi (nhưng không phải quota/invalid).
     * Sau 3 lỗi liên tiếp → COOLDOWN.
     */
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

    /**
     * Lấy index của key ACTIVE tốt nhất để dùng.
     * Ưu tiên preferredKeyIndex nếu vẫn ACTIVE, sau đó tìm key ACTIVE gần nhất.
     * Tự động phục hồi COOLDOWN keys nếu đã qua 00:00.
     *
     * @return Key index hoặc -1 nếu không có key nào可用
     */
    @Synchronized
    fun getAvailableKeyIndex(): Int {
        recoverCooldownKeysIfNeeded()

        val keys = apiKeyProvider.getApiKeys()
        if (keys.isEmpty()) return -1

        // Ưu tiên preferred key nếu vẫn ACTIVE
        if (preferredKeyIndex in keys.indices && keyStatuses[preferredKeyIndex] == KeyStatus.ACTIVE) {
            return preferredKeyIndex
        }

        // Tìm key ACTIVE gần preferred index (round-robin)
        for (offset in keys.indices) {
            val idx = (preferredKeyIndex + offset + 1) % keys.size
            if (keyStatuses[idx] == null || keyStatuses[idx] == KeyStatus.ACTIVE) {
                return idx
            }
        }

        // Không có key ACTIVE nào
        Log.e(TAG, "No ACTIVE keys available! Statuses: $keyStatuses")
        return -1
    }

    /**
     * Lấy danh sách tất cả key ACTIVE (để loop fallback).
     */
    @Synchronized
    fun getActiveKeyIndices(): List<Int> {
        recoverCooldownKeysIfNeeded()

        val keys = apiKeyProvider.getApiKeys()
        return keys.indices.filter { idx ->
            val status = keyStatuses[idx]
            status == null || status == KeyStatus.ACTIVE
        }
    }

    /**
     * Kiểm tra xem có key nào ACTIVE không.
     */
    @Synchronized
    fun hasActiveKeys(): Boolean {
        recoverCooldownKeysIfNeeded()
        return getAvailableKeyIndex() >= 0
    }

    /**
     * Kiểm tra tất cả keys đều không dùng được.
     */
    @Synchronized
    fun areAllKeysDown(): Boolean {
        recoverCooldownKeysIfNeeded()
        return !hasActiveKeys()
    }

    /**
     * Lấy tổng quan sức khoẻ tất cả keys (dùng cho HealthCheck & UI).
     */
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

    /**
     * Phục hồi các key COOLDOWN nếu đã qua 00:00.
     */
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

    /**
     * Tính thời điểm 00:00 hôm sau (milliseconds).
     */
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
