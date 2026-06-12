package com.example.lachancuocgoi.services

import android.Manifest
import android.content.Context
import android.content.Intent
import android.content.pm.PackageManager
import android.media.AudioFormat
import android.media.AudioRecord
import android.os.Bundle
import android.os.Handler
import android.os.Looper
import android.speech.RecognitionListener
import android.speech.RecognizerIntent
import android.speech.SpeechRecognizer
import android.util.Log
import androidx.core.content.ContextCompat
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.Job
import kotlinx.coroutines.SupervisorJob
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.isActive
import kotlinx.coroutines.launch

sealed class SttState {
    object Idle : SttState()
    object Listening : SttState()
    data class Error(val message: String, val recoverable: Boolean) : SttState()
    object Stopped : SttState()
}

class SpeechToTextManager(private val context: Context) : SttEngine {

    companion object {
        private const val TAG = "SpeechToTextManager"
        private const val DEBUG_LOGS = false
        private const val NETWORK_ERROR_FALLBACK_THRESHOLD = 3 // Switch sang Vosk sau 3 network errors liên tiếp
        private const val VOSK_SAMPLE_RATE = 16000
        private const val VOSK_CHANNEL_CONFIG = AudioFormat.CHANNEL_IN_MONO
        private const val VOSK_AUDIO_FORMAT = AudioFormat.ENCODING_PCM_16BIT
    }

    override val name = "Google"

    // ── Vosk Fallback Engine ────────────────────────────────────────────────
    private var voskFallback: VoskSttManager? = null
    private var voskMicRecord: AudioRecord? = null
    private var voskMicJob: Job? = null
    private val voskScope = CoroutineScope(Dispatchers.IO + SupervisorJob())
    private var isVoskFallbackActive = false
    private var consecutiveNetworkErrors = 0

    /** Callback khi engine switch xảy ra. ViewModel có thể observe. */
    var onEngineSwitched: ((isVosk: Boolean) -> Unit)? = null

    /** Preload Vosk model ở background để sẵn sàng khi cần fallback */
    fun preloadVoskFallback() {
        if (voskFallback == null) {
            voskFallback = VoskSttManager(context)
            Log.d(TAG, "Vosk fallback model preloading...")
        }
    }

    /** Mạng đã trở lại — chuyển về Google nếu đang dùng Vosk fallback */
    fun onNetworkRestored() {
        if (isVoskFallbackActive) {
            Log.i(TAG, "Mạng trở lại — chuyển từ Vosk fallback về Google")
            switchToGoogle()
        }
    }

    private val _textResults = MutableStateFlow("")
    override val textResults = _textResults.asStateFlow()

    private var cumulativeTranscript = ""
    private val _fullTranscriptFlow = MutableStateFlow("")
    override val fullTranscriptFlow = _fullTranscriptFlow.asStateFlow()

    private val _isListening = MutableStateFlow(false)
    override val isListening = _isListening.asStateFlow()

    private val _sttState = MutableStateFlow<SttState>(SttState.Idle)
    val sttState = _sttState.asStateFlow()

    // Add RMS flow for waveform
    private val _rmsDbFlow = MutableStateFlow(0f)
    override val rmsDbFlow = _rmsDbFlow.asStateFlow()

    private var shouldBeListening = false
    @Volatile private var isRestarting = false
    private var speechRecognizer: SpeechRecognizer? = null
    private val handler = Handler(Looper.getMainLooper())

    // Track consecutive error 12 occurrences to stop retry loop during VoIP calls
    private var consecutiveError12Count = 0
    private val MAX_CONSECUTIVE_ERROR12 = 20

    override val isReady: Boolean
        get() = !isVoskFallbackActive // Google luôn ready (trừ khi đang fallback)

    private val recognitionListener = object : RecognitionListener {
        override fun onReadyForSpeech(params: Bundle?) {
            _isListening.value = true
            _sttState.value = SttState.Listening
        }
        override fun onBeginningOfSpeech() {}
        override fun onRmsChanged(rmsdB: Float) {
            _rmsDbFlow.value = rmsdB
        }
        override fun onBufferReceived(buffer: ByteArray?) {}
        override fun onEndOfSpeech() {
            _isListening.value = false
        }

        override fun onError(error: Int) {
            val errorMessage = when (error) {
                SpeechRecognizer.ERROR_AUDIO -> "Audio recording error - may conflict with phone call audio"
                SpeechRecognizer.ERROR_CLIENT -> "Client side error"
                SpeechRecognizer.ERROR_INSUFFICIENT_PERMISSIONS -> "Insufficient permissions"
                SpeechRecognizer.ERROR_NETWORK -> "Network error"
                SpeechRecognizer.ERROR_NETWORK_TIMEOUT -> "Network timeout"
                SpeechRecognizer.ERROR_NO_MATCH -> "No speech match"
                SpeechRecognizer.ERROR_RECOGNIZER_BUSY -> "Recognition service busy"
                SpeechRecognizer.ERROR_SERVER -> "Server error"
                SpeechRecognizer.ERROR_SPEECH_TIMEOUT -> "No speech input"
                else -> "Unknown error ($error)"
            }
            // Log error only if it's not a common retry-able error or if DEBUG is on
            if (DEBUG_LOGS || (error != SpeechRecognizer.ERROR_AUDIO && error != SpeechRecognizer.ERROR_RECOGNIZER_BUSY && error != 12)) {
                Log.e(TAG, "onError: $errorMessage")
            }
            _isListening.value = false

            // Map error to SttState
            val isRecoverable = when (error) {
                SpeechRecognizer.ERROR_NETWORK, SpeechRecognizer.ERROR_NETWORK_TIMEOUT,
                SpeechRecognizer.ERROR_AUDIO, SpeechRecognizer.ERROR_RECOGNIZER_BUSY,
                SpeechRecognizer.ERROR_NO_MATCH, SpeechRecognizer.ERROR_SPEECH_TIMEOUT,
                12 -> true
                else -> false
            }
            _sttState.value = SttState.Error(errorMessage, isRecoverable)

            // ── Network error fallback logic ──────────────────────────────────
            if (error == SpeechRecognizer.ERROR_NETWORK || error == SpeechRecognizer.ERROR_NETWORK_TIMEOUT) {
                consecutiveNetworkErrors++
                if (consecutiveNetworkErrors >= NETWORK_ERROR_FALLBACK_THRESHOLD && !isVoskFallbackActive) {
                    Log.w(TAG, "$consecutiveNetworkErrors network errors — switching to Vosk fallback")
                    switchToVoskFallback()
                    return
                }
            } else {
                consecutiveNetworkErrors = 0 // Reset on non-network errors
            }

            // For audio errors during calls, this is expected - don't spam restart
            // Error 12 is often a manufacturer-specific code for "Client Busy" or "Insufficient Permissions" during calls
            if (error == SpeechRecognizer.ERROR_AUDIO || error == SpeechRecognizer.ERROR_RECOGNIZER_BUSY || error == 12) {
                if (error == 12) {
                    handleError12()
                    return
                }

                if (DEBUG_LOGS) Log.w(TAG, "Audio/Busy error ($error) - will retry in 2s")
                if (shouldBeListening) {
                    handler.postDelayed({ startListening() }, 2000)
                }
            } else if (shouldBeListening && error != SpeechRecognizer.ERROR_INSUFFICIENT_PERMISSIONS && error != SpeechRecognizer.ERROR_CLIENT) {
                // Auto-restart on other errors (except permission/client error)
                consecutiveError12Count = 0 // Reset counter on non-12 errors
                handler.postDelayed({ startListening() }, 1000)
            }
        }

        override fun onResults(results: Bundle?) {
            val result = results?.getStringArrayList(SpeechRecognizer.RESULTS_RECOGNITION)?.firstOrNull() ?: ""
            if (result.isNotEmpty()) {
                cumulativeTranscript = appendWithOverlapDetection(cumulativeTranscript, result)
                _fullTranscriptFlow.value = cumulativeTranscript
                _textResults.value = result
                consecutiveError12Count = 0 // Reset on successful recognition
                consecutiveNetworkErrors = 0 // Reset network errors on success
            }
            _isListening.value = false
            if (shouldBeListening) {
                handler.post { startListening() }
            }
        }

        override fun onPartialResults(partialResults: Bundle?) {
            val partialResult = partialResults?.getStringArrayList(SpeechRecognizer.RESULTS_RECOGNITION)?.firstOrNull() ?: ""
            if (partialResult.isNotEmpty()) {
                val combined = if (cumulativeTranscript.isBlank()) partialResult else "$cumulativeTranscript\n$partialResult"
                _fullTranscriptFlow.value = combined
                _textResults.value = partialResult
                // (SỬA BUG 8) KHÔNG gọi TranscriptionHub.postTranscript() ở đây nữa.
                // Partial results là lũy tiến ("xin chào" → "xin chào anh" → "xin chào anh tôi")
                // Nếu gửi tất cả vào TranscriptionHub, overlap detection có thể fail khi STT
                // thay đổi correction giữa chừng → transcript bị lặp nội dung.
                // Chỉ gửi final result (đã xác nhận) từ onResults() là đủ.
            }
        }

        override fun onEvent(eventType: Int, params: Bundle?) {}
    }

    fun startListening() {
        // Check if RECORD_AUDIO permission is granted
        if (ContextCompat.checkSelfPermission(context, Manifest.permission.RECORD_AUDIO) != PackageManager.PERMISSION_GRANTED) {
            Log.e("SpeechToTextManager", "RECORD_AUDIO permission not granted. Cannot start speech recognition.")
            shouldBeListening = false
            _isListening.value = false
            _sttState.value = SttState.Error("Không có quyền RECORD_AUDIO", false)
            return
        }

        if (!SpeechRecognizer.isRecognitionAvailable(context)) {
            Log.e("SpeechToTextManager", "Speech recognition not available on this device")
            _sttState.value = SttState.Error("Thiết bị không hỗ trợ nhận diện giọng nói", false)
            return
        }
        shouldBeListening = true
        
        // Cancel tất cả pending restart/retry để tránh tạo 2 recognizer cùng lúc
        handler.removeCallbacksAndMessages(null)
        
        handler.post {
            if (isRestarting) {
                if (DEBUG_LOGS) Log.d(TAG, "Restart already in progress, skipping.")
                return@post
            }
            isRestarting = true
            if (DEBUG_LOGS) Log.d(TAG, "Starting speech recognition...")
            _isListening.value = true
            speechRecognizer?.destroy()
            speechRecognizer = SpeechRecognizer.createSpeechRecognizer(context).apply {
                setRecognitionListener(recognitionListener)
                val intent = Intent(RecognizerIntent.ACTION_RECOGNIZE_SPEECH).apply {
                    putExtra(RecognizerIntent.EXTRA_LANGUAGE_MODEL, RecognizerIntent.LANGUAGE_MODEL_FREE_FORM)
                    putExtra(RecognizerIntent.EXTRA_LANGUAGE, "vi-VN")
                    putExtra(RecognizerIntent.EXTRA_PARTIAL_RESULTS, true)
                    // Keep listening longer even if silence occurs
                    putExtra("android.speech.extra.SPEECH_INPUT_COMPLETE_SILENCE_LENGTH_MILLIS", 10000L) // Increased to 10s
                    putExtra("android.speech.extra.SPEECH_INPUT_POSSIBLY_COMPLETE_SILENCE_LENGTH_MILLIS", 10000L)
                    
                    // REMOVED EXTRA_PREFER_OFFLINE: This often causes Error 12 if offline pack is not installed/working
                    // putExtra(RecognizerIntent.EXTRA_PREFER_OFFLINE, true) 
                }
                try {
                    startListening(intent)
                    isRestarting = false
                    if (DEBUG_LOGS) Log.d(TAG, "Speech recognition started successfully")
                } catch (e: Exception) {
                    isRestarting = false
                    Log.e(TAG, "Error starting speech recognition", e)
                    // If start fails immediately, count it towards error limit
                    handleError12()
                }
            }
        }
    }

    fun stopListening() {
        if (DEBUG_LOGS) Log.d(TAG, "Stopping speech recognition...")
        shouldBeListening = false
        _isListening.value = false
        _sttState.value = SttState.Stopped
        
        // Reset error count when explicitly stopped by user/system
        consecutiveError12Count = 0
        
        handler.post {
            try {
                speechRecognizer?.cancel()
            } catch (e: Exception) { Log.e("SpeechToTextManager", "Error cancelling", e) }
            
            try {
                speechRecognizer?.destroy()
            } catch (e: Exception) { Log.e("SpeechToTextManager", "Error destroying", e) }
            
            speechRecognizer = null
            if (DEBUG_LOGS) Log.d(TAG, "Speech recognition stopped")
        }
    }

    private fun handleError12() {
        consecutiveError12Count++
        if (consecutiveError12Count >= MAX_CONSECUTIVE_ERROR12) {
            Log.e(TAG, "Stopped. Google Speech Service unavailable (Error 12 loop).")
            shouldBeListening = false
            _isListening.value = false
            _sttState.value = SttState.Error("Google Speech không khả dụng — chuyển sang chế độ dự phòng", false)

            android.os.Handler(Looper.getMainLooper()).post {
                android.widget.Toast.makeText(
                    context,
                    "Google Speech lỗi liên tục — đang chuyển sang chế độ dự phòng...",
                    android.widget.Toast.LENGTH_SHORT
                ).show()
            }

            switchToVoskFallback()
        } else {
             if (shouldBeListening) {
                 handler.postDelayed({ startListening() }, 2000)
            }
        }
    }

    /**
     * Ghép utterance mới vào transcript cũ, loại bỏ overlap.
     * Google STT thường lặp 2-3 từ cuối utterance trước ở đầu utterance mới.
     * VD: cũ="xin chào anh" → mới="anh tôi là" → kết quả="xin chào anh tôi là"
     */
    private fun appendWithOverlapDetection(existing: String, newSegment: String): String {
        if (existing.isBlank()) return newSegment

        val existingWords = existing.split(Regex("\\s+")).filter { it.isNotBlank() }
        val newWords = newSegment.split(Regex("\\s+")).filter { it.isNotBlank() }

        if (existingWords.isEmpty() || newWords.isEmpty()) {
            return if (existing.isBlank()) newSegment else "$existing\n$newSegment"
        }

        // Tìm overlap dài nhất: so sánh N từ cuối của existing với N từ đầu của new
        var bestOverlap = 0
        val maxCheck = minOf(existingWords.size, newWords.size, 6) // tối đa 6 từ overlap
        for (len in 1..maxCheck) {
            val tailExisting = existingWords.takeLast(len).joinToString(" ").lowercase()
            val headNew = newWords.take(len).joinToString(" ").lowercase()
            if (tailExisting == headNew) {
                bestOverlap = len
            }
        }

        val dedupedNew = if (bestOverlap > 0) {
            newWords.drop(bestOverlap).joinToString(" ")
        } else {
            newSegment
        }

        return if (dedupedNew.isBlank()) existing else "$existing\n$dedupedNew"
    }

    override fun start() = startListening()

    override fun stop() = stopListening()

    override fun clearTranscript() {
        cumulativeTranscript = ""
        _fullTranscriptFlow.value = ""
        _textResults.value = ""
    }

    override fun destroy() {
        shouldBeListening = false
        stopListening()
        stopVoskFallback()
        voskFallback?.destroy()
        voskFallback = null
    }

    // ── Vosk Fallback: Mic-based offline STT ────────────────────────────────

    private fun switchToVoskFallback() {
        val vosk = voskFallback
        if (vosk == null || !vosk.isModelReady) {
            Log.w(TAG, "Vosk fallback không sẵn sàng — không thể chuyển")
            return
        }

        isVoskFallbackActive = true
        consecutiveNetworkErrors = 0
        _sttState.value = SttState.Error("Mất mạng — chuyển sang nhận diện offline", true)
        onEngineSwitched?.invoke(true)

        // Dừng Google
        handler.post {
            try { speechRecognizer?.cancel() } catch (_: Exception) {}
            try { speechRecognizer?.destroy() } catch (_: Exception) {}
            speechRecognizer = null
        }

        // Bắt đầu đọc mic cho Vosk
        startVoskMicReading(vosk)
    }

    private fun switchToGoogle() {
        isVoskFallbackActive = false
        consecutiveNetworkErrors = 0
        onEngineSwitched?.invoke(false)

        // Dừng Vosk mic reading
        stopVoskMicReading()

        // Khởi động lại Google
        if (shouldBeListening) {
            startListening()
        }
    }

    private fun startVoskMicReading(vosk: VoskSttManager) {
        stopVoskMicReading()

        if (ContextCompat.checkSelfPermission(context, Manifest.permission.RECORD_AUDIO) != PackageManager.PERMISSION_GRANTED) {
            Log.e(TAG, "RECORD_AUDIO permission not granted for Vosk fallback")
            return
        }

        val bufferSize = AudioRecord.getMinBufferSize(VOSK_SAMPLE_RATE, VOSK_CHANNEL_CONFIG, VOSK_AUDIO_FORMAT)
            .coerceAtLeast(VOSK_SAMPLE_RATE * 2 * 320 / 1000)

        val record = try {
            AudioRecord.Builder()
                .setAudioFormat(
                    AudioFormat.Builder()
                        .setEncoding(VOSK_AUDIO_FORMAT)
                        .setSampleRate(VOSK_SAMPLE_RATE)
                        .setChannelMask(VOSK_CHANNEL_CONFIG)
                        .build()
                )
                .setBufferSizeInBytes(bufferSize)
                .build()
        } catch (e: Exception) {
            Log.e(TAG, "Failed to create AudioRecord for Vosk fallback", e)
            return
        }

        if (record.state != AudioRecord.STATE_INITIALIZED) {
            Log.e(TAG, "Vosk fallback AudioRecord not initialized")
            record.release()
            return
        }

        record.startRecording()
        voskMicRecord = record
        vosk.resetTranscript()
        _isListening.value = true
        _sttState.value = SttState.Listening

        voskMicJob = voskScope.launch {
            val buffer = ByteArray(bufferSize)
            try {
                while (isActive && isVoskFallbackActive) {
                    val read = record.read(buffer, 0, buffer.size)
                    if (read > 0) {
                        vosk.processAudioBuffer(buffer, read)

                        // Tính RMS cho waveform
                        val amplitude = buffer.take(read)
                            .chunked(2)
                            .mapNotNull { bytes ->
                                if (bytes.size < 2) null
                                else (bytes[1].toInt() shl 8 or (bytes[0].toInt() and 0xFF)).toShort().toInt()
                            }
                            .map { Math.abs(it).toFloat() }
                            .average().toFloat()
                        val normalizedRms = (amplitude / 2184f).coerceIn(0f, 15f)
                        _rmsDbFlow.value = normalizedRms
                    } else if (read < 0) {
                        break
                    }
                }
            } catch (e: Exception) {
                Log.e(TAG, "Vosk mic read loop error", e)
            }
        }

        // Collect Vosk transcript và đưa vào flow chung
        voskMicJob?.invokeOnCompletion {
            record.stop()
            record.release()
        }

        // Observe Vosk transcript flow
        voskScope.launch {
            vosk.creatorTranscriptFlow.collect { text ->
                if (text.isNotBlank() && isVoskFallbackActive) {
                    // Vosk đã tự overlap-detect trong cumulativeTranscript của nó
                    cumulativeTranscript = text
                    _fullTranscriptFlow.value = text
                }
            }
        }

        Log.i(TAG, "Vosk fallback mic reading started")
    }

    private fun stopVoskMicReading() {
        voskMicJob?.cancel()
        voskMicJob = null
        try {
            voskMicRecord?.let { record ->
                if (record.state == AudioRecord.STATE_INITIALIZED) {
                    record.stop()
                }
                record.release()
            }
        } catch (e: Exception) {
            Log.e(TAG, "Error stopping Vosk mic record", e)
        } finally {
            voskMicRecord = null
        }
        voskFallback?.resetTranscript()
        _isListening.value = false
    }

    private fun stopVoskFallback() {
        isVoskFallbackActive = false
        stopVoskMicReading()
    }
}
