package com.example.lachancuocgoi.ui.HomePage.SettingsDialog

import android.os.SystemClock
import androidx.compose.runtime.mutableStateOf

object DeveloperModeManager {

    private const val REQUIRED_TAPS = 10
    private const val DEACTIVATE_TAPS = 3
    private const val TAP_TIMEOUT_MS = 2_000L
    private const val DEV_MODE_DURATION_MS = 600_000L
    private const val DEV_PASSWORD = "110210"

    private var tapCount = 0
    private var lastTapTime = 0L

    private var deactivateTapCount = 0
    private var lastDeactivateTapTime = 0L

    private var devModeActivatedAt = 0L

    val isActive = mutableStateOf(false)

    sealed class TapResult {
        object Nothing : TapResult()
        object ShowPassword : TapResult()
        object Deactivated : TapResult()
    }

    fun onTitleTap(): TapResult {
        val now = SystemClock.elapsedRealtime()

        if (isDevModeActive()) {

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

    fun currentTapCount(): Int = tapCount

    fun verifyPassword(input: String): Boolean = input.trim() == DEV_PASSWORD

    fun activateDevMode() {
        devModeActivatedAt = SystemClock.elapsedRealtime()
        deactivateTapCount = 0
        isActive.value = true
    }

    fun isDevModeActive(): Boolean {
        if (devModeActivatedAt == 0L) return false
        val active = SystemClock.elapsedRealtime() - devModeActivatedAt < DEV_MODE_DURATION_MS
        if (!active && isActive.value) {

            isActive.value = false
        }
        return active
    }

    fun remainingSeconds(): Int {
        if (!isDevModeActive()) return -1
        val elapsed = SystemClock.elapsedRealtime() - devModeActivatedAt
        return ((DEV_MODE_DURATION_MS - elapsed) / 1000).toInt()
    }

    fun deactivateDevMode() {
        devModeActivatedAt = 0L
        tapCount = 0
        deactivateTapCount = 0
        isActive.value = false
    }
}
