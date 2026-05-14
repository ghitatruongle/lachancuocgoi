package com.lachancuocgoi.lachancuocgoi_flutter.services

import android.content.Context
import android.util.Log
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow

/**
 * Stub VoskSttManager — Vosk offline STT.
 * Phase 8 chỉ cung cấp API stub để SpeechToTextManager compile được.
 * Vosk inference thật sẽ được test trên thiết bị Android ở Phase 12 QA.
 */
class VoskSttManager(private val context: Context) {

    companion object {
        private const val TAG = "VoskSttManager"
    }

    val isModelReady: Boolean = false

    private val _creatorTranscriptFlow = MutableStateFlow("")
    val creatorTranscriptFlow: StateFlow<String> = _creatorTranscriptFlow.asStateFlow()

    fun processAudioBuffer(buffer: ByteArray, bytesRead: Int) {
        // Stub — Vosk processing will be implemented when model-vn is loaded
        Log.d(TAG, "processAudioBuffer called (stub) — $bytesRead bytes")
    }

    fun resetTranscript() {
        _creatorTranscriptFlow.value = ""
    }

    fun destroy() {
        Log.d(TAG, "destroy called (stub)")
    }
}
