package com.example.lachancuocgoi.ui.HomePage.SettingsDialog

import android.os.SystemClock
import androidx.compose.runtime.mutableStateOf

/**
 * Quản lý chế độ Nhà phát triển:
 * - Kích hoạt: nhấn "Cài đặt" 10 lần liên tiếp (mỗi lần cách nhau < 2s) → nhập mật mã 110210
 * - Tắt: nhấn 3 lần liên tiếp khi đang active
 * - Thời hạn: 10 phút kể từ lúc kích hoạt
 */
object DeveloperModeManager {

    private const val REQUIRED_TAPS = 10
    private const val DEACTIVATE_TAPS = 3
    private const val TAP_TIMEOUT_MS = 2_000L        // Reset nếu tap cách nhau > 2 giây
    private const val DEV_MODE_DURATION_MS = 600_000L // 10 phút
    private const val DEV_PASSWORD = "110210"

    private var tapCount = 0
    private var lastTapTime = 0L

    // Counter riêng cho deactivation khi đang active
    private var deactivateTapCount = 0
    private var lastDeactivateTapTime = 0L

    private var devModeActivatedAt = 0L

    /**
     * Observable state — Compose sẽ tự recompose khi giá trị thay đổi.
     * Đọc bằng: DeveloperModeManager.isActive.value
     */
    val isActive = mutableStateOf(false)

    // Sealed class kết quả của mỗi tap
    sealed class TapResult {
        object Nothing : TapResult()          // Chưa đủ số lần
        object ShowPassword : TapResult()     // Đủ 10 tap → hiện dialog mật mã
        object Deactivated : TapResult()      // Đang active + 3 tap → tắt dev mode
    }

    // -------------------------------------------------------
    // Public API
    // -------------------------------------------------------

    /** Gọi mỗi khi người dùng nhấn vào title "Cài đặt". */
    fun onTitleTap(): TapResult {
        val now = SystemClock.elapsedRealtime()

        if (isDevModeActive()) {
            // ── Đang active: đếm 3 tap để tắt ──────────────────────────
            if (now - lastDeactivateTapTime > TAP_TIMEOUT_MS) {
                deactivateTapCount = 0
            }
            lastDeactivateTapTime = now
            deactivateTapCount++
            if (deactivateTapCount >= DEACTIVATE_TAPS) {
                deactivateTapCount = 0
                deactivateDevMode()
                return TapResult.Deactivated
            }
            return TapResult.Nothing
        } else {
            // ── Chưa active: đếm 10 tap để hiện password ────────────────
            if (now - lastTapTime > TAP_TIMEOUT_MS) {
                tapCount = 0
            }
            lastTapTime = now
            tapCount++
            if (tapCount >= REQUIRED_TAPS) {
                tapCount = 0
                return TapResult.ShowPassword
            }
            return TapResult.Nothing
        }
    }

    /** Số lần tap hiện tại (khi chưa active) */
    fun currentTapCount(): Int = tapCount

    /** Xác thực mật mã. @return true nếu đúng */
    fun verifyPassword(input: String): Boolean = input.trim() == DEV_PASSWORD

    /** Kích hoạt dev mode sau khi xác thực thành công */
    fun activateDevMode() {
        devModeActivatedAt = SystemClock.elapsedRealtime()
        deactivateTapCount = 0
        isActive.value = true   // ← trigger Compose recomposition
    }

    /** @return true nếu dev mode đang hoạt động (trong vòng 10 phút) */
    fun isDevModeActive(): Boolean {
        if (devModeActivatedAt == 0L) return false
        val active = SystemClock.elapsedRealtime() - devModeActivatedAt < DEV_MODE_DURATION_MS
        if (!active && isActive.value) {
            // Hết hạn tự nhiên — cập nhật state
            isActive.value = false
        }
        return active
    }

    /** Số giây còn lại của dev mode (-1 nếu không active) */
    fun remainingSeconds(): Int {
        if (!isDevModeActive()) return -1
        val elapsed = SystemClock.elapsedRealtime() - devModeActivatedAt
        return ((DEV_MODE_DURATION_MS - elapsed) / 1000).toInt()
    }

    /** Huỷ dev mode thủ công */
    fun deactivateDevMode() {
        devModeActivatedAt = 0L
        tapCount = 0
        deactivateTapCount = 0
        isActive.value = false  // ← trigger Compose recomposition
    }
}
