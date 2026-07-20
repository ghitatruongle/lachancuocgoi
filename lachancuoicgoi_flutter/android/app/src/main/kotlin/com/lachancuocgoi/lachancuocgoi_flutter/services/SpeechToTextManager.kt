package com.lachancuocgoi.lachancuocgoi_flutter.services

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
import com.lachancuocgoi.lachancuocgoi_flutter.services.stt.SttState
import com.lachancuocgoi.lachancuocgoi_flutter.services.stt.TranscriptOverlapJoiner
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.Job
import kotlinx.coroutines.SupervisorJob
import kotlinx.coroutines.cancelChildren
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.isActive
import kotlinx.coroutines.launch

class SpeechToTextManager(private val context: Context) : SttEngine {

    companion object {
        private const val TAG = "SpeechToTextManager"
        private const val DEBUG_LOGS = false
        private const val NETWORK_ERROR_FALLBACK_THRESHOLD = 3
        private const val CLIENT_ERROR_FALLBACK_THRESHOLD = 3
        private const val GOOGLE_RETRY_INTERVAL_MS = 30_000L
        private const val GOOGLE_RETRY_MAX_ATTEMPTS = 10
        // SpeechRecognizer.ERROR_LANGUAGE_UNAVAILABLE was added after our
        // minimum SDK. The callback can still return its stable wire value.
        private const val ERROR_LANGUAGE_UNAVAILABLE_COMPAT = 12
        // Max wait for the Google test recognizer to signal readiness/error
        // during a retry probe. If neither fires (service hung), we abort the
        // probe and resume Vosk so the call doesn't go silent.
        private const val GOOGLE_TEST_TIMEOUT_MS = 5_000L
        private const val VOSK_SAMPLE_RATE = 16000
        private const val VOSK_CHANNEL_CONFIG = AudioFormat.CHANNEL_IN_MONO
        private const val VOSK_AUDIO_FORMAT = AudioFormat.ENCODING_PCM_16BIT
        // RMS throttle: the dB reading feeds only the monitoring UI and
        // tolerates ~1Hz updates. Computing RMS on every ~320ms read iterates
        // ~5000 byte pairs and competes with the Vosk JNI on weak arm32
        // devices (e.g. SM-J610F). Skip N-1 of every N reads to cut the loop
        // cost ~3x without any perceptible UI change.
        private const val VOSK_RMS_THROTTLE_READS = 3
    }

    override val name = "Google"

    // Vosk Fallback Engine
    private var voskFallback: VoskSttManager? = null
    private var voskMicRecord: AudioRecord? = null
    private var voskMicJob: Job? = null
    private val voskScope = CoroutineScope(Dispatchers.IO + SupervisorJob())
    @Volatile private var isVoskFallbackActive = false
    private var consecutiveNetworkErrors = 0

    var onEngineSwitched: ((isVosk: Boolean) -> Unit)? = null

    fun preloadVoskFallback() {
        if (voskFallback == null) {
            voskFallback = VoskSttManager(context)
            Log.d(TAG, "Vosk fallback model preloading...")
            NativeBridgeEventSink.sendLog(TAG, "Vosk fallback model preloading...", "INFO")
        }
    }

    /**
     * Start Vosk as the primary engine — used when Google STT is unavailable
     * (e.g. on a device without the Google SpeechService or in airplane mode at
     * start time). Returns true if Vosk is now active and listening.
     *
     * The Vosk model must already be loaded — call [preloadVoskFallback] from
     * onCreate so the model is warm by the time monitoring begins. If the model
     * is not ready yet (e.g. the user starts monitoring < 1s after service
     * start) this returns false and the caller can fall through to Google.
     */
    fun startVoskPrimaryIfReady(): Boolean {
        val vosk = voskFallback
        if (vosk == null) {
            Log.w(TAG, "startVoskPrimaryIfReady: Vosk manager not initialised — was preloadVoskFallback() called?")
            NativeBridgeEventSink.sendLog(TAG, "startVoskPrimaryIfReady: Vosk manager not initialised — was preloadVoskFallback() called?", "WARN")
            return false
        }
        if (!vosk.isModelReady) {
            Log.w(TAG, "startVoskPrimaryIfReady: Vosk model not ready yet — will retry on next network-error fallback")
            NativeBridgeEventSink.sendLog(TAG, "startVoskPrimaryIfReady: Vosk model not ready yet — will retry on next network-error fallback", "WARN")
            return false
        }
        Log.i(TAG, "Starting Vosk as primary STT engine (Google STT unavailable)")
        NativeBridgeEventSink.sendLog(TAG, "Starting Vosk as primary STT engine (Google STT unavailable)", "INFO")
        switchToVoskFallback()
        return isVoskFallbackActive
    }

    fun onNetworkRestored() {
        if (isVoskFallbackActive) {
            Log.i(TAG, "Mạng trở lại — chuyển từ Vosk fallback về Google")
            NativeBridgeEventSink.sendLog(TAG, "Mạng trở lại — chuyển từ Vosk fallback về Google", "INFO")
            switchToGoogle()
        }
    }

    private val _textResults = MutableStateFlow("")
    override val textResults = _textResults.asStateFlow()

    @Volatile
    private var cumulativeTranscript = ""
    private val transcriptLock = Any()  // Bug fix: synchronize cumulativeTranscript access
    private val _fullTranscriptFlow = MutableStateFlow("")
    override val fullTranscriptFlow = _fullTranscriptFlow.asStateFlow()

    private val _isListening = MutableStateFlow(false)
    override val isListening = _isListening.asStateFlow()

    private val _sttState = MutableStateFlow<SttState>(SttState.Idle)
    val sttState = _sttState.asStateFlow()

    private val _rmsDbFlow = MutableStateFlow(0f)
    override val rmsDbFlow = _rmsDbFlow.asStateFlow()

    private var shouldBeListening = false

    /**
     * Read-only snapshot of [shouldBeListening] — used by
     * `BackgroundMonitoringService` from the audio-focus listener to decide
     * whether to re-start STT after a transient focus loss.
     */
    val shouldBeListeningSnapshot: Boolean
        get() = shouldBeListening

    @Volatile private var isRestarting = false
    private var speechRecognizer: SpeechRecognizer? = null
    private val handler = Handler(Looper.getMainLooper())

    private var consecutiveError12Count = 0
    private val MAX_CONSECUTIVE_ERROR12 = 20

    private var consecutiveAudioErrors = 0
    private val AUDIO_ERROR_FALLBACK_THRESHOLD = 3

    private var consecutiveClientErrors = 0

    // Google retry: periodically try switching back from Vosk to Google STT
    private var googleRetryCount = 0
    private val googleRetryRunnable = Runnable { attemptGoogleRetry() }

    override val isReady: Boolean
        get() = !isVoskFallbackActive

    private val restartRunnable = Runnable {
        if (shouldBeListening) startListening()
    }

    private val recognitionListener = object : RecognitionListener {
        override fun onReadyForSpeech(params: Bundle?) {
            _isListening.value = true
            _sttState.value = SttState.Listening
            Log.i(TAG, "Google Speech connected & ready for speech (vi-VN)")
            NativeBridgeEventSink.sendLog(TAG, "Google Speech connected & ready for speech (vi-VN)", "INFO")
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
            if (DEBUG_LOGS || (error != SpeechRecognizer.ERROR_AUDIO && error != SpeechRecognizer.ERROR_RECOGNIZER_BUSY && error != 12)) {
                Log.e(TAG, "onError: $errorMessage")
                NativeBridgeEventSink.sendLog(TAG, "Google Speech Recognizer error: $errorMessage", "ERROR")
            }
            _isListening.value = false

            val isRecoverable = error == ERROR_LANGUAGE_UNAVAILABLE_COMPAT || when (error) {
                SpeechRecognizer.ERROR_NETWORK, SpeechRecognizer.ERROR_NETWORK_TIMEOUT,
                SpeechRecognizer.ERROR_AUDIO, SpeechRecognizer.ERROR_RECOGNIZER_BUSY,
                SpeechRecognizer.ERROR_NO_MATCH, SpeechRecognizer.ERROR_SPEECH_TIMEOUT -> true
                else -> false
            }
            _sttState.value = SttState.Error(errorMessage, isRecoverable)

            // Client error fallback logic
            if (error == SpeechRecognizer.ERROR_CLIENT) {
                consecutiveClientErrors++
                if (consecutiveClientErrors >= CLIENT_ERROR_FALLBACK_THRESHOLD && !isVoskFallbackActive) {
                    Log.w(TAG, "$consecutiveClientErrors consecutive client errors — switching to Vosk fallback")
                    NativeBridgeEventSink.sendLog(TAG, "$consecutiveClientErrors lỗi client liên tiếp — chuyển sang Vosk STT (offline fallback)", "WARN")
                    NativeBridgeEventSink.sendMonitoringState(
                        "STT_FALLBACK:VOSK:google_client_error"
                    )
                    handler.post {
                        try { speechRecognizer?.cancel() } catch (_: Exception) {}
                        try { speechRecognizer?.destroy() } catch (_: Exception) {}
                        speechRecognizer = null
                    }
                    switchToVoskFallback()
                    return
                }
                // Retry after brief delay — client errors are often transient
                if (shouldBeListening) {
                    handler.removeCallbacks(restartRunnable)
                    handler.postDelayed(restartRunnable, 2000)
                }
                return
            }

            // Network error fallback logic
            if (error == SpeechRecognizer.ERROR_NETWORK || error == SpeechRecognizer.ERROR_NETWORK_TIMEOUT) {
                consecutiveNetworkErrors++
                if (consecutiveNetworkErrors >= NETWORK_ERROR_FALLBACK_THRESHOLD && !isVoskFallbackActive) {
                    Log.w(TAG, "$consecutiveNetworkErrors network errors — switching to Vosk fallback")
                    NativeBridgeEventSink.sendLog(TAG, "$consecutiveNetworkErrors lỗi mạng liên tiếp — chuyển sang Vosk STT (offline fallback)", "WARN")
                    // Sprint 2 (C1): tell Dart to show a banner explaining
                    // why the engine changed. The UI uses the same STT_FALLBACK
                    // event shape as the Error-12 path for consistency.
                    NativeBridgeEventSink.sendMonitoringState(
                        "STT_FALLBACK:VOSK:network_errors_$consecutiveNetworkErrors"
                    )
                    switchToVoskFallback()
                    return
                }
            } else {
                consecutiveNetworkErrors = 0
            }

            if (error == SpeechRecognizer.ERROR_AUDIO || error == SpeechRecognizer.ERROR_RECOGNIZER_BUSY || error == 12) {
                if (error == 12) {
                    handleError12()
                    return
                }

                if (error == SpeechRecognizer.ERROR_AUDIO) {
                    consecutiveAudioErrors++
                    if (consecutiveAudioErrors >= AUDIO_ERROR_FALLBACK_THRESHOLD && !isVoskFallbackActive) {
                        Log.w(TAG, "$consecutiveAudioErrors consecutive audio errors — switching to Vosk fallback")
                        NativeBridgeEventSink.sendLog(TAG, "$consecutiveAudioErrors lỗi âm thanh liên tiếp — chuyển sang Vosk STT (offline fallback)", "WARN")
                        NativeBridgeEventSink.sendMonitoringState(
                            "STT_FALLBACK:VOSK:audio_error_$consecutiveAudioErrors"
                        )
                        switchToVoskFallback()
                        return
                    }
                } else {
                    consecutiveAudioErrors = 0
                }

                if (DEBUG_LOGS) Log.w(TAG, "Audio/Busy error ($error) - will retry in 2s")
                if (shouldBeListening) {
                    // Only remove our restart callbacks — not all handler callbacks
                    handler.removeCallbacks(restartRunnable)
                    handler.postDelayed(restartRunnable, 2000)
                }
            } else if (shouldBeListening && isRecoverable && error != SpeechRecognizer.ERROR_INSUFFICIENT_PERMISSIONS && error != SpeechRecognizer.ERROR_CLIENT) {
                consecutiveError12Count = 0
                consecutiveAudioErrors = 0
                handler.removeCallbacks(restartRunnable)
                handler.postDelayed(restartRunnable, 1000)
            }
        }

        override fun onResults(results: Bundle?) {
            // Bug fix: skip if Vosk is active (prevents race with switchToVoskFallback)
            if (isVoskFallbackActive) {
                if (DEBUG_LOGS) Log.d(TAG, "Vosk active — ignoring Google onResults")
                return
            }
            
            val result = results?.getStringArrayList(SpeechRecognizer.RESULTS_RECOGNITION)?.firstOrNull() ?: ""
            if (result.isNotEmpty()) {
                synchronized(transcriptLock) {
                    cumulativeTranscript = TranscriptOverlapJoiner.appendWithOverlapDetection(cumulativeTranscript, result)
                    _fullTranscriptFlow.value = cumulativeTranscript
                }
                _textResults.value = ""
                consecutiveError12Count = 0
                consecutiveNetworkErrors = 0
                consecutiveAudioErrors = 0
                consecutiveClientErrors = 0
            }
            _isListening.value = false
            if (shouldBeListening) {
                handler.post { if (shouldBeListening) startListening() }
            }
        }

        override fun onPartialResults(partialResults: Bundle?) {
            val partialResult = partialResults?.getStringArrayList(SpeechRecognizer.RESULTS_RECOGNITION)?.firstOrNull() ?: ""
            if (partialResult.isNotEmpty()) {
                // Only update textResults (current utterance) for partial results.
                // Do NOT overwrite _fullTranscriptFlow — partial results are temporary
                // and would cause Flutter to run analysis on incomplete text.
                _textResults.value = partialResult
            }
        }

        override fun onEvent(eventType: Int, params: Bundle?) {}
    }

    /**
     * Sprint 2 (B3): pause STT without forgetting the user's intent to
     * monitor. Used by `BackgroundMonitoringService` when audio focus is
     * lost transiently (e.g. another app starts a call, a navigation
     * prompt fires, etc.). The [resumeListening] call from the focus
     * listener will re-start recognition if the user was listening before.
     *
     * Implementation: cancel and destroy the current [SpeechRecognizer]
     * (frees the mic immediately) but keep [shouldBeListening] = true so
     * [startListening] knows to fire again on resume.
     */
    fun pauseListening() {
        if (DEBUG_LOGS) Log.d(TAG, "pauseListening() — cancelling recognizer but keeping intent")
        // Cancel any pending restart timer so it doesn't fire mid-pause.
        handler.removeCallbacks(restartRunnable)
        val recognizerToDestroy = speechRecognizer
        speechRecognizer = null
        handler.post {
            try {
                recognizerToDestroy?.cancel()
            } catch (e: Exception) {
                if (DEBUG_LOGS) Log.w(TAG, "Error cancelling during pause", e)
            }
            try {
                recognizerToDestroy?.destroy()
            } catch (e: Exception) {
                if (DEBUG_LOGS) Log.w(TAG, "Error destroying during pause", e)
            }
            _isListening.value = false
        }
        // If Vosk is the active engine, stop the mic read loop too but
        // keep the fallback flag so resumeListening re-starts it.
        if (isVoskFallbackActive) {
            stopVoskMicReading()
        }
    }

    /**
     * Sprint 2 (B3): counterpart to [pauseListening]. Re-starts the
     * appropriate engine iff [shouldBeListening] is still true. Safe to
     * call when the engine is already running (no-op).
     */
    fun resumeListening() {
        if (!shouldBeListening) {
            if (DEBUG_LOGS) Log.d(TAG, "resumeListening() — no intent to listen, skipping")
            return
        }
        if (isVoskFallbackActive) {
            val vosk = voskFallback
            if (vosk == null || !vosk.isModelReady) {
                if (DEBUG_LOGS) Log.d(TAG, "resumeListening() — Vosk not ready, skipping")
                return
            }
            // Vosk is the active engine — re-arm the mic read loop.
            startVoskMicReading(vosk)
        } else {
            startListening()
        }
    }

    fun startListening() {
        // Bug fix: skip if Vosk fallback is active (prevents race with switchToVoskFallback)
        if (isVoskFallbackActive) {
            if (DEBUG_LOGS) Log.d(TAG, "Vosk fallback active — skipping Google startListening")
            return
        }
        
        if (ContextCompat.checkSelfPermission(context, Manifest.permission.RECORD_AUDIO) != PackageManager.PERMISSION_GRANTED) {
            Log.e(TAG, "RECORD_AUDIO permission not granted. Cannot start speech recognition.")
            shouldBeListening = false
            _isListening.value = false
            _sttState.value = SttState.Error("Không có quyền RECORD_AUDIO", false)
            return
        }

        if (!SpeechRecognizer.isRecognitionAvailable(context)) {
            Log.w(TAG, "Google Speech recognition not available on this device — Vosk fallback will be used")
            _sttState.value = SttState.Error("Thiết bị không hỗ trợ nhận diện giọng nói", false)
            return
        }
        shouldBeListening = true

        // Only remove our restart callbacks — not all handler callbacks
        handler.removeCallbacks(restartRunnable)

        handler.post {
            if (isRestarting) {
                if (DEBUG_LOGS) Log.d(TAG, "Restart already in progress, skipping.")
                return@post
            }
            isRestarting = true
            Log.i(TAG, "Starting Google Speech recognition (vi-VN)...")
            _isListening.value = true
            try { speechRecognizer?.cancel() } catch (_: Exception) {}
            try { speechRecognizer?.destroy() } catch (_: Exception) {}

            // Bug #3 fix: the entire construction block is wrapped in
            // try/finally so the isRestarting flag is ALWAYS reset, even if
            // SpeechRecognizer.createSpeechRecognizer() throws (e.g. on a
            // broken device) or returns null. Without this, a single failure
            // permanently locks all future startListening() calls.
            try {
                val recognizer = SpeechRecognizer.createSpeechRecognizer(context)
                if (recognizer == null) {
                    Log.e(TAG, "createSpeechRecognizer returned null — STT permanently unavailable")
                    shouldBeListening = false
                    _sttState.value = SttState.Error("Không thể khởi tạo SpeechRecognizer", false)
                    return@post // finally still runs
                }
                recognizer.setRecognitionListener(recognitionListener)
                speechRecognizer = recognizer
                val intent = Intent(RecognizerIntent.ACTION_RECOGNIZE_SPEECH).apply {
                    putExtra(RecognizerIntent.EXTRA_LANGUAGE_MODEL, RecognizerIntent.LANGUAGE_MODEL_FREE_FORM)
                    putExtra(RecognizerIntent.EXTRA_LANGUAGE, "vi-VN")
                    putExtra(RecognizerIntent.EXTRA_PARTIAL_RESULTS, true)
                    putExtra("android.speech.extra.SPEECH_INPUT_COMPLETE_SILENCE_LENGTH_MILLIS", 10000)
                    putExtra("android.speech.extra.SPEECH_INPUT_POSSIBLY_COMPLETE_SILENCE_LENGTH_MILLIS", 10000)
                }
                try {
                    recognizer.startListening(intent)
                    Log.i(TAG, "Google Speech recognition start requested (awaiting onReadyForSpeech)")
                } catch (e: Exception) {
                    Log.e(TAG, "Error starting Google speech recognition", e)
                    handleError12()
                }
            } catch (e: Throwable) {
                Log.e(TAG, "Unexpected error creating SpeechRecognizer", e)
                // Don't crash — schedule a retry via the normal restart path.
                handler.postDelayed(restartRunnable, 2000)
            } finally {
                // Bug #3 fix: unconditional reset. Without this, any throw
                // from createSpeechRecognizer / setRecognitionListener /
                // startListening would leave isRestarting=true forever.
                isRestarting = false
            }
        }
    }

    fun stopListening() {
        if (DEBUG_LOGS) Log.d(TAG, "Stopping speech recognition...")
        shouldBeListening = false
        _isListening.value = false
        _sttState.value = SttState.Stopped

        consecutiveError12Count = 0
        consecutiveAudioErrors = 0
        consecutiveClientErrors = 0

        stopGoogleRetry()

        // Bug fix: Stop Vosk mic if active (previously only Google was cleaned up)
        if (isVoskFallbackActive) {
            if (DEBUG_LOGS) Log.d(TAG, "Stopping Vosk fallback mic...")
            stopVoskMicReading()
            isVoskFallbackActive = false
        }

        // Only remove our restart callbacks — not all handler callbacks
        // (prevents killing unrelated speakerphone enforcement callbacks).
        handler.removeCallbacks(restartRunnable)

        // Capture the current recognizer reference so we can safely null out
        // the field immediately. This prevents a race where stopListening()
        // is called twice and the second call tries to cancel a recognizer
        // that was already destroyed.
        val recognizerToDestroy = speechRecognizer
        speechRecognizer = null

        handler.post {
            try {
                recognizerToDestroy?.cancel()
            } catch (e: Exception) {
                if (DEBUG_LOGS) Log.w(TAG, "Error cancelling (may already be disconnected)", e)
            }

            try {
                recognizerToDestroy?.destroy()
            } catch (e: Exception) {
                if (DEBUG_LOGS) Log.w(TAG, "Error destroying (may already be disconnected)", e)
            }
        }

        if (DEBUG_LOGS) Log.d(TAG, "Speech recognition stopped")
    }

    private fun handleError12() {
        consecutiveError12Count++
        if (consecutiveError12Count >= MAX_CONSECUTIVE_ERROR12) {
            Log.e(TAG, "Stopped. Google Speech Service unavailable (Error 12 loop).")
            shouldBeListening = false
            _isListening.value = false
            _sttState.value = SttState.Error("Google Speech không khả dụng — chuyển sang chế độ dự phòng", false)

            // Sprint 2 (C1): replaced the Toast with a structured event
            // that the Dart UI renders as an in-page banner. Toasts are
            // easy to miss and look out of place in this app's design.
            NativeBridgeEventSink.sendMonitoringState(
                "STT_FALLBACK:VOSK:error12_loop"
            )

            handler.post {
                try { speechRecognizer?.cancel() } catch (_: Exception) {}
                try { speechRecognizer?.destroy() } catch (_: Exception) {}
                speechRecognizer = null
            }
            switchToVoskFallback()
        } else {
            if (shouldBeListening) {
                handler.removeCallbacks(restartRunnable)
                handler.postDelayed(restartRunnable, 2000)
            }
        }
    }

    private fun appendWithOverlapDetection(existing: String, newSegment: String): String {
        return TranscriptOverlapJoiner.appendWithOverlapDetection(existing, newSegment)
    }

    override fun start() = startListening()

    override fun stop() = stopListening()

    override fun clearTranscript() {
        cumulativeTranscript = ""
        _fullTranscriptFlow.value = ""
        _textResults.value = ""
    }

    /**
     * Release the heavy Vosk native model early — called from the host
     * service's onDestroy() before the service scope cancels — so the
     * acoustic model (potentially 100s of MB) is reclaimed promptly
     * instead of waiting for the full teardown chain.
     *
     * Idempotent: after this runs, [voskFallback] is nulled so the later
     * [destroy] call is a no-op for the Vosk side. Safe to call from any
     * thread: VoskSttManager.destroy() routes close() through the main
     * looper to serialize with in-flight model init.
     */
    fun releaseVoskModel() {
        if (voskFallback == null) return
        stopVoskMicReading()
        voskFallback?.destroy()
        voskFallback = null
        Log.i(TAG, "Vosk native model released early in host onDestroy")
    }

    override fun destroy() {
        shouldBeListening = false
        stopListening()
        stopGoogleRetry()
        stopVoskFallback()
        voskFallback?.destroy()
        voskFallback = null
    }

    // Vosk Fallback: Mic-based offline STT
    private fun switchToVoskFallback() {
        val vosk = voskFallback
        if (vosk == null || !vosk.isModelReady) {
            Log.w(TAG, "Vosk fallback không sẵn sàng — không thể chuyển")
            // Bug fix: cleanup limbo state (previously left shouldBeListening=true with no engine)
            shouldBeListening = false
            _isListening.value = false
            _sttState.value = SttState.Error("STT fallback không khả dụng", false)
            return
        }

        Log.i(TAG, "Switching STT engine: Google → Vosk (offline fallback)")
        isVoskFallbackActive = true
        // Bug #33 fix: reset all error counters when switching engines so a
        // stale error count from Google STT doesn't immediately trigger
        // another fallback when we switch back.
        consecutiveNetworkErrors = 0
        consecutiveClientErrors = 0
        consecutiveAudioErrors = 0
        consecutiveError12Count = 0
        _sttState.value = SttState.Error("Mất mạng — chuyển sang nhận diện offline", true)
        onEngineSwitched?.invoke(true)

        // Destroy Google SpeechRecognizer before switching to Vosk
        val recognizerToDestroy = speechRecognizer
        speechRecognizer = null
        handler.post {
            try { recognizerToDestroy?.cancel() } catch (_: Exception) {}
            try { recognizerToDestroy?.destroy() } catch (_: Exception) {}
        }

        startVoskMicReading(vosk)
        startGoogleRetry()
    }

    private fun switchToGoogle() {
        Log.i(TAG, "Switching STT engine: Vosk → Google (online restored)")
        isVoskFallbackActive = false
        // Bug #33 fix: reset all error counters on every engine switch so
        // counters don't leak across engines.
        consecutiveNetworkErrors = 0
        consecutiveClientErrors = 0
        consecutiveAudioErrors = 0
        consecutiveError12Count = 0
        onEngineSwitched?.invoke(false)

        stopGoogleRetry()
        stopVoskMicReading()

        if (shouldBeListening) {
            startListening()
        }
    }

    @Suppress("MissingPermission")
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
                .setAudioSource(android.media.MediaRecorder.AudioSource.VOICE_RECOGNITION)
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

        try {
            record.startRecording()
        } catch (e: Exception) {
            Log.e(TAG, "Failed to start Vosk recording (likely locked by telephony)", e)
            record.release()
            _sttState.value = SttState.Error("Không thể thu âm ngoại tuyến (mic đang bị chiếm dụng)", false)
            _isListening.value = false
            // Bug #19 fix: schedule a retry. The mic is often briefly held
            // by telephony at the start of a call; a 2-second retry catches
            // the case where the call becomes stable and the mic is released.
            // Without this retry the entire monitoring session would have no
            // audio for the rest of the call.
            scheduleVoskMicRetry()
            return
        }

        voskMicRecord = record
        vosk.resetTranscript()
        _isListening.value = true
        _sttState.value = SttState.Listening
        Log.i(TAG, "Vosk offline STT is now listening (mic read loop started)")

        voskMicJob = voskScope.launch {
            val buffer = ByteArray(bufferSize)
            var readsSinceLastRms = 0
            try {
                while (isActive && isVoskFallbackActive) {
                    val read = record.read(buffer, 0, buffer.size)
                    if (read > 0) {
                        vosk.processAudioBuffer(buffer, read)
                        if (++readsSinceLastRms >= VOSK_RMS_THROTTLE_READS) {
                            readsSinceLastRms = 0
                            // Zero-allocation RMS: iterate byte pairs directly
                            // instead of creating List/Chunked/MapNotNull/Map chains.
                            var sum = 0.0
                            var count = 0
                            var i = 0
                            while (i + 1 < read) {
                                val sample = (buffer[i + 1].toInt() shl 8 or (buffer[i].toInt() and 0xFF)).toShort().toInt()
                                sum += if (sample >= 0) sample.toDouble() else -sample.toDouble()
                                count++
                                i += 2
                            }
                            val amplitude = if (count > 0) (sum / count).toFloat() else 0f
                            val normalizedRms = (amplitude / 2184f).coerceIn(0f, 15f)
                            _rmsDbFlow.value = normalizedRms
                        }
                    } else if (read < 0) {
                        break
                    }
                }
            } catch (e: Exception) {
                Log.e(TAG, "Vosk mic read loop error", e)
            }
        }

        voskMicJob?.invokeOnCompletion {
            // Bug fix: only stop, don't release (stopVoskMicReading handles release)
            // Previously both paths called release(), causing double-release on native resource
            try {
                record.stop()
            } catch (_: Exception) {}
        }

        voskScope.launch {
            vosk.voskFullTranscript.collect { text ->
                if (isVoskFallbackActive) {
                    synchronized(transcriptLock) {
                        cumulativeTranscript = text
                        _fullTranscriptFlow.value = text
                    }
                }
            }
        }

        voskScope.launch {
            vosk.voskTextResults.collect { text ->
                if (isVoskFallbackActive) {
                    _textResults.value = text
                }
            }
        }

        Log.i(TAG, "Vosk fallback mic reading started")
    }

    private fun stopVoskMicReading() {
        voskMicJob?.cancel()
        voskMicJob = null
        
        // Bug fix: cancel flow collectors to prevent memory leak
        // (previously only voskMicJob was cancelled, flow collectors accumulated)
        voskScope.coroutineContext.cancelChildren()
        
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

    // Bug #19 fix: retry mechanism for the case where telephony briefly
    // holds the mic lock. Bounded to VOSK_RETRY_MAX_ATTEMPTS to avoid
    // spinning forever on a device where the mic is genuinely unavailable.
    private var voskRetryCount = 0
    private val VOSK_RETRY_MAX_ATTEMPTS = 3
    private val VOSK_RETRY_DELAY_MS = 2000L

    private fun scheduleVoskMicRetry() {
        voskRetryCount++
        if (voskRetryCount > VOSK_RETRY_MAX_ATTEMPTS) {
            Log.w(TAG, "Vosk mic retry exhausted after $VOSK_RETRY_MAX_ATTEMPTS attempts — staying silent")
            return
        }
        if (!shouldBeListening || !isVoskFallbackActive) {
            // User or system already gave up — no point retrying.
            voskRetryCount = 0
            return
        }
        Log.d(TAG, "Scheduling Vosk mic retry #${voskRetryCount}/$VOSK_RETRY_MAX_ATTEMPTS in ${VOSK_RETRY_DELAY_MS}ms")
        handler.postDelayed({
            val vosk = voskFallback ?: return@postDelayed
            if (vosk.isModelReady && isVoskFallbackActive && shouldBeListening) {
                startVoskMicReading(vosk)
                // Bug fix (review): only reset retry count when
                // startVoskMicReading actually succeeded. Previously the
                // count was reset unconditionally, so if startVoskMicReading
                // failed silently (returned without throwing), the retry
                // loop would spin forever.
                if (_isListening.value) {
                    voskRetryCount = 0
                }
            }
        }, VOSK_RETRY_DELAY_MS)
    }

    private fun stopVoskFallback() {
        isVoskFallbackActive = false
        stopVoskMicReading()
    }

    // ── Google Retry: periodically try switching back from Vosk ─────────

    private fun startGoogleRetry() {
        stopGoogleRetry()
        googleRetryCount = 0
        scheduleGoogleRetryAttempt()
    }

    private fun stopGoogleRetry() {
        handler.removeCallbacks(googleRetryRunnable)
        googleRetryCount = 0
    }

    private fun scheduleGoogleRetryAttempt() {
        handler.removeCallbacks(googleRetryRunnable)
        if (googleRetryCount < GOOGLE_RETRY_MAX_ATTEMPTS) {
            handler.postDelayed(googleRetryRunnable, GOOGLE_RETRY_INTERVAL_MS)
        }
    }

    private fun attemptGoogleRetry() {
        if (!isVoskFallbackActive || !shouldBeListening) return
        if (!SpeechRecognizer.isRecognitionAvailable(context)) {
            Log.d(TAG, "Google retry #${googleRetryCount + 1}: STT not available, retrying later")
            googleRetryCount++
            scheduleGoogleRetryAttempt()
            return
        }

        googleRetryCount++
        Log.i(TAG, "Google retry #$googleRetryCount: attempting to switch back from Vosk")

        // Stop Vosk mic temporarily to free the microphone
        stopVoskMicReading()

        // Try creating a test SpeechRecognizer to check if the service is responsive
        handler.post {
            if (!isVoskFallbackActive || !shouldBeListening) return@post
            val testRecognizer = SpeechRecognizer.createSpeechRecognizer(context)
            if (testRecognizer == null) {
                Log.w(TAG, "Google retry #$googleRetryCount: createSpeechRecognizer returned null")
                resumeVoskIfNeeded()
                googleRetryCount++
                scheduleGoogleRetryAttempt()
                return@post
            }
            var decided = false
            // Safety timeout: if the recognizer neither fires onReadyForSpeech
            // nor onError within GOOGLE_TEST_TIMEOUT_MS (e.g. the Google speech
            // service is hung), we must NOT leave Vosk mic stopped forever —
            // resume it and reschedule. Without this, the call goes silent.
            val timeoutRunnable = Runnable {
                if (decided) return@Runnable
                decided = true
                Log.w(TAG, "Google retry #$googleRetryCount: test recognizer timed out — staying on Vosk")
                try { testRecognizer.cancel() } catch (_: Exception) {}
                try { testRecognizer.destroy() } catch (_: Exception) {}
                resumeVoskIfNeeded()
                googleRetryCount++
                scheduleGoogleRetryAttempt()
            }
            handler.postDelayed(timeoutRunnable, GOOGLE_TEST_TIMEOUT_MS)
            testRecognizer.setRecognitionListener(object : RecognitionListener {
                override fun onReadyForSpeech(params: Bundle?) {
                    if (decided) return
                    decided = true
                    handler.removeCallbacks(timeoutRunnable)
                    Log.i(TAG, "Google retry #$googleRetryCount: service responsive — switching back to Google")
                    try { testRecognizer.cancel() } catch (_: Exception) {}
                    try { testRecognizer.destroy() } catch (_: Exception) {}
                    handler.post { switchToGoogle() }
                }
                override fun onBeginningOfSpeech() {}
                override fun onRmsChanged(rmsdB: Float) {}
                override fun onBufferReceived(buffer: ByteArray?) {}
                override fun onEndOfSpeech() {}
                override fun onError(error: Int) {
                    if (decided) return
                    decided = true
                    handler.removeCallbacks(timeoutRunnable)
                    Log.d(TAG, "Google retry #$googleRetryCount: service responded with error $error — staying on Vosk")
                    try { testRecognizer.cancel() } catch (_: Exception) {}
                    try { testRecognizer.destroy() } catch (_: Exception) {}
                    resumeVoskIfNeeded()
                    googleRetryCount++
                    scheduleGoogleRetryAttempt()
                }
                override fun onResults(results: Bundle?) {}
                override fun onPartialResults(partialResults: Bundle?) {}
                override fun onEvent(eventType: Int, params: Bundle?) {}
            })
            try {
                val intent = Intent(RecognizerIntent.ACTION_RECOGNIZE_SPEECH).apply {
                    putExtra(RecognizerIntent.EXTRA_LANGUAGE_MODEL, RecognizerIntent.LANGUAGE_MODEL_FREE_FORM)
                    putExtra(RecognizerIntent.EXTRA_LANGUAGE, "vi-VN")
                    putExtra(RecognizerIntent.EXTRA_PARTIAL_RESULTS, false)
                }
                testRecognizer.startListening(intent)
            } catch (e: Exception) {
                if (decided) return@post
                decided = true
                handler.removeCallbacks(timeoutRunnable)
                Log.w(TAG, "Google retry #$googleRetryCount: startListening threw — staying on Vosk")
                try { testRecognizer.destroy() } catch (_: Exception) {}
                resumeVoskIfNeeded()
                googleRetryCount++
                scheduleGoogleRetryAttempt()
            }
        }
    }

    private fun resumeVoskIfNeeded() {
        if (isVoskFallbackActive && shouldBeListening) {
            val vosk = voskFallback
            if (vosk != null && vosk.isModelReady) {
                startVoskMicReading(vosk)
            }
        }
    }
}
