package com.lachancuocgoi.lachancuocgoi_flutter.helpers

import android.media.AudioManager
import android.util.Log

/**
 * Speakerphone control extracted from `BackgroundMonitoringService.kt` (Wave 2 refactor).
 *
 * Manages enabling/disabling speakerphone during a call, tracking whether the
 * service changed the speakerphone state so it can be restored on stop.
 */
class SpeakerphoneController(
    private val audioManager: AudioManager,
    private val initialState: Boolean,
) {
    companion object {
        private const val TAG = "SpeakerphoneController"
    }

    private var changedByService: Boolean = false
    private val snapshot: Boolean = initialState

    /**
     * Enable speakerphone if not already on.
     */
    fun enable() {
        try {
            if (!audioManager.isSpeakerphoneOn) {
                @Suppress("DEPRECATION")
                audioManager.isSpeakerphoneOn = true
                changedByService = true
            }
        } catch (e: Exception) {
            Log.e(TAG, "Error enabling speakerphone", e)
        }
    }

    /**
     * Restore speakerphone to the snapshot state if the service changed it.
     */
    @Suppress("DEPRECATION")
    fun disable() {
        try {
            if (changedByService) {
                audioManager.isSpeakerphoneOn = snapshot
                changedByService = false
            }
        } catch (e: Exception) {
            Log.e(TAG, "Error disabling speakerphone", e)
        }
    }
}