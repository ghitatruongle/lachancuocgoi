package com.example.lachancuocgoi.ui.MonitoringPage

import android.app.Application
import android.content.Context
import android.media.AudioManager
import android.media.AudioRecord
import android.media.projection.MediaProjection
import android.util.Log
import androidx.compose.runtime.mutableStateListOf
import androidx.lifecycle.ViewModel
import androidx.lifecycle.ViewModelProvider
import androidx.lifecycle.viewModelScope
import com.example.lachancuocgoi.Analysis.AnalysisCoordinator
import com.example.lachancuocgoi.Analysis.AnalysisLevel
import com.example.lachancuocgoi.Analysis.AnalysisModePolicy
import com.example.lachancuocgoi.Analysis.AnalysisResult
import com.example.lachancuocgoi.RiskLevel
import com.example.lachancuocgoi.audio.CreatorAudioCaptureManager
import com.example.lachancuocgoi.services.ConnectivityMonitor
import com.example.lachancuocgoi.services.SpeechToTextManager
import com.example.lachancuocgoi.services.TranscriptionHub
import com.example.lachancuocgoi.services.VoskSttManager
import com.example.lachancuocgoi.data.AlertHistoryEntry
import com.example.lachancuocgoi.data.CallHistory
import com.example.lachancuocgoi.data.CallHistoryDao
import com.example.lachancuocgoi.data.TranscriptSaver
import com.example.lachancuocgoi.ui.HomePage.SettingsDialog.AnalysisMode
import com.example.lachancuocgoi.ui.HomePage.SettingsDialog.DeveloperModeManager
import com.example.lachancuocgoi.ui.HomePage.SettingsDialog.SettingsState
import com.example.lachancuocgoi.ui.SimulationPage.SimulationScenarioData
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.Job
import kotlinx.coroutines.SupervisorJob
import kotlinx.coroutines.delay
import kotlinx.coroutines.flow.MutableSharedFlow
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.asSharedFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.flow.collectLatest
import kotlinx.coroutines.flow.combine
import kotlinx.coroutines.flow.debounce
import kotlinx.coroutines.flow.launchIn
import kotlinx.coroutines.flow.onEach
import kotlinx.coroutines.launch
import kotlinx.coroutines.withContext
import java.text.SimpleDateFormat
import java.util.Date
import java.util.Locale
import com.example.lachancuocgoi.R
import com.google.gson.Gson
import com.google.gson.reflect.TypeToken

private const val WAVEFORM_SIZE = 100
private const val L3_REPLAY_WINDOW_CHARS = 1000
private const val L3_RECOVERY_RETRY_MS = 10_000L
private const val NETWORK_RECOVERY_DEBOUNCE_MS = 1_500L

data class AlertInfo(val level: RiskLevel, val reason: String)

/**
 * Đại diện cho một cảnh báo trong hàng đợi với metadata.
 */
data class QueuedAlert(
    val info: AlertInfo,
    val analysisLevel: AnalysisLevel,
    val timestamp: Long = System.currentTimeMillis()
)

@OptIn(kotlinx.coroutines.FlowPreview::class)
class MonitoringViewModel(private val application: Application, private val callHistoryDao: CallHistoryDao) : ViewModel() {

    private val TAG = "MonitoringViewModel"

    private val speechToTextManager = SpeechToTextManager(application)
    private val analysisCoordinator = AnalysisCoordinator(application)
    private val connectivityMonitor = ConnectivityMonitor(application)

    private var isStopping = false
    private var originalVoiceCallVolume: Int = -1

    // ── Creator Mode (Developer Only) ────────────────────────────────────────
    // MediaProjection token được set từ bên ngoài bởi MonitoringPage
    // khi người dùng chấp nhận system dialog "Bắt đầu ghi màn hình?"
    @Volatile private var creatorMediaProjection: MediaProjection? = null
    
    // ======= PHẦN MỚI CHO BACKGROUND CREATOR MODE =======
    private var creatorAmplitudeJob: Job? = null
    private var creatorTextJob: Job? = null

    // Simulation
    private var isSimulationMode = false
    private var simulationJob: Job? = null
    
    // Lưu settings gốc khi vào simulation mode để khôi phục sau
    private var originalSettingsBeforeSimulation: SettingsState? = null
    
    // Lưu settings gốc khi L3 mất mạng để khôi phục sau cuộc gọi
    private var originalSettingsBeforeFallback: SettingsState? = null
    private var hasShownFallbackAlertForCurrentOutage = false
    private var lastL3RecoveryAttemptAt = 0L

    // ===== HỆ THỐNG BATCH PROCESSING CẢNH BÁO =====
    // Hàng đợi riêng cho L1 và L2 (batch processing) - Thread-safe
    private val l1AlertQueue = java.util.Collections.synchronizedList(mutableListOf<QueuedAlert>())
    private val l2AlertQueue = java.util.Collections.synchronizedList(mutableListOf<QueuedAlert>())
    
    // Theo dõi xem đã gửi cảnh báo đầu tiên chưa
    @Volatile
    private var hasShownFirstL1Alert = false
    
    @Volatile
    private var hasShownFirstL2Alert = false

    // Timer jobs cho batch processing
    private var l1BatchJob: Job? = null
    private var l2BatchJob: Job? = null
    
    // Timestamp của lần thêm vào queue gần nhất (để tính thời gian batch)
    private var l1LastQueueTime = 0L
    private var l2LastQueueTime = 0L
    
    // SupervisorJob để quản lý coroutines - tránh memory leak
    private val supervisorJob = SupervisorJob()
    
    // Lưu trữ alert history cho cuộc gọi hiện tại
    private val currentAlertHistory = mutableListOf<AlertHistoryEntry>()

    private val _currentSettings = MutableStateFlow<SettingsState?>(null)
    private val _selectedMode = MutableStateFlow(AnalysisMode.GDetection)
    val selectedMode = _selectedMode.asStateFlow()

    private val _effectiveMode = MutableStateFlow(AnalysisMode.GDetection)
    val effectiveMode = _effectiveMode.asStateFlow()

    private val _networkAvailable = MutableStateFlow(connectivityMonitor.checkCurrentConnectivity())
    val networkAvailable = _networkAvailable.asStateFlow()

    private val _isFallbackActive = MutableStateFlow(false)
    val isFallbackActive = _isFallbackActive.asStateFlow()

    private val _transcript = MutableStateFlow("")
    val transcript = _transcript.asStateFlow()

    private val _analysisResult = MutableStateFlow(AnalysisResult(RiskLevel.GREEN, emptyList()))
    val analysisResult = _analysisResult.asStateFlow()

    private val _currentAlert = MutableStateFlow<AlertInfo?>(null)
    val currentAlert = _currentAlert.asStateFlow()

    private val _amplitudes = mutableStateListOf<Float>().apply { addAll(List(WAVEFORM_SIZE) { 0f }) }
    val amplitudes: List<Float> = _amplitudes

    private val _elapsedTime = MutableStateFlow(0L)
    val elapsedTime = _elapsedTime.asStateFlow()

    private val _isListeningInternal = MutableStateFlow(false)
    val isListening = _isListeningInternal.asStateFlow()

    private val _navigationEvent = MutableSharedFlow<Long>()
    val navigationEvent = _navigationEvent.asSharedFlow()

    private var timerJob: Job? = null
    private var waveformJob: Job? = null

    init {
        connectivityMonitor.start()

        // Preload Vosk model để sẵn sàng fallback khi mất mạng
        speechToTextManager.preloadVoskFallback()

        combine(
            speechToTextManager.fullTranscriptFlow,
            TranscriptionHub.transcriptFlow,
            CreatorAudioCaptureManager.creatorTranscriptFlow
        ) { stt, acc, creator ->
            listOf(stt, acc, creator)
                .filter { it.isNotBlank() }
                .joinToString("\n")
                .trim()
        }.onEach { fullText ->
            if (fullText.isNotBlank() && !isSimulationMode) {
                _transcript.value = fullText
            }
        }.launchIn(viewModelScope)

        viewModelScope.launch {
            speechToTextManager.isListening.collectLatest { listening ->
                if (!isSimulationMode) {
                    _isListeningInternal.value = listening
                    if (listening) {
                        startTimer()
                        startWaveformCollection()
                    } else {
                        timerJob?.cancel()
                        waveformJob?.cancel()
                    }
                }
            }
        }

        // Creator Mode: collect amplitude cho waveform + set listening state
        viewModelScope.launch {
            CreatorAudioCaptureManager.amplitudeFlow.collect { amp ->
                if (DeveloperModeManager.isDevModeActive()) {
                    updateAmplitudes(amp)
                }
            }
        }
        viewModelScope.launch {
            CreatorAudioCaptureManager.state.collectLatest { state ->
                if (!isSimulationMode && DeveloperModeManager.isDevModeActive()) {
                    val isCapturing = state == CreatorAudioCaptureManager.CaptureState.CAPTURING
                    _isListeningInternal.value = isCapturing
                    if (isCapturing) {
                        startTimer()
                        startWaveformCollection()
                    }
                }
            }
        }

        viewModelScope.launch {
            connectivityMonitor.isNetworkAvailable.collectLatest { isAvailable ->
                handleConnectivityChanged(isAvailable)
            }
        }

        viewModelScope.launch(Dispatchers.IO) {
            transcript.debounce(500).collect { currentFullText ->
                if (currentFullText.isNotBlank()) {
                    analyzeTranscriptIncrementally(currentFullText)
                }
            }
        }
    }

    fun updateSettings(newSettings: SettingsState) {
        _currentSettings.value = newSettings
        val previousSelectedMode = _selectedMode.value
        _selectedMode.value = newSettings.analysisMode
        refreshRuntimeState(newSettings.analysisMode)

        if (previousSelectedMode != newSettings.analysisMode) {
            viewModelScope.launch {
                handleSelectedModeChanged(previousSelectedMode, newSettings.analysisMode)
            }
        }
    }

    private fun refreshRuntimeState(selectedMode: AnalysisMode = _selectedMode.value) {
        val runtimeState = AnalysisModePolicy.createRuntimeState(
            selectedMode = selectedMode,
            networkAvailable = _networkAvailable.value
        )
        _selectedMode.value = runtimeState.selectedMode
        _effectiveMode.value = runtimeState.effectiveMode
        _isFallbackActive.value = runtimeState.isFallbackActive
    }

    private fun isSessionActive(): Boolean {
        return isSimulationMode || _isListeningInternal.value
    }

    private suspend fun handleConnectivityChanged(isAvailable: Boolean) {
        val previousState = _networkAvailable.value
        _networkAvailable.value = isAvailable

        if (_selectedMode.value != AnalysisMode.GEMINI_API) {
            _effectiveMode.value = _selectedMode.value
            _isFallbackActive.value = false
            return
        }

        if (!isSessionActive()) {
            refreshRuntimeState()
            return
        }

        if (!isAvailable) {
            enterL3FallbackMode(showAlert = previousState)
            return
        }

        if (!previousState && isAvailable) {
            // Thông báo cho STT engine: mạng đã trở lại → chuyển về Google nếu đang dùng Vosk fallback
            speechToTextManager.onNetworkRestored()
            delay(NETWORK_RECOVERY_DEBOUNCE_MS)
            if (_networkAvailable.value && _selectedMode.value == AnalysisMode.GEMINI_API) {
                tryRecoverL3Session(_transcript.value, force = true)
            }
        }
    }

    private suspend fun handleSelectedModeChanged(
        previousSelectedMode: AnalysisMode,
        newSelectedMode: AnalysisMode
    ) {
        if (previousSelectedMode == AnalysisMode.GEMINI_API && newSelectedMode != AnalysisMode.GEMINI_API) {
            analysisCoordinator.closeL3Session(resetProgress = true)
            hasShownFallbackAlertForCurrentOutage = false
        }

        analysisCoordinator.resetMode(newSelectedMode)
        withContext(Dispatchers.Main) {
            _analysisResult.value = AnalysisResult(RiskLevel.GREEN, emptyList())
            _currentAlert.value = null
        }

        if (!isSessionActive()) {
            refreshRuntimeState(selectedMode = newSelectedMode)
            return
        }

        if (newSelectedMode == AnalysisMode.GEMINI_API) {
            if (_networkAvailable.value) {
                tryRecoverL3Session(_transcript.value, force = true)
            } else {
                enterL3FallbackMode(showAlert = true)
            }
        } else {
            _effectiveMode.value = newSelectedMode
            _isFallbackActive.value = false
        }
    }

    private suspend fun analyzeTranscriptIncrementally(currentFullText: String) {
        if (_selectedMode.value == AnalysisMode.GEMINI_API &&
            _isFallbackActive.value &&
            _networkAvailable.value
        ) {
            tryRecoverL3Session(currentFullText, force = false)
        }

        when (_effectiveMode.value) {
            AnalysisMode.GEMINI_API -> analyzeWithL3(currentFullText)
            AnalysisMode.NORMAL,
            AnalysisMode.GDetection -> analyzeWithLocalMode(currentFullText, _effectiveMode.value)
        }
    }

    private suspend fun analyzeWithL3(currentFullText: String) {
        val newResult = analysisCoordinator.analyzeIncrementalL3(currentFullText) ?: return
        if (newResult.isError) {
            enterL3FallbackMode(showAlert = true)
            analyzeWithLocalMode(currentFullText, AnalysisMode.GDetection)
            return
        }

        publishAnalysisResult(newResult)
        Log.d(TAG, "L3 incremental update: ${newResult.overallRiskLevel}")
    }

    private suspend fun analyzeWithLocalMode(
        currentFullText: String,
        mode: AnalysisMode
    ) {
        if (currentFullText.length <= analysisCoordinator.getProcessedTextLength(mode)) {
            return
        }

        val newResult = analysisCoordinator.analyzeIncremental(currentFullText, mode)
        publishAnalysisResult(newResult)
    }

    private suspend fun publishAnalysisResult(result: AnalysisResult) {
        withContext(Dispatchers.Main) {
            if (result.analysisLevel is AnalysisLevel.L3) {
                _analysisResult.value = result
            } else {
                val currentResult = _analysisResult.value
                val combinedRiskLevel = maxOf(currentResult.overallRiskLevel, result.overallRiskLevel)
                val combinedMatches = (currentResult.matches + result.matches).distinct()
                val combinedReason = if (result.overallRiskLevel >= currentResult.overallRiskLevel) {
                    result.reason
                } else {
                    currentResult.reason
                }

                _analysisResult.value = AnalysisResult(
                    overallRiskLevel = combinedRiskLevel,
                    matches = combinedMatches,
                    reason = combinedReason,
                    analysisLevel = result.analysisLevel,
                    alertEnabled = result.alertEnabled
                )
            }

            updateAlert(_analysisResult.value)
        }
    }

    private suspend fun tryRecoverL3Session(
        currentFullText: String,
        force: Boolean
    ) {
        if (_selectedMode.value != AnalysisMode.GEMINI_API || !_networkAvailable.value) {
            return
        }

        val now = System.currentTimeMillis()
        if (!force && now - lastL3RecoveryAttemptAt < L3_RECOVERY_RETRY_MS) {
            return
        }
        lastL3RecoveryAttemptAt = now

        val replayStart = (currentFullText.length - L3_REPLAY_WINDOW_CHARS).coerceAtLeast(0)
        analysisCoordinator.createL3Session(initialProcessedTextLength = replayStart)
        _effectiveMode.value = AnalysisMode.GEMINI_API
        _isFallbackActive.value = false

        val warmupResult = if (currentFullText.isBlank()) {
            null
        } else {
            analysisCoordinator.analyzeIncrementalL3(currentFullText)
        }

        if (warmupResult?.isError == true) {
            enterL3FallbackMode(showAlert = !hasShownFallbackAlertForCurrentOutage)
            return
        }

        hasShownFallbackAlertForCurrentOutage = false
        warmupResult?.let { publishAnalysisResult(it) }
    }

    private suspend fun enterL3FallbackMode(showAlert: Boolean) {
        val enteringFallback = !_isFallbackActive.value || _effectiveMode.value != AnalysisMode.GDetection
        analysisCoordinator.closeL3Session()
        if (enteringFallback) {
            analysisCoordinator.resetMode(AnalysisMode.GDetection)
        }

        _effectiveMode.value = AnalysisMode.GDetection
        _isFallbackActive.value = true
        lastL3RecoveryAttemptAt = System.currentTimeMillis()

        if (showAlert && !hasShownFallbackAlertForCurrentOutage) {
            hasShownFallbackAlertForCurrentOutage = true
            withContext(Dispatchers.Main) {
                _currentAlert.value = AlertInfo(
                    RiskLevel.YELLOW,
                    "Mất kết nối mạng. Hệ thống tạm chuyển sang L2 để duy trì bảo vệ."
                )
            }
        }
    }

    private fun extractCategory(reason: String): String {
        return reason.removePrefix("Tình huống: ").trim()
    }

    private fun updateAlert(result: AnalysisResult) {
        if (!result.alertEnabled) return
        
        val newLevel = result.overallRiskLevel
        val newReason = result.reason ?: return
        val analysisLevel = result.analysisLevel
        
        Log.d(TAG, "updateAlert: analysisLevel=$analysisLevel, riskLevel=$newLevel, reason=$newReason")

        if (newLevel < RiskLevel.ORANGE) return

        val queuedAlert = QueuedAlert(
            info = AlertInfo(newLevel, newReason),
            analysisLevel = analysisLevel,
            timestamp = System.currentTimeMillis()
        )

        when (analysisLevel) {
            is AnalysisLevel.L1 -> {
                val l1Reason = newReason
                val isDuplicate = synchronized(l1AlertQueue) { l1AlertQueue.any { it.info.reason == l1Reason } }
                    || currentAlertHistory.any { it.analysisLevel == "L1" && it.displayedReason == l1Reason }
                
                if (isDuplicate) {
                    Log.d(TAG, "⊘ Skipping duplicate L1 alert: $l1Reason")
                    return
                }

                if (!hasShownFirstL1Alert) {
                    hasShownFirstL1Alert = true
                    _currentAlert.value = queuedAlert.info
                    Log.i(TAG, "✓ L1 FIRST ALERT sent immediately: $newReason")
                    
                    val entry = AlertHistoryEntry(
                        timestamp = System.currentTimeMillis(),
                        analysisLevel = AnalysisLevel.L1.toString(),
                        riskLevel = newLevel.name,
                        alertCount = 1,
                        displayedReason = newReason,
                        allReasons = null
                    )
                    currentAlertHistory.add(entry)
                } else {
                    synchronized(l1AlertQueue) {
                        l1AlertQueue.add(queuedAlert)
                        l1LastQueueTime = System.currentTimeMillis()
                        val queueSize = l1AlertQueue.size
                        Log.d(TAG, "Added to L1 queue. Total: $queueSize")
                        
                        if (queueSize >= 5) {
                            Log.i(TAG, "⚡ L1 batch triggered by COUNT (>= 5 warnings)")
                            viewModelScope.launch {
                                processL1Batch()
                            }
                        }
                    }
                }
            }
            is AnalysisLevel.L2, is AnalysisLevel.L2AI, is AnalysisLevel.L2Fused -> {

                if (analysisLevel is AnalysisLevel.L2AI) {
                    val reasonCategory = extractCategory(newReason)
                    val isAIDuplicate = currentAlertHistory.any { it.analysisLevel == "L2-AI" && extractCategory(it.displayedReason) == reasonCategory }
                    if (isAIDuplicate) {
                        Log.d(TAG, "⊘ Skipping duplicate L2-AI alert: $reasonCategory")
                        return
                    }

                    Log.i(TAG, "🤖 [L2-AI] Luồng 1 phân tích thành công. Đẩy kết quả trực tiếp ra màn hình!")
                    _currentAlert.value = queuedAlert.info
                    
                    val entry = AlertHistoryEntry(
                        timestamp = System.currentTimeMillis(),
                        analysisLevel = AnalysisLevel.L2AI.toString(),
                        riskLevel = newLevel.name,
                        alertCount = 1,
                        displayedReason = newReason,
                        allReasons = null
                    )
                    currentAlertHistory.add(entry)
                    return
                }

                val reasonCategory = extractCategory(newReason)
                
                val isDuplicate = synchronized(l2AlertQueue) {
                    l2AlertQueue.any { extractCategory(it.info.reason) == reasonCategory }
                } || currentAlertHistory.any { it.analysisLevel.startsWith("L2") && extractCategory(it.displayedReason) == reasonCategory }
                
                if (isDuplicate) {
                    Log.d(TAG, "⊘ Skipping duplicate L2 alert: $reasonCategory")
                    return
                }

                if (!hasShownFirstL2Alert && (analysisLevel is AnalysisLevel.L2 || analysisLevel is AnalysisLevel.L2Fused)) {
                     hasShownFirstL2Alert = true
                     _currentAlert.value = queuedAlert.info
                     Log.i(TAG, "✓ L2 FIRST ALERT sent immediately: $newReason")
                     
                     val entry = AlertHistoryEntry(
                         timestamp = System.currentTimeMillis(),
                         analysisLevel = analysisLevel.toString(),
                         riskLevel = newLevel.name,
                         alertCount = 1,
                         displayedReason = newReason,
                         allReasons = null
                     )
                     currentAlertHistory.add(entry)
                     return
                }
                
                synchronized(l2AlertQueue) {
                    l2AlertQueue.add(queuedAlert)
                    l2LastQueueTime = System.currentTimeMillis()
                    val queueSize = l2AlertQueue.size
                    Log.d(TAG, "Added to L2 queue. Total: $queueSize")
                    
                    if (queueSize >= 5) {
                        Log.i(TAG, "⚡ L2 batch triggered by COUNT (>= 5 warnings)")
                        viewModelScope.launch {
                            processL2Batch()
                        }
                    }
                }
            }
            is AnalysisLevel.L3 -> {
                _currentAlert.value = queuedAlert.info
                Log.i(TAG, "✓ L3 alert displayed immediately: $newReason")
                
                val entry = AlertHistoryEntry(
                    timestamp = System.currentTimeMillis(),
                    analysisLevel = AnalysisLevel.L3.toString(),
                    riskLevel = newLevel.name,
                    alertCount = 1,
                    displayedReason = newReason,
                    allReasons = null
                )
                currentAlertHistory.add(entry)
            }
        }
    }

    private fun startL1BatchTimer() {
        l1BatchJob?.cancel()
        l1BatchJob = viewModelScope.launch {
            while (true) {
                delay(5000L)
                processL1Batch()
            }
        }
        Log.d(TAG, "L1 batch timer started (5s interval)")
    }

    private fun startL2BatchTimer() {
        l2BatchJob?.cancel()
        l2BatchJob = viewModelScope.launch {
            while (true) {
                delay(10000L)
                processL2Batch()
            }
        }
        Log.d(TAG, "L2 batch timer started (10s interval)")
    }

    private suspend fun processL1Batch() {
        try {
            synchronized(l1AlertQueue) {
                if (l1AlertQueue.isEmpty()) return
            }

            val topAlert = synchronized(l1AlertQueue) {
                l1AlertQueue.maxByOrNull { it.info.level }
            }
            
            topAlert?.let { alert ->
                val queueSnapshot = synchronized(l1AlertQueue) { l1AlertQueue.toList() }
                val summary = buildBatchSummary("L1", queueSnapshot)
                Log.i(TAG, "⏰ Processing L1 batch (TIME trigger): $summary")
                
                try {
                    val queueSize = synchronized(l1AlertQueue) { l1AlertQueue.size }
                    val allReasons = synchronized(l1AlertQueue) {
                        l1AlertQueue.map { it.info.reason }.distinct()
                    }
                    
                    val entry = AlertHistoryEntry(
                        timestamp = System.currentTimeMillis(),
                        analysisLevel = AnalysisLevel.L1.toString(),
                        riskLevel = alert.info.level.name,
                        alertCount = queueSize,
                        displayedReason = alert.info.reason,
                        allReasons = allReasons
                    )
                    currentAlertHistory.add(entry)
                } catch (e: Exception) {
                    Log.e(TAG, "Failed to save L1 alert to history", e)
                }
                
                withContext(Dispatchers.Main) {
                    _currentAlert.value = alert.info
                    delay(3000)
                    if (_currentAlert.value == alert.info) {
                        _currentAlert.value = null
                    }
                }
            }
        } catch (e: Exception) {
            Log.e(TAG, "Error processing L1 batch", e)
        } finally {
            synchronized(l1AlertQueue) {
                l1AlertQueue.clear()
            }
            Log.d(TAG, "✓ L1 queue cleared")
        }
    }

    private suspend fun processL2Batch() {
        try {
            synchronized(l2AlertQueue) {
                if (l2AlertQueue.isEmpty()) return
            }

            val topAlert = synchronized(l2AlertQueue) {
                l2AlertQueue.maxByOrNull { it.info.level }
            }
            
            topAlert?.let { alert ->
                val queueSnapshot = synchronized(l2AlertQueue) { l2AlertQueue.toList() }
                val summary = buildBatchSummary("L2", queueSnapshot)
                Log.i(TAG, "⏰ Processing L2 batch (TIME trigger): $summary")
                
                try {
                    val queueSize = synchronized(l2AlertQueue) { l2AlertQueue.size }
                    val allReasons = synchronized(l2AlertQueue) {
                        l2AlertQueue.map { it.info.reason }.distinct()
                    }
                    
                    val entry = AlertHistoryEntry(
                        timestamp = System.currentTimeMillis(),
                        analysisLevel = AnalysisLevel.L2.toString(),
                        riskLevel = alert.info.level.name,
                        alertCount = queueSize,
                        displayedReason = alert.info.reason,
                        allReasons = allReasons
                    )
                    currentAlertHistory.add(entry)
                } catch (e: Exception) {
                    Log.e(TAG, "Failed to save L2 alert to history", e)
                }
                
                withContext(Dispatchers.Main) {
                    _currentAlert.value = alert.info
                    delay(3000)
                    if (_currentAlert.value == alert.info) {
                        _currentAlert.value = null
                    }
                }
            }
        } catch (e: Exception) {
            Log.e(TAG, "Error processing L2 batch", e)
        } finally {
            synchronized(l2AlertQueue) {
                l2AlertQueue.clear()
            }
            Log.d(TAG, "✓ L2 queue cleared")
        }
    }

    private fun buildBatchSummary(level: String, batch: List<QueuedAlert>): String {
        val count = batch.size
        val highestLevel = batch.maxByOrNull { it.info.level }?.info?.level
        val reasons = batch.map { it.info.reason }.distinct().take(3)
        val keywords = reasons.joinToString(" | ")
        
        return "[$level] Count: $count, Highest: $highestLevel, Top reasons: $keywords"
    }

    fun onDismissAlert() {
        _currentAlert.value = null
        Log.d(TAG, "Alert dismissed by user")
    }

    private fun startWaveformCollection() {
        waveformJob?.cancel()
        waveformJob = viewModelScope.launch {
            while (true) {
                val isCreatorMode = DeveloperModeManager.isDevModeActive() &&
                    CreatorAudioCaptureManager.state.value == CreatorAudioCaptureManager.CaptureState.CAPTURING
                val db = if (isSimulationMode) (30..60).random().toFloat()
                         else if (isCreatorMode) speechToTextManager.rmsDbFlow.value // Creator dùng amplitude riêng
                         else speechToTextManager.rmsDbFlow.value
                val normalized = (db / 15f + 0.1f).coerceIn(0f, 1f)
                _amplitudes.add(normalized)
                if (_amplitudes.size > WAVEFORM_SIZE) _amplitudes.removeAt(0)
                delay(100)
            }
        }
    }

    /** Cập nhật waveform từ Creator amplitude (được gọi từ amplitudeFlow collector) */
    private fun updateAmplitudes(amp: Float) {
        val normalized = (amp / 15f + 0.1f).coerceIn(0f, 1f)
        _amplitudes.add(normalized)
        if (_amplitudes.size > WAVEFORM_SIZE) _amplitudes.removeAt(0)
    }

    fun startListening() {
        resetState()
        isSimulationMode = false

        startL1BatchTimer()
        startL2BatchTimer()

        _currentSettings.value?.let { settings ->
            _selectedMode.value = settings.analysisMode
            refreshRuntimeState(settings.analysisMode)
        }
        
        _currentSettings.value?.let { settings ->
            if (_effectiveMode.value == AnalysisMode.GEMINI_API) {
                analysisCoordinator.createL3Session()
                Log.d(TAG, "✓ Created L3 chat session")
            }
        }

        _currentSettings.value?.let {
            if (it.audioBoost) {
                val audioManager = application.getSystemService(Context.AUDIO_SERVICE) as AudioManager
                originalVoiceCallVolume = audioManager.getStreamVolume(AudioManager.STREAM_VOICE_CALL)
                val maxVolume = audioManager.getStreamMaxVolume(AudioManager.STREAM_VOICE_CALL)
                audioManager.setStreamVolume(AudioManager.STREAM_VOICE_CALL, maxVolume, 0)
            }
        }

        speechToTextManager.startListening()

    }

    fun loadAndStartSimulation(context: Context, title: String) {
        viewModelScope.launch(Dispatchers.IO) {
            try {
                context.assets.open("situation_test.json").bufferedReader().use { reader ->
                    val type = object : TypeToken<List<SimulationScenarioData>>() {}.type
                    val loaded = Gson().fromJson<List<SimulationScenarioData>>(reader, type) ?: emptyList()
                    val scenario = loaded.find { it.title == title }
                    if (scenario != null) {
                        withContext(Dispatchers.Main) {
                            startSimulation(scenario)
                        }
                    }
                }
            } catch (e: Exception) {
                e.printStackTrace()
            }
        }
    }

    private fun startSimulation(scenario: SimulationScenarioData) {
        resetState()
        isSimulationMode = true
        _isListeningInternal.value = true
        
        _currentSettings.value?.let { currentSettings ->
            Log.d(TAG, "✓ Simulation started with mode: ${currentSettings.analysisMode}")
        }
        
        startL1BatchTimer()
        startL2BatchTimer()
        
        _currentSettings.value?.let { settings ->
            if (_effectiveMode.value == AnalysisMode.GEMINI_API) {
                analysisCoordinator.createL3Session()
                Log.d(TAG, "✓ Created L3 chat session for simulation")
            }
        }
        
        startTimer()
        startWaveformCollection()

        simulationJob = viewModelScope.launch {
            var lastTime = 0L
            scenario.script.forEach { step ->
                val waitTime = step.timestamp - lastTime
                if (waitTime > 0) delay(waitTime)
                
                val newLine = "[${step.speaker}]: ${step.line}"
                _transcript.value = if (_transcript.value.isBlank()) newLine else "${_transcript.value}\n$newLine"
                
                lastTime = step.timestamp
            }
            
            delay(6000)
            
            stopListeningAndSave(application)
        }
    }

    private fun resetState() {
        isStopping = false
        speechToTextManager.clearTranscript()
        analysisCoordinator.reset()
        
        l1BatchJob?.cancel()
        l2BatchJob?.cancel()
        
        hasShownFirstL1Alert = false
        hasShownFirstL2Alert = false
        l1LastQueueTime = 0L
        l2LastQueueTime = 0L
        
        synchronized(l1AlertQueue) { l1AlertQueue.clear() }
        synchronized(l2AlertQueue) { l2AlertQueue.clear() }
        currentAlertHistory.clear()
        
        _transcript.value = ""
        _analysisResult.value = AnalysisResult(RiskLevel.GREEN, emptyList())
        _elapsedTime.value = 0L
        _currentAlert.value = null
        _isListeningInternal.value = false
        simulationJob?.cancel()
        
        originalSettingsBeforeSimulation = null
        originalSettingsBeforeFallback = null
        hasShownFallbackAlertForCurrentOutage = false
        lastL3RecoveryAttemptAt = 0L
        refreshRuntimeState(_currentSettings.value?.analysisMode ?: AnalysisMode.GDetection)
    }

    private fun startTimer() {
        timerJob?.cancel()
        timerJob = viewModelScope.launch {
            while (true) {
                delay(1000)
                _elapsedTime.value++
            }
        }
    }

    fun stopListeningAndSave(context: Context) {
        if (isStopping) return
        isStopping = true

        if (isSimulationMode) {
            simulationJob?.cancel()
            
            originalSettingsBeforeSimulation?.let { originalSettings ->
                _currentSettings.value = originalSettings
                Log.d(TAG, "✓ Simulation ended: Restored original settings (${originalSettings.analysisMode})")
            }
            originalSettingsBeforeSimulation = null
        } else {
            stopCreatorCapture()
            speechToTextManager.stopListening()
            
            originalSettingsBeforeFallback?.let { originalSettings ->
                _currentSettings.value = originalSettings
                Log.d(TAG, "✓ Fallback ended: Restored original settings (${originalSettings.analysisMode})")
            }
            originalSettingsBeforeFallback = null
        }
        
        _isListeningInternal.value = false
        timerJob?.cancel()
        waveformJob?.cancel()
        
        analysisCoordinator.closeL3Session(resetProgress = true)
        Log.d(TAG, "Closed L3 session")

        if (originalVoiceCallVolume != -1) {
            (application.getSystemService(Context.AUDIO_SERVICE) as AudioManager).setStreamVolume(AudioManager.STREAM_VOICE_CALL, originalVoiceCallVolume, 0)
            originalVoiceCallVolume = -1
        }

        viewModelScope.launch {
            val settings = _currentSettings.value ?: return@launch
            val activeModeAtStop = _effectiveMode.value
            var historyId: Long
            try {
                withContext(Dispatchers.IO) {
                    val finalTranscript = _transcript.value
                    val storedTranscript = TranscriptSaver.prepareTranscriptForLocalStorage(finalTranscript)
                    
                    val existingResult = _analysisResult.value
                    
                    val audioPath = TranscriptSaver.saveTranscript(context, storedTranscript)
                    val analysisType = when (settings.analysisMode) {
                        AnalysisMode.NORMAL -> application.getString(R.string.analysis_mode_fast)
                        AnalysisMode.GDetection -> application.getString(R.string.analysis_mode_deep)
                        AnalysisMode.GEMINI_API -> existingResult.modelName ?: application.getString(R.string.analysis_mode_ai)
                    }

                    val newHistory = CallHistory(
                        id = 0,
                        dateTime = SimpleDateFormat("HH:mm:ss dd/MM/yyyy", Locale.getDefault()).format(Date()),
                        riskLevel = existingResult.overallRiskLevel.name,
                        summary = existingResult.reason ?: application.getString(R.string.status_analysis_complete),
                        duration = "${_elapsedTime.value}s",
                        flagCount = existingResult.matches.size,
                        transcript = storedTranscript,
                        audioPath = audioPath,
                        analysisResult = null,
                        analysisType = if (isSimulationMode) application.getString(R.string.simulation_prefix, analysisType) else analysisType,
                        alertHistory = CallHistory.alertHistoryToJson(currentAlertHistory)
                    )
                    Log.d(TAG, "Saving call history with ${currentAlertHistory.size} alert entries")
                    historyId = callHistoryDao.insert(newHistory)
                }
                
                _navigationEvent.emit(historyId)
                
                withContext(Dispatchers.IO) {
                    val finalTranscript = _transcript.value
                    val processedLen = analysisCoordinator.getProcessedTextLength(activeModeAtStop)
                    val segmentToAnalyze = if (finalTranscript.length > processedLen) {
                        finalTranscript.substring(processedLen)
                    } else ""
                    
                    if (segmentToAnalyze.isNotBlank()) {
                        try {
                            val finalResult = analysisCoordinator.analyze(segmentToAnalyze, activeModeAtStop)
                            val existingResult = _analysisResult.value
                            
                            val combinedResult = AnalysisResult(
                                overallRiskLevel = maxOf(existingResult.overallRiskLevel, finalResult.overallRiskLevel),
                                matches = (existingResult.matches + finalResult.matches).distinct(),
                                reason = if (finalResult.overallRiskLevel >= existingResult.overallRiskLevel) 
                                    finalResult.reason else existingResult.reason,
                                analysisLevel = finalResult.analysisLevel,
                                alertEnabled = finalResult.alertEnabled
                            )
                            
                            val updated = callHistoryDao.getByIdSync(historyId)?.copy(
                                riskLevel = combinedResult.overallRiskLevel.name,
                                summary = combinedResult.reason ?: "",
                                flagCount = combinedResult.matches.size
                            )
                            updated?.let { callHistoryDao.update(it) }
                            
                            Log.d("MonitoringViewModel", "Background analysis completed and updated")
                        } catch (e: Exception) {
                            Log.w("MonitoringViewModel", "Background analysis failed, using preliminary result", e)
                        }
                    }
                }
                
            } catch (e: Exception) {
                Log.e("MonitoringViewModel", "Failed to save history", e)
                _navigationEvent.emit(-1L)
            }
        }
    }

    override fun onCleared() {
        super.onCleared()
        connectivityMonitor.stop()
        supervisorJob.cancel()
        l1BatchJob?.cancel()
        l2BatchJob?.cancel()
        
        analysisCoordinator.closeL3Session(resetProgress = true)
        
        if (originalVoiceCallVolume != -1) {
            (application.getSystemService(Context.AUDIO_SERVICE) as AudioManager).setStreamVolume(AudioManager.STREAM_VOICE_CALL, originalVoiceCallVolume, 0)
        }
        speechToTextManager.destroy()
    }

    fun setMediaProjection(projection: MediaProjection?) {
        if (!DeveloperModeManager.isDevModeActive()) {
            Log.w(TAG, "[Creator] setMediaProjection called outside Developer Mode. Ignored.")
            return
        }
        creatorMediaProjection = projection
        Log.d(TAG, "[Creator] MediaProjection token received: ${if (projection != null) "OK" else "null"}")
    }

    private fun stopCreatorCapture() {
        creatorAmplitudeJob?.cancel()
        creatorTextJob?.cancel()
        CreatorAudioCaptureManager.stopCapture()
        creatorMediaProjection = null
        val intent = android.content.Intent(application, com.example.lachancuocgoi.services.CreatorMediaProjectionService::class.java).apply {
            action = com.example.lachancuocgoi.services.CreatorMediaProjectionService.ACTION_STOP
        }
        application.startService(intent)
        Log.d(TAG, "[Creator] Capture stopped and resources released.")
    }

}

class MonitoringViewModelFactory(private val application: Application, private val callHistoryDao: CallHistoryDao) : ViewModelProvider.Factory {
    override fun <T : ViewModel> create(modelClass: Class<T>): T {
        if (modelClass.isAssignableFrom(MonitoringViewModel::class.java)) {
            @Suppress("UNCHECKED_CAST")
            return MonitoringViewModel(application, callHistoryDao) as T
        }
        throw IllegalArgumentException("Unknown ViewModel class")
    }
}
