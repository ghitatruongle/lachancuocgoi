package com.lachancuocgoi.lachancuocgoi_flutter.services.stt

/**
 * Sealed class representing the state of the Speech-to-Text engine.
 *
 * Extracted from `SpeechToTextManager.kt` (Wave 2 refactor) to reduce file size.
 * Used by both Google STT and Vosk fallback paths.
 */
sealed class SttState {
    object Idle : SttState()
    object Listening : SttState()
    data class Error(val message: String, val recoverable: Boolean) : SttState()
    object Stopped : SttState()
}
