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
import com.lachancuocgoi.lachancuocgoi_flutter.diagnostics.MonitoringPerfProbe
import com.lachancuocgoi.lachancuocgoi_flutter.services.stt.SttErrorClassifier
import com.lachancuocgoi.lachancuocgoi_flutter.services.stt.SttRestartPolicy
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
        private const val GOOGLE_RETRY_INTERVAL_MS = 30_000L
        private const val GOOGLE_RETRY_MAX_ATTEMPTS = 10

        private const val GOOGLE_TEST_TIMEOUT_MS = 5_000L
        private const val VOSK_SAMPLE_RATE = 16000
        private const val VOSK_CHANNEL_CONFIG = AudioFormat.CHANNEL_IN_MONO
        private const val VOSK_AUDIO_FORMAT = AudioFormat.ENCODING_PCM_16BIT

        private const val VOSK_RMS_THROTTLE_READS = 3
    }

    override val name = "Google"

    private var voskFallback: VoskSttManager? = null
    private var voskMicRecord: AudioRecord? = null
    private var voskMicJob: Job? = null
    private val voskScope = CoroutineScope(Dispatchers.IO + SupervisorJob())
    @Volatile private var isVoskFallbackActive = false
    private val restartPolicy = SttRestartPolicy()

    var onEngineSwitched: ((isVosk: Boolean) -> Unit)? = null

    fun preloadVoskFallback() {
        if (voskFallback == null) {
            voskFallback = VoskSttManager(context)
            Log.d(TAG, "Vosk fallback model preloading...")
            NativeBridgeEventSink.sendLog(TAG, "Vosk fallback model preloading...", "INFO")
        }
    }

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
    private val transcriptLock = Any()
    private val _fullTranscriptFlow = MutableStateFlow("")
    override val fullTranscriptFlow = _fullTranscriptFlow.asStateFlow()

    private val _isListening = MutableStateFlow(false)
    override val isListening = _isListening.asStateFlow()

    private val _sttState = MutableStateFlow<SttState>(SttState.Idle)
    val sttState = _sttState.asStateFlow()

    private val _rmsDbFlow = MutableStateFlow(0f)
    override val rmsDbFlow = _rmsDbFlow.asStateFlow()

    private var shouldBeListening = false

    val shouldBeListeningSnapshot: Boolean
        get() = shouldBeListening

    @Volatile private var isRestarting = false
    private var speechRecognizer: SpeechRecognizer? = null
    private val handler = Handler(Looper.getMainLooper())

    private var consecutiveError12Count = 0
    private val MAX_CONSECUTIVE_ERROR12 = 20

    private var googleRetryCount = 0
    private val googleRetryRunnable = Runnable { attemptGoogleRetry() }

    override val isReady: Boolean
        get() = !isVoskFallbackActive

    private val restartRunnable = Runnable {
        if (shouldBeListening) startListening()
    }

    private val recognitionListener = object : RecognitionListener {
        override fun onReadyForSpeech(params: Bundle?) {
            MonitoringPerfProbe.mark("speech_on_ready")
            restartPolicy.onSuccess()
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
            MonitoringPerfProbe.mark("speech_on_error", "code=$error")
            val errorMessage = SttErrorClassifier.describe(error)
            if (DEBUG_LOGS ||
                (
                    error != SpeechRecognizer.ERROR_AUDIO &&
                        error != SpeechRecognizer.ERROR_RECOGNIZER_BUSY &&
                        error != 12
                    )
            ) {
                Log.e(TAG, "onError: $errorMessage")
                NativeBridgeEventSink.sendLog(TAG, "Google Speech Recognizer error: $errorMessage", "ERROR")
            }
            _isListening.value = false

            val isRecoverable = SttErrorClassifier.isRetryable(error)
            _sttState.value = SttState.Error(errorMessage, isRecoverable)

            if (SttErrorClassifier.isError12(error)) {
                handleError12()
                return
            }

            val decision = restartPolicy.onError(error, isVoskFallbackActive)
            when (decision.action) {
                SttRestartPolicy.Action.FALLBACK_VOSK -> {
                    Log.w(TAG, "STT policy fallback to Vosk: ${decision.reason}")
                    NativeBridgeEventSink.sendLog(
                        TAG,
                        "Chuyển sang Vosk STT (offline fallback): ${decision.reason}",
                        "WARN",
                    )
                    NativeBridgeEventSink.sendMonitoringState(
                        "STT_FALLBACK:VOSK:${decision.reason}",
                    )
                    if (SttErrorClassifier.isClientError(error)) {
                        handler.post {
                            try {
                                speechRecognizer?.cancel()
                            } catch (_: Exception) {
                            }
                            try {
                                speechRecognizer?.destroy()
                            } catch (_: Exception) {
                            }
                            speechRecognizer = null
                        }
                    }
                    switchToVoskFallback()
                }
                SttRestartPolicy.Action.RETRY_DELAYED -> {
                    if (shouldBeListening) {
                        handler.removeCallbacks(restartRunnable)
                        handler.postDelayed(restartRunnable, decision.retryDelayMs)
                    }
                }
                SttRestartPolicy.Action.NONE -> Unit
            }
        }

        override fun onResults(results: Bundle?) {

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
                restartPolicy.onSuccess()
            }
            _isListening.value = false
            if (shouldBeListening) {
                handler.post { if (shouldBeListening) startListening() }
            }
        }

        override fun onPartialResults(partialResults: Bundle?) {
            val partialResult = partialResults?.getStringArrayList(SpeechRecognizer.RESULTS_RECOGNITION)?.firstOrNull() ?: ""
            if (partialResult.isNotEmpty()) {

                _textResults.value = partialResult
            }
        }

        override fun onEvent(eventType: Int, params: Bundle?) {}
    }

    fun pauseListening() {
        if (DEBUG_LOGS) Log.d(TAG, "pauseListening() — cancelling recognizer but keeping intent")

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

        if (isVoskFallbackActive) {
            stopVoskMicReading()
        }
    }

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

            startVoskMicReading(vosk)
        } else {
            startListening()
        }
    }

    fun startListening() {

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

        val availabilityToken = MonitoringPerfProbe.begin("speech_start_available_check")
        val recognitionAvailable = try {
            SpeechRecognizer.isRecognitionAvailable(context)
        } finally {
            MonitoringPerfProbe.end(availabilityToken)
        }
        if (!recognitionAvailable) {
            Log.w(TAG, "Google Speech recognition not available on this device — Vosk fallback will be used")
            _sttState.value = SttState.Error("Thiết bị không hỗ trợ nhận diện giọng nói", false)
            return
        }
        shouldBeListening = true

        handler.removeCallbacks(restartRunnable)

        val enqueuedAtNanos = MonitoringPerfProbe.nowNanos()
        MonitoringPerfProbe.mark("speech_main_task_enqueued")
        handler.post {
            if (isRestarting) {
                MonitoringPerfProbe.mark("speech_main_task_skipped", "reason=already_restarting")
                if (DEBUG_LOGS) Log.d(TAG, "Restart already in progress, skipping.")
                return@post
            }
            val queueDelayMs =
                (MonitoringPerfProbe.nowNanos() - enqueuedAtNanos) / 1_000_000.0
            val mainTaskToken = MonitoringPerfProbe.begin(
                "speech_main_task",
                "queue_ms=$queueDelayMs",
            )
            var mainTaskOutcome = "success=true"
            isRestarting = true
            Log.i(TAG, "Starting Google Speech recognition (vi-VN)...")
            _isListening.value = true
            val cleanupToken = MonitoringPerfProbe.begin("speech_previous_recognizer_cleanup")
            try {
                try { speechRecognizer?.cancel() } catch (_: Exception) {}
                try { speechRecognizer?.destroy() } catch (_: Exception) {}
            } finally {
                MonitoringPerfProbe.end(cleanupToken)
            }

            try {
                val createToken = MonitoringPerfProbe.begin("speech_create_recognizer")
                val recognizer = try {
                    SpeechRecognizer.createSpeechRecognizer(context).also {
                        MonitoringPerfProbe.end(
                            createToken,
                            "success=${it != null}",
                        )
                    }
                } catch (error: Throwable) {
                    MonitoringPerfProbe.end(
                        createToken,
                        "success=false,error=${error.javaClass.simpleName}",
                    )
                    throw error
                }
                if (recognizer == null) {
                    mainTaskOutcome = "success=false,error=null_recognizer"
                    Log.e(TAG, "createSpeechRecognizer returned null — STT permanently unavailable")
                    shouldBeListening = false
                    _sttState.value = SttState.Error("Không thể khởi tạo SpeechRecognizer", false)
                    return@post
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
                    val startToken = MonitoringPerfProbe.begin("speech_start_listening_ipc")
                    try {
                        recognizer.startListening(intent)
                    } finally {
                        MonitoringPerfProbe.end(startToken)
                    }
                    Log.i(TAG, "Google Speech recognition start requested (awaiting onReadyForSpeech)")
                } catch (e: Exception) {
                    mainTaskOutcome = "success=false,error=${e.javaClass.simpleName}"
                    Log.e(TAG, "Error starting Google speech recognition", e)
                    handleError12()
                }
            } catch (e: Throwable) {
                mainTaskOutcome = "success=false,error=${e.javaClass.simpleName}"
                Log.e(TAG, "Unexpected error creating SpeechRecognizer", e)

                handler.postDelayed(restartRunnable, 2000)
            } finally {

                isRestarting = false
                MonitoringPerfProbe.end(mainTaskToken, mainTaskOutcome)
            }
        }
    }

    fun stopListening() {
        if (DEBUG_LOGS) Log.d(TAG, "Stopping speech recognition...")
        shouldBeListening = false
        _isListening.value = false
        _sttState.value = SttState.Stopped

        consecutiveError12Count = 0
        restartPolicy.reset()

        stopGoogleRetry()

        if (isVoskFallbackActive) {
            if (DEBUG_LOGS) Log.d(TAG, "Stopping Vosk fallback mic...")
            stopVoskMicReading()
            isVoskFallbackActive = false
        }

        handler.removeCallbacks(restartRunnable)

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

    private fun switchToVoskFallback() {
        val vosk = voskFallback
        if (vosk == null || !vosk.isModelReady) {
            Log.w(TAG, "Vosk fallback không sẵn sàng — không thể chuyển")

            shouldBeListening = false
            _isListening.value = false
            _sttState.value = SttState.Error("STT fallback không khả dụng", false)
            return
        }

        Log.i(TAG, "Switching STT engine: Google → Vosk (offline fallback)")
        isVoskFallbackActive = true

        consecutiveError12Count = 0
        restartPolicy.reset()
        _sttState.value = SttState.Error("Mất mạng — chuyển sang nhận diện offline", true)
        onEngineSwitched?.invoke(true)

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

        consecutiveError12Count = 0
        restartPolicy.reset()
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

            voskRetryCount = 0
            return
        }
        Log.d(TAG, "Scheduling Vosk mic retry #${voskRetryCount}/$VOSK_RETRY_MAX_ATTEMPTS in ${VOSK_RETRY_DELAY_MS}ms")
        handler.postDelayed({
            val vosk = voskFallback ?: return@postDelayed
            if (vosk.isModelReady && isVoskFallbackActive && shouldBeListening) {
                startVoskMicReading(vosk)

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

        stopVoskMicReading()

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

