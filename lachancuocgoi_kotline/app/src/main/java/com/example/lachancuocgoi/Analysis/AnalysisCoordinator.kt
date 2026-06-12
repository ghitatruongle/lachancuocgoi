package com.example.lachancuocgoi.Analysis

import android.content.Context
import com.example.lachancuocgoi.Analysis.L1.L1Analyzer
import com.example.lachancuocgoi.Analysis.L2.GDetection.GDetectionEngine
import com.example.lachancuocgoi.Analysis.L2.Intent.TFLiteIntentClassifier
import com.example.lachancuocgoi.Analysis.L2.L2Analyzer
import com.example.lachancuocgoi.Analysis.L3.L3Analyzer
import com.example.lachancuocgoi.R
import com.example.lachancuocgoi.RiskLevel
import com.example.lachancuocgoi.ui.HomePage.SettingsDialog.AnalysisMode

class AnalysisCoordinator(private val context: Context) {

    private val l1Analyzer = L1Analyzer(context)
    private val l2Analyzer = L2Analyzer(GDetectionEngine(context), TFLiteIntentClassifier(context))
    private val l3Analyzer = L3Analyzer(context)

    /** Lấy Analyzer cho mode tương ứng — dùng interface chung */
    private fun analyzerFor(mode: AnalysisMode): Analyzer = when (mode) {
        AnalysisMode.NORMAL -> l1Analyzer
        AnalysisMode.GDetection -> l2Analyzer
        AnalysisMode.GEMINI_API -> l3Analyzer
    }

    private var compatibilityMode = AnalysisMode.NORMAL

    suspend fun analyze(text: String, mode: AnalysisMode): AnalysisResult {
        compatibilityMode = mode
        return analyze(text, text, mode)
    }

    suspend fun analyze(
        incrementalText: String,
        fullText: String,
        mode: AnalysisMode
    ): AnalysisResult {
        compatibilityMode = mode
        if (mode == AnalysisMode.GDetection && !l2Analyzer.isReady()) {
            l2Analyzer.initialize()
            if (!l2Analyzer.isReady()) {
                return AnalysisResult(
                    RiskLevel.GREEN,
                    emptyList(),
                    reason = context.getString(R.string.status_ai_init),
                    analysisLevel = AnalysisLevel.L2
                )
            }
        }
        return when (mode) {
            AnalysisMode.NORMAL -> ChooseAnalysis.analyzeL1(fullText, l1Analyzer)
            AnalysisMode.GDetection -> ChooseAnalysis.analyzeL2(incrementalText, fullText, l2Analyzer)
            AnalysisMode.GEMINI_API -> ChooseAnalysis.analyzeL3(incrementalText, l3Analyzer)
        }
    }

    suspend fun analyzeIncremental(fullText: String, mode: AnalysisMode): AnalysisResult {
        compatibilityMode = mode
        val processedTextLength = getProcessedTextLength(mode)
        if (fullText.length <= processedTextLength) {
            return defaultResultFor(mode)
        }

        val deltaLength = fullText.length - processedTextLength
        val lastResult = getLastResult(mode)

        // Adaptive buffering cho L3: buffer ngắn hơn khi risk cao
        if (mode == AnalysisMode.GEMINI_API) {
            val minDelta = adaptiveMinDelta(lastResult.overallRiskLevel)
            if (deltaLength < minDelta) {
                return if (lastResult.overallRiskLevel.ordinal >= RiskLevel.ORANGE.ordinal) {
                    lastResult.copy(alertEnabled = false)
                } else {
                    lastResult
                }
            }
        }

        val textToAnalyze = fullText.substring(processedTextLength)
        return analyze(textToAnalyze, fullText, mode)
    }

    /**
     * Adaptive buffer: risk càng cao → buffer càng ngắn → phản hồi nhanh hơn.
     * GREEN/YELLOW: 50 chars (tiết kiệm API)
     * ORANGE: 30 chars (phản hồi nhanh hơn)
     * RED: 20 chars (gần như real-time)
     */
    private fun adaptiveMinDelta(currentRiskLevel: RiskLevel): Int = when (currentRiskLevel) {
        RiskLevel.RED -> MIN_DELTA_RED
        RiskLevel.ORANGE -> MIN_DELTA_ORANGE
        else -> MIN_DELTA_DEFAULT
    }

    fun reset() {
        AnalysisMode.values().forEach { resetMode(it) }
        compatibilityMode = AnalysisMode.NORMAL
    }

    fun resetMode(mode: AnalysisMode) {
        if (compatibilityMode == mode) {
            compatibilityMode = AnalysisMode.NORMAL
        }
        when (mode) {
            AnalysisMode.NORMAL -> l1Analyzer.resetSession()
            AnalysisMode.GDetection -> l2Analyzer.resetSession()
            AnalysisMode.GEMINI_API -> closeL3Session(resetProgress = true)
        }
    }

    fun getProcessedTextLength(mode: AnalysisMode): Int = analyzerFor(mode).getProcessedTextLength()

    fun getLastResult(mode: AnalysisMode): AnalysisResult {
        val result = analyzerFor(mode).getLastResult()
        return if (result.overallRiskLevel == RiskLevel.GREEN && result.matches.isEmpty() && mode == AnalysisMode.GEMINI_API) {
            defaultResultFor(mode)
        } else {
            result
        }
    }

    fun syncProcessedTextLength(mode: AnalysisMode, length: Int) {
        compatibilityMode = mode
        analyzerFor(mode).syncProcessedTextLength(length)
    }

    @Deprecated("Use the mode-aware overload")
    fun getProcessedTextLength(): Int = getProcessedTextLength(compatibilityMode)

    @Deprecated("Use the mode-aware overload")
    fun syncProcessedTextLength(length: Int) {
        syncProcessedTextLength(compatibilityMode, length)
    }

    fun createL3Session(initialProcessedTextLength: Int = 0) {
        compatibilityMode = AnalysisMode.GEMINI_API
        l3Analyzer.createSession(initialProcessedTextLength = initialProcessedTextLength.coerceAtLeast(0))
    }

    suspend fun analyzeIncrementalL3(fullText: String): AnalysisResult? {
        compatibilityMode = AnalysisMode.GEMINI_API
        return l3Analyzer.analyzeIncremental(fullText)
    }

    fun closeL3Session(resetProgress: Boolean = false) {
        l3Analyzer.closeSession()
    }

    /**
     * Chạy health check cho tất cả engines.
     * Trả về map engine → HealthReport.
     */
    fun runAllHealthChecks(): Map<String, HealthReport> {
        val analyzers: List<Analyzer> = listOf(l1Analyzer, l2Analyzer, l3Analyzer)
        return analyzers.associate { it.level.toString() to it.healthCheck() }
    }

    private fun defaultResultFor(mode: AnalysisMode): AnalysisResult {
        val level = when (mode) {
            AnalysisMode.NORMAL -> AnalysisLevel.L1
            AnalysisMode.GDetection -> AnalysisLevel.L2
            AnalysisMode.GEMINI_API -> AnalysisLevel.L3
        }
        return AnalysisResult(
            overallRiskLevel = RiskLevel.GREEN,
            matches = emptyList(),
            analysisLevel = level
        )
    }

    companion object {
        private const val MIN_DELTA_DEFAULT = 50  // GREEN/YELLOW: tiết kiệm API
        private const val MIN_DELTA_ORANGE = 30   // Phản hồi nhanh hơn khi nguy cơ lừa đảo
        private const val MIN_DELTA_RED = 20      // Gần real-time khi đã xác nhận lừa đảo
    }
}
