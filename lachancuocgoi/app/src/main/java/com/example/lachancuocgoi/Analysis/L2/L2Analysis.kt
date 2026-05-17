package com.example.lachancuocgoi.Analysis.L2

import com.example.lachancuocgoi.Analysis.AnalysisLevel
import com.example.lachancuocgoi.Analysis.Analyzer
import com.example.lachancuocgoi.Analysis.AnalysisResult
import com.example.lachancuocgoi.Analysis.HealthReport
import com.example.lachancuocgoi.Analysis.HealthStatus
import com.example.lachancuocgoi.Analysis.KeywordMatch
import com.example.lachancuocgoi.Analysis.L2.GDetection.GDetectionEngine
import com.example.lachancuocgoi.Analysis.L2.WFSA.ScamGraphBuilder
import com.example.lachancuocgoi.Analysis.L2.WFSA.WfsaEngine
import com.example.lachancuocgoi.Analysis.L2.Intent.TFLiteIntentClassifier
import com.example.lachancuocgoi.Analysis.L2.Intent.IntentPrediction
import com.example.lachancuocgoi.Analysis.L2.Intent.getDisplayName
import com.example.lachancuocgoi.Analysis.L2.Intent.getDescription
import com.example.lachancuocgoi.Analysis.L2.Intent.getRiskLevel
import com.example.lachancuocgoi.Analysis.L2.Intent.ScamIntent
import com.example.lachancuocgoi.Analysis.L2.Safety.SafetyFilter
import com.example.lachancuocgoi.RiskLevel
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.async
import kotlinx.coroutines.coroutineScope
import kotlinx.coroutines.withContext

class L2Analyzer(
    private val gDetectionEngine: GDetectionEngine,
    private val intentClassifier: TFLiteIntentClassifier
) : Analyzer {

    override val level = AnalysisLevel.L2

    // WFSA Engine cho nhận diện kịch bản lừa đảo theo ngữ cảnh độc lập
    private val wfsaEngine = WfsaEngine(ScamGraphBuilder.buildDefaultGraphs())

    // Session state tự quản lý
    private var processedTextLength = 0
    private var lastResult: AnalysisResult = AnalysisResult(RiskLevel.GREEN, emptyList(), analysisLevel = AnalysisLevel.L2)

    /**
     * Khởi tạo các engine của L2
     */
    /**
     * (SỬA BUG 4) Giờ là suspend function để đợi GDetectionEngine.initialize() hoàn tất.
     */
    override suspend fun initialize() {
        gDetectionEngine.initialize()
        intentClassifier.initialize()
    }

    override fun isReady(): Boolean {
        return gDetectionEngine.isEngineReady()
    }

    fun isFullyReady(): Boolean {
        return gDetectionEngine.isEngineReady() && intentClassifier.isReady()
    }

    fun isIntentClassifierReady(): Boolean {
        return intentClassifier.isReady()
    }

    override fun healthCheck(): HealthReport {
        val gdReady = gDetectionEngine.isEngineReady()
        val icReady = intentClassifier.isReady()

        return when {
            !gdReady -> HealthReport(
                HealthStatus.DOWN,
                "L2",
                "GDetectionEngine chưa sẵn sàng. Keywords/patterns có thể chưa load."
            )
            !icReady -> HealthReport(
                HealthStatus.DEGRADED,
                "L2",
                "GDetection OK nhưng IntentClassifier (TFLite) chưa sẵn sàng. Chỉ Luồng 2 hoạt động."
            )
            else -> HealthReport(
                HealthStatus.HEALTHY,
                "L2",
                "GDetection + IntentClassifier đều sẵn sàng. Cả 2 luồng hoạt động."
            )
        }
    }

    /**
     * (SỬA BUG 3) Reset tất cả trạng thái phiên, bao gồm cả cờ tắt Luồng 1.
     * Trước đây isLuong1Disabled không được reset → AI bị tắt vĩnh viễn sau 1 lần lỗi.
     */
    override fun resetSession() {
        wfsaEngine.resetSession()
        processedTextLength = 0
        lastResult = AnalysisResult(RiskLevel.GREEN, emptyList(), analysisLevel = AnalysisLevel.L2)
    }

    override fun getProcessedTextLength(): Int = processedTextLength

    override fun syncProcessedTextLength(length: Int) {
        processedTextLength = length.coerceAtLeast(0)
    }

    override fun getLastResult(): AnalysisResult = lastResult

    /**
     * Sealed class thay thế magic string "10101_TRIGGERED" — Type-safe Luồng 1 result.
     */
    private sealed class Luong1Result {
        data class Success(
            val prediction: IntentPrediction,
            val confidenceMargin: Float
        ) : Luong1Result()
        object Fallback : Luong1Result()
    }

    suspend fun analyze(incrementalText: String, fullText: String): AnalysisResult = coroutineScope {
        if (!isReady() || fullText.isBlank()) {
            val emptyResult = AnalysisResult(RiskLevel.GREEN, emptyList(), analysisLevel = AnalysisLevel.L2)
            lastResult = emptyResult
            return@coroutineScope emptyResult
        }

        // LUỒNG 1: DÙNG AI (MobileBERT)
        val luong1Deferred = async(Dispatchers.Default) {
             if (!intentClassifier.isReady()) {
                 Luong1Result.Fallback
             } else try {
                 val intentPredictions = intentClassifier.predictIntent(fullText)
                 val topIntent = intentPredictions.maxByOrNull { it.confidence }
                 val secondIntent = intentPredictions
                     .filter { it != topIntent }
                     .maxByOrNull { it.confidence }
                 val confidenceMargin = if (topIntent != null) {
                     topIntent.confidence - (secondIntent?.confidence ?: 0f)
                 } else {
                     0f
                 }
                 val isAiConfident = topIntent != null &&
                     topIntent.confidence >= AI_ASSIST_CONFIDENCE &&
                     confidenceMargin >= AI_ASSIST_MARGIN
                 
                 if (isAiConfident) {
                     Luong1Result.Success(topIntent!!, confidenceMargin)
                 } else {
                     Luong1Result.Fallback
                 }
             } catch (e: Exception) {
                 // Lỗi tạm thời (vd: OOM), vẫn tiếp tục sử dụng luồng 2 và thử lại AI vào lượt sau
                 Luong1Result.Fallback
             }
        }

        // LUỒNG 2: DÙNG GDetection & WFSA
        // GDetection chạy song song với Luồng 1 (không phụ thuộc BERT)
        val gDetectionDeferred = async(Dispatchers.Default) {
            gDetectionEngine.performFullAnalysis(fullText)
        }

        // Chờ cả 2 kết quả
        val luong1Result = luong1Deferred.await()
        val gResult = gDetectionDeferred.await()
        
        // Trích xuất intent predictions từ Luồng 1 để truyền cho WFSA
        val intentForWfsa = when (luong1Result) {
            is Luong1Result.Success -> listOf(luong1Result.prediction)
            is Luong1Result.Fallback -> emptyList()
        }

        // WFSA + SafetyFilter chạy sau khi có cả GDetection result và BERT intent
        val parsedGDetectionResult = L2ResultParser.parse(gResult)

        // FIX: Giờ WFSA nhận được BERT predictions thực tế thay vì luôn emptyList()
        var wfsaScore = wfsaEngine.analyzeSegment(incrementalText, intentForWfsa)
        val safetyDiscount = SafetyFilter.calculateSafetyDiscount(fullText)
        wfsaScore *= safetyDiscount
        
        val wfsaRiskLevel = when {
            wfsaScore >= 50.0 -> RiskLevel.RED
            wfsaScore >= 20.0 -> RiskLevel.YELLOW
            else -> RiskLevel.GREEN
        }

        val gDetectionRiskLevel = if (safetyDiscount < 1.0 && parsedGDetectionResult.overallRiskLevel != RiskLevel.RED && parsedGDetectionResult.overallRiskLevel != RiskLevel.ORANGE) {
            if (safetyDiscount <= 0.5 && parsedGDetectionResult.overallRiskLevel == RiskLevel.YELLOW) {
                RiskLevel.GREEN
            } else {
                parsedGDetectionResult.overallRiskLevel
            }
        } else {
            parsedGDetectionResult.overallRiskLevel
        }

        val finalRiskLevel: RiskLevel
        val finalReason: String?
        
        if (wfsaRiskLevel > gDetectionRiskLevel) {
            finalRiskLevel = wfsaRiskLevel
            finalReason = if (wfsaScore >= 50.0) "Cảnh báo L2 nghiêm trọng (Theo ngữ cảnh)" else "Cảnh báo L2: Có phát hiện dấu hiệu lừa đảo"
        } else {
            finalRiskLevel = gDetectionRiskLevel
            finalReason = parsedGDetectionResult.reason
        }
        
        val result2 = AnalysisResult(
            overallRiskLevel = finalRiskLevel,
            matches = parsedGDetectionResult.matches,
            reason = finalReason,
            analysisLevel = AnalysisLevel.L2,
            alertEnabled = parsedGDetectionResult.alertEnabled || wfsaRiskLevel > RiskLevel.GREEN
        )

        when (luong1Result) {
            is Luong1Result.Success -> {
                // Luồng 1 (AI) thành công
                val topIntent = luong1Result.prediction
                val intentLabel = topIntent.intent.getDisplayName()
                val intentRisk = topIntent.intent.getRiskLevel(topIntent.confidence)
                val isSafeIntent = topIntent.intent == ScamIntent.SAFE || intentRisk == RiskLevel.GREEN
                val isAiDirectWinner = !isSafeIntent &&
                    topIntent.confidence >= AI_DIRECT_CONFIDENCE &&
                    luong1Result.confidenceMargin >= AI_DIRECT_MARGIN
                val shouldFuseWithContext = !isSafeIntent &&
                    result2.overallRiskLevel >= RiskLevel.YELLOW &&
                    topIntent.confidence >= AI_ASSIST_CONFIDENCE &&
                    luong1Result.confidenceMargin >= AI_ASSIST_MARGIN
                
                val matches = mutableListOf(KeywordMatch(
                    keyword = intentLabel,
                    level = intentRisk,
                    category = "Luồng 1 (AI) Độ tin cậy: ${(topIntent.confidence * 100).toInt()}% | Margin: ${(luong1Result.confidenceMargin * 100).toInt()}%"
                ))

                // [A3] CROSS-VALIDATION: Nếu AI nói SAFE nhưng GDetection phát hiện RED
                // hoặc confirmed scam topic → KHÔNG tin AI blind, dùng kết quả GDetection
                val gDetectionOverride = isSafeIntent && (
                    result2.overallRiskLevel >= RiskLevel.RED ||
                    result2.matches.any { it.category == "Chủ đề Lừa đảo" }
                )
                if (gDetectionOverride) {
                    val overrideMatches = result2.matches.toMutableList()
                    overrideMatches.add(0, KeywordMatch(
                        "AI nói an toàn nhưng GDetection phát hiện rủi ro",
                        result2.overallRiskLevel,
                        "Cross-validation Override"
                    ))
                    val res = AnalysisResult(
                        overallRiskLevel = result2.overallRiskLevel,
                        matches = overrideMatches,
                        reason = result2.reason ?: "GDetection override: Phát hiện rủi ro dù AI không nhận ra",
                        analysisLevel = AnalysisLevel.L2Fused,
                        alertEnabled = result2.alertEnabled
                    )
                    processedTextLength = fullText.length
                    lastResult = res
                    return@coroutineScope res
                }
                // ─── [A4] HIGH-CONFIDENCE FAST PATH ──────────────────────────────────
                // Khi GhitaV3 trả về kết quả với độ tin cậy ≥ 80% → ưu tiên AI ngay lập tức
                // Không cần kiểm tra margin vì 80% là ngưỡng rất cao — model chắc chắn
                val isAiHighConfidence = !isSafeIntent &&
                    topIntent.confidence >= AI_HIGH_CONFIDENCE_THRESHOLD

                if (isAiHighConfidence) {
                    val alertName = intentLabel.uppercase()
                    val alertDesc = topIntent.intent.getDescription().uppercase()
                    val highConfMatches = mutableListOf(
                        KeywordMatch(
                            keyword = alertName,
                            level = intentRisk,
                            category = "AI ≥ 80% — Độ tin cậy: ${(topIntent.confidence * 100).toInt()}%"
                        )
                    )
                    if (result2.matches.isNotEmpty()) {
                        highConfMatches.addAll(result2.matches)
                    }
                    val res = AnalysisResult(
                        overallRiskLevel = maxOf(intentRisk, result2.overallRiskLevel),
                        matches = highConfMatches.distinct(),
                        reason = "⚠️ $alertName — $alertDesc",
                        analysisLevel = AnalysisLevel.L2AI,
                        alertEnabled = intentRisk != RiskLevel.GREEN
                    )
                    processedTextLength = fullText.length
                    lastResult = res
                    return@coroutineScope res
                }



                if (isAiDirectWinner) {
                    val res = AnalysisResult(
                        overallRiskLevel = intentRisk,
                        matches = matches,
                        reason = "⚠️ $intentLabel — ${topIntent.intent.getDescription()}",
                        analysisLevel = AnalysisLevel.L2AI,
                        alertEnabled = intentRisk != RiskLevel.GREEN
                    )
                    processedTextLength = fullText.length
                    lastResult = res
                    return@coroutineScope res
                }

                if (shouldFuseWithContext) {
                    val ensembleConfidence = if (result2.confidence > 0) {
                        (topIntent.confidence * 0.6f + result2.confidence * 0.4f).coerceAtMost(1.0f)
                    } else {
                        topIntent.confidence
                    }
                    val res = AnalysisResult(
                        overallRiskLevel = maxOf(intentRisk, result2.overallRiskLevel),
                        matches = (matches + result2.matches).distinct(),
                        reason = "⚠️ $intentLabel — ${topIntent.intent.getDescription()}",
                        analysisLevel = AnalysisLevel.L2Fused,
                        alertEnabled = result2.alertEnabled || intentRisk != RiskLevel.GREEN,
                        confidence = ensembleConfidence
                    )
                    processedTextLength = fullText.length
                    lastResult = res
                    return@coroutineScope res
                }

                processedTextLength = fullText.length
                    lastResult = result2
                    return@coroutineScope result2
            }
            is Luong1Result.Fallback -> {
                // NHÁNH 2 LUÔN CHẠY KHI LUỒNG 1 LỖI HOẶC KHÔNG ĐỦ TỰ TIN
                val matches = result2.matches.toMutableList()
                
                // [D2] Thêm WFSA active scenario info
                val wfsaInfo = wfsaEngine.activeScenarioName
                val wfsaStage = wfsaEngine.activeScenarioStage
                val fallbackLabel = if (wfsaInfo != null && wfsaStage != null) {
                    "Luồng 2 — Theo dõi: $wfsaInfo (Giai đoạn $wfsaStage/4)"
                } else {
                    "Sử dụng Luồng 2 (GDetection & WFSA)"
                }

                matches.add(0, KeywordMatch(fallbackLabel, RiskLevel.GREEN, "Analysis Fallback"))
                val res = AnalysisResult(
                    overallRiskLevel = result2.overallRiskLevel,
                    matches = matches,
                    reason = result2.reason ?: "Cảnh báo ngữ cảnh (Luồng 2)",
                    analysisLevel = AnalysisLevel.L2,
                    alertEnabled = result2.alertEnabled
                )
                processedTextLength = fullText.length
                lastResult = res
                return@coroutineScope res
            }
        }
    }

    companion object {
        // Ngưỡng 1: AI ≥ 80% → ưu tiên tối cao, bỏ qua margin check
        private const val AI_HIGH_CONFIDENCE_THRESHOLD = 0.80f
        // Ngưỡng 2: AI ≥ 62% và margin ≥ 15% → AI direct winner
        private const val AI_DIRECT_CONFIDENCE = 0.62f
        private const val AI_DIRECT_MARGIN = 0.15f
        // Ngưỡng 3: AI ≥ 50% và margin ≥ 8% → Fuse với GDetection context
        private const val AI_ASSIST_CONFIDENCE = 0.5f
        private const val AI_ASSIST_MARGIN = 0.08f
    }
}
