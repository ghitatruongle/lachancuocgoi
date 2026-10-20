package com.lachancuocgoi.lachancuocgoi_flutter.helpers

import android.media.AudioManager
import android.util.Log

class SpeakerphoneController(
    private val audioManager: AudioManager,
    private val initialState: Boolean,
) {
    companion object {
        private const val TAG = "SpeakerphoneController"
    }

    private var changedByService: Boolean = false
    private val snapshot: Boolean = initialState

    @Suppress("DEPRECATION")
    fun enable() {
        try {
            if (!audioManager.isSpeakerphoneOn) {
                audioManager.isSpeakerphoneOn = true
                changedByService = true
            }
        } catch (e: Exception) {
            Log.e(TAG, "Error enabling speakerphone", e)
        }
    }

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

