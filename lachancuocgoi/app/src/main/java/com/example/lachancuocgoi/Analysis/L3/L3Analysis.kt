package com.example.lachancuocgoi.Analysis.L3

import android.content.Context
import android.util.Log
import com.example.lachancuocgoi.Analysis.AnalysisLevel
import com.example.lachancuocgoi.Analysis.Analyzer
import com.example.lachancuocgoi.Analysis.AnalysisResult
import com.example.lachancuocgoi.Analysis.HealthReport
import com.example.lachancuocgoi.Analysis.HealthStatus
import com.example.lachancuocgoi.Analysis.KeywordMatch
import com.example.lachancuocgoi.Analysis.L3.core.*
import com.example.lachancuocgoi.R
import com.example.lachancuocgoi.RiskLevel
import com.google.gson.Gson
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.withContext

class L3Analyzer(private val context: Context) : Analyzer {

    override val level = AnalysisLevel.L3
    
    // Shared instances — tránh tạo mới mỗi lần gọi
    private val apiKeyProvider = BuildConfigApiKeyProvider()
    private val keyHealthTracker = KeyHealthTracker(apiKeyProvider)
    
    // L3 health tracking
    private var lastErrorTime = 0L
    private var consecutiveErrors = 0

    override fun healthCheck(): HealthReport {
        val hasApiKey = try {
            apiKeyProvider.getApiKeys().isNotEmpty()
        } catch (_: Exception) { false }

        val keyHealth = keyHealthTracker.getHealthSummary()
        val activeCount = keyHealth.count { it.status == KeyHealthTracker.KeyStatus.ACTIVE }
        val cooldownCount = keyHealth.count { it.status == KeyHealthTracker.KeyStatus.COOLDOWN }
        val exhaustedCount = keyHealth.count { it.status == KeyHealthTracker.KeyStatus.EXHAUSTED }
        val totalKeys = keyHealth.size

        val isRecentError = System.currentTimeMillis() - lastErrorTime < 60_000L

        return when {
            !hasApiKey -> HealthReport(
                HealthStatus.DOWN,
                "L3",
                "API key không hợp lệ hoặc chưa cấu hình."
            )
            exhaustedCount == totalKeys -> HealthReport(
                HealthStatus.DOWN,
                "L3",
                "Tất cả $totalKeys keys đều INVALID/REVOKED. Cần thay thế API keys."
            )
            activeCount == 0 && cooldownCount > 0 -> HealthReport(
                HealthStatus.DEGRADED,
                "L3",
                "$cooldownCount/$totalKeys keys hết quota (cooldown đến 00:00). $exhaustedCount keys invalid."
            )
            consecutiveErrors >= 3 -> HealthReport(
                HealthStatus.DEGRADED,
                "L3",
                "$consecutiveErrors lỗi liên tiếp. $activeCount/$totalKeys keys ACTIVE."
            )
            isRecentError -> HealthReport(
                HealthStatus.DEGRADED,
                "L3",
                "Gần đây có lỗi (consecutiveErrors=$consecutiveErrors). $activeCount/$totalKeys keys ACTIVE."
            )
            else -> HealthReport(
                HealthStatus.HEALTHY,
                "L3",
                "$activeCount/$totalKeys keys ACTIVE, $cooldownCount cooldown, $exhaustedCount invalid."
            )
        }
    }

    companion object {
        private const val TAG = "L3Analyzer"
        private const val MIN_WORDS = 3  // Minimum words for analysis
        
        // Smart Buffering Constants (GĐ4)
        private const val MIN_INCREMENTAL_CHARS = 40  // Chờ ít nhất 40 ký tự để có ngữ cảnh
        private const val MAX_INCREMENTAL_CHARS = 200 // Ép buộc gửi đi nếu dài quá 200 ký tự (tránh chờ quá lâu)
    }
    
    // ============ Session-based analysis (NEW) ============
    private var activeSession: GeminiChatSession? = null
    private var processedTextLength = 0  // Track what we've already sent to API
    private var maxRiskLevel: RiskLevel = RiskLevel.GREEN  // Maintain maximum risk level in session
    private var consecutiveGreenCount = 0  // Risk Decay: Đếm số lần liên tiếp GREEN để cho phép de-escalation

    // ============ One-shot analysis (Existing - backward compatible) ============
    private val geminiClient = GeminiClient(
        apiKeyProvider = apiKeyProvider,
        config = GeminiConfig.forAnalysis(),
        keyHealthTracker = keyHealthTracker,
        onAllKeysExhausted = {
            Log.e(TAG, "All keys exhausted — triggering L3 fallback")
        }
    )
    
    // Response cache để giảm API calls (chỉ dùng cho one-shot analysis)
    private val cache = ResponseCache<AnalysisResult>()
    
    private val gson = Gson()
    
    // ============ PUBLIC API ============
    
    /**
     * Phân tích văn bản để phát hiện lừa đảo qua cuộc gọi.
     * 
     * @param text Nội dung cuộc gọi cần phân tích
     * @return AnalysisResult với risk level, keywords, và lý do
     * 
     * Note: For real-time monitoring, use createSession() + analyzeIncremental() instead.
     */
    suspend fun analyze(text: String): AnalysisResult = withContext(Dispatchers.IO) {
        // Validation
        val validationError = validateInput(text)
        if (validationError != null) {
            return@withContext validationError
        }
        
        // Check cache first (no risk level hint needed for get, uses dynamic TTL)
        cache.get(text)?.let { cachedResult ->
            GeminiMetrics.recordCacheHit()
            Log.d(TAG, "Cache hit for text: ${text.take(50)}...")
            return@withContext cachedResult
        }
        
        // --- GĐ1: PII Redaction (Ẩn danh dữ liệu cục bộ) ---
        val (redactedText, piiMap) = PIIStripper.redactPII(text)
        
        // Cache miss - query Gemini using redacted text
        val prompt = createPrompt(redactedText)
        
        // Query Gemini thông qua unified client
        val result = geminiClient.query(prompt) { responseText, modelName ->
            // Khôi phục PII nếu AI có trích dẫn lại (để hiển thị đúng trên UI)
            val restoredResponseText = PIIStripper.restorePII(responseText, piiMap)
            parseResponse(restoredResponseText, modelName)
        }
        
        // Handle result and cache if successful
        return@withContext result.fold(
            onSuccess = { analysisResult ->
                cache.put(text, analysisResult, analysisResult.overallRiskLevel)
                consecutiveErrors = 0
                analysisResult
            },
            onFailure = { error ->
                Log.w(TAG, "Analysis failed: ${error.javaClass.simpleName} - ${error.message}")
                consecutiveErrors++
                lastErrorTime = System.currentTimeMillis()
                AnalysisResult(
                    RiskLevel.GREEN,
                    emptyList(),
                    reason = "API Error: ${error.localizedMessage}",
                    analysisLevel = AnalysisLevel.L3,
                    isError = true
                )
            }
        )
    }
    
    // ============ SESSION-BASED INCREMENTAL ANALYSIS (NEW) ============
    
    /**
     * Tạo chat session mới cho một cuộc gọi.
     * Call này khi bắt đầu monitoring.
     */
    fun createSession(initialProcessedTextLength: Int = 0) {
        activeSession?.close()
        activeSession = GeminiChatSession(
            apiKeyProvider = apiKeyProvider,
            config = GeminiConfig.forAnalysis(),
            keyHealthTracker = keyHealthTracker
        )
        processedTextLength = initialProcessedTextLength.coerceAtLeast(0)
        maxRiskLevel = RiskLevel.GREEN
        consecutiveGreenCount = 0
        Log.i(TAG, "Created new L3 chat session")
    }
    
    /**
     * Phân tích incremental - gửi chỉ phần text mới.
     * 
     * @param fullText Toàn bộ transcript hiện tại
     * @return AnalysisResult hoặc null nếu chưa đủ text mới để gửi
     */
    suspend fun analyzeIncremental(fullText: String): AnalysisResult? = withContext(Dispatchers.IO) {
        val session = activeSession
        if (session == null) {
            Log.e(TAG, "No active session. Call createSession() first.")
            return@withContext null
        }
        
        // Check if we have enough new text using Smart Buffering (GĐ4)
        val newTextLength = fullText.length - processedTextLength
        val newText = fullText.substring(processedTextLength)
        
        val isBoundary = isSentenceBoundary(newText)
        
        // Chưa đủ độ dài tối thiểu -> Tiếp tục buffer
        if (newTextLength < MIN_INCREMENTAL_CHARS) {
            return@withContext null
        }
        
        // Đã đủ độ dài tối thiểu, nhưng chưa hết câu VÀ chưa vượt ngưỡng tối đa -> Tiếp tục buffer
        if (!isBoundary && newTextLength < MAX_INCREMENTAL_CHARS) {
            Log.d(TAG, "Smart Buffering: Waiting for sentence boundary... (Length: $newTextLength)")
            return@withContext null
        }
        
        Log.d(TAG, "Analyzing incremental: ${newText.length} new chars. Boundary reached: $isBoundary")
        
        // --- GĐ1: PII Redaction ---
        val (redactedNewText, piiMap) = PIIStripper.redactPII(newText)
        
        // Create incremental prompt
        val isFirstMessage = processedTextLength == 0
        val prompt = PromptBuilder.buildIncrementalPrompt(redactedNewText, isFirstMessage)
        
        // Send to session
        val result = session.sendMessage(prompt) { responseText, modelName ->
            // Khôi phục PII nếu AI có trích dẫn lại
            val restoredResponseText = PIIStripper.restorePII(responseText, piiMap)
            parseResponse(restoredResponseText, modelName)
        }
        
        return@withContext result.fold(
            onSuccess = { analysisResult ->
                // Update processed length
                processedTextLength = fullText.length
                consecutiveErrors = 0  // Reset error counter on success
                Log.d(TAG, "✓ Incremental analysis successful. Processed: $processedTextLength chars")
                analysisResult
            },
            onFailure = { error ->
                Log.w(TAG, "Incremental analysis failed: ${error.javaClass.simpleName} - ${error.message}")
                consecutiveErrors++
                lastErrorTime = System.currentTimeMillis()
                // Don't update processedTextLength - retry next time
                AnalysisResult(
                    RiskLevel.GREEN,
                    emptyList(),
                    context.getString(R.string.error_l3_analysis, error.message),
                    analysisLevel = AnalysisLevel.L3,
                    isError = true
                )
            }
        )
    }
    
    /**
     * Đóng chat session hiện tại.
     * Call khi kết thúc cuộc gọi.
     */
    fun closeSession() {
        activeSession?.close()
        activeSession = null
        processedTextLength = 0
        maxRiskLevel = RiskLevel.GREEN
        consecutiveGreenCount = 0
        Log.i(TAG, "Closed L3 chat session")
    }

    override fun getProcessedTextLength(): Int = processedTextLength

    override fun syncProcessedTextLength(length: Int) {
        processedTextLength = length.coerceAtLeast(0)
    }

    override fun getLastResult(): AnalysisResult {
        // L3 doesn't cache lastResult internally; return default GREEN
        return AnalysisResult(RiskLevel.GREEN, emptyList(), analysisLevel = AnalysisLevel.L3)
    }

    override suspend fun initialize() {
        // L3 uses lazy init — no explicit initialization needed
        // API key is checked on first use
    }

    override fun isReady(): Boolean {
        return try {
            apiKeyProvider.getApiKeys().isNotEmpty() && keyHealthTracker.hasActiveKeys()
        } catch (_: Exception) { false }
    }

    override fun resetSession() {
        closeSession()
    }
    
    /**
     * Lấy metrics snapshot để monitoring.
     */
    fun getMetrics(): MetricsSnapshot {
        return GeminiMetrics.getSnapshot()
    }
    
    // ============ PRIVATE HELPERS ============
    
    /**
     * Kiểm tra ranh giới câu — cải tiến cho STT engines (thường không thêm dấu câu).
     * Nhận diện cả filler words/ending particles phổ biến trong tiếng Việt.
     */
    private fun isSentenceBoundary(text: String): Boolean {
        val trimmed = text.trimEnd()
        if (trimmed.isEmpty()) return false
        val lastChar = trimmed.last()
        
        // 1. Dấu ngắt câu chuẩn
        if (lastChar in listOf('.', '?', '!', '\n', ';', ':') || trimmed.endsWith("...")) return true
        
        // 2. Vietnamese ending particles (STT không thêm dấu câu nhưng có filler words)
        val lowerTrimmed = trimmed.lowercase()
        val endsWithParticle = lowerTrimmed.endsWith(" à") || lowerTrimmed.endsWith(" ạ")
            || lowerTrimmed.endsWith(" nhé") || lowerTrimmed.endsWith(" nha")
            || lowerTrimmed.endsWith(" vậy") || lowerTrimmed.endsWith(" rồi")
            || lowerTrimmed.endsWith(" đi") || lowerTrimmed.endsWith(" nhỉ")
            || lowerTrimmed.endsWith(" hen") || lowerTrimmed.endsWith(" nghe")
        
        // 3. Pause markers (một số STT dùng double space cho khoảng dừng)
        val hasPauseMarker = trimmed.contains("  ")
        
        return endsWithParticle || hasPauseMarker
    }
    
    /**
     * Validate input text.
     * @return AnalysisResult with error if invalid, null if valid
     */
    private fun validateInput(text: String): AnalysisResult? {
        val trimmed = text.trim()
        
        if (trimmed.isEmpty()) {
            return AnalysisResult(RiskLevel.GREEN, emptyList(), context.getString(R.string.error_text_empty), analysisLevel = AnalysisLevel.L3)
        }
        
        val wordCount = trimmed.split(Regex("\\s+")).size
        if (wordCount < MIN_WORDS) {
            return AnalysisResult(
                RiskLevel.GREEN, 
                emptyList(), 
                context.getString(R.string.error_text_too_short, MIN_WORDS),
                analysisLevel = AnalysisLevel.L3
            )
        }
        
        return null  // Valid
    }
    
    /**
     * Tạo prompt cho Gemini AI.
     * Sử dụng enhanced prompt với examples từ PromptBuilder.
     */
    private fun createPrompt(text: String): String {
        return PromptBuilder.buildAnalysisPrompt(text)
    }
    
    /**
     * Parse response từ Gemini AI.
     * Sử dụng regex để extract JSON vì AI có thể thêm text xung quanh.
     */
    private fun parseResponse(responseText: String, modelName: String): AnalysisResult {
        if (responseText.isBlank()) {
            throw Exception("Response is blank")
        }

        // Extract JSON từ response
        val jsonMatch = Regex("""\{.*\}""", RegexOption.DOT_MATCHES_ALL)
            .find(responseText)
        val jsonString = jsonMatch?.value ?: responseText

        return try {
            val response = gson.fromJson(jsonString, AnalysisResponse::class.java)

            // Parse level string thành RiskLevel enum
            val riskLevel = when (response.level?.lowercase()?.trim()) {
                "red" -> RiskLevel.RED
                "orange" -> RiskLevel.ORANGE
                "yellow" -> RiskLevel.YELLOW
                "green" -> RiskLevel.GREEN
                else -> {
                    // Response validation: thử extract level từ reason nếu AI trả level không hợp lệ
                    val inferredFromReason = inferLevelFromReason(response.reason)
                    if (inferredFromReason != RiskLevel.GREEN) {
                        Log.w(TAG, "Unknown level '${response.level}', inferred ${inferredFromReason} from reason")
                    } else {
                        Log.w(TAG, "Unknown level '${response.level}', defaulting to GREEN")
                    }
                    inferredFromReason
                }
            }

            // Risk Decay: Cho phép de-escalation thay vì monotonic increase
            // Nếu nhiều lần liên tiếp GREEN → dần giảm maxRiskLevel
            var finalRiskLevel = riskLevel
            if (riskLevel == RiskLevel.GREEN) {
                consecutiveGreenCount++
                if (consecutiveGreenCount >= 3 && maxRiskLevel.ordinal > RiskLevel.GREEN.ordinal) {
                    // De-escalate 1 bậc sau 3 lần GREEN liên tiếp
                    maxRiskLevel = maxRiskLevel.deescalate()
                    consecutiveGreenCount = 0
                    Log.d(TAG, "Risk Decay: De-escalated maxRiskLevel to $maxRiskLevel")
                }
                finalRiskLevel = maxRiskLevel
            } else {
                consecutiveGreenCount = 0
                if (riskLevel.ordinal > maxRiskLevel.ordinal) {
                    maxRiskLevel = riskLevel
                }
            }

            // Tạo reason từ label và reason từ AI
            val reason = buildString {
                response.label?.takeIf { it.isNotBlank() }?.let { append("[$it] ") }
                response.reason?.let { append(it).append("\n") }
                response.recommendation?.let { append("Khuyến cáo: ").append(it) }
            }.trim().takeIf { it.isNotEmpty() } ?: context.getString(R.string.status_analysis_complete)

            // Tạo matches từ label nếu có
            val matches = response.label?.takeIf { it.isNotBlank() }?.let {
                listOf(KeywordMatch(it, finalRiskLevel, "L3 (Gemini)"))
            } ?: emptyList()

            AnalysisResult(
                overallRiskLevel = finalRiskLevel,
                matches = matches,
                reason = reason,
                analysisLevel = AnalysisLevel.L3,
                confidence = calculateL3Confidence(response),
                modelName = modelName
            )

        } catch (e: Exception) {
            Log.e(TAG, "JSON parse error. Raw: $responseText", e)
            throw Exception("Failed to parse Gemini response: ${e.message}")
        }
    }

    /**
     * Response validation: Thử suy luận risk level từ reason text khi AI trả level không hợp lệ.
     * Tìm các từ khóa rủi ro trong reason → ước lượng level.
     */
    private fun inferLevelFromReason(reason: String?): RiskLevel {
        if (reason.isNullOrBlank()) return RiskLevel.GREEN
        val lower = reason.lowercase()
        // RED indicators
        val redWords = listOf("lừa đảo", "chuyển tiền", "mã otp", "đe dọa", "khởi tố", "bắt cóc", "tống tiền")
        if (redWords.any { lower.contains(it) }) return RiskLevel.RED
        // ORANGE indicators
        val orangeWords = listOf("công an", "kiểm sát", "tài khoản", "mật khẩu", "cấp bách", "ngay lập tức", "ứng dụng")
        if (orangeWords.any { lower.contains(it) }) return RiskLevel.ORANGE
        // YELLOW indicators
        val yellowWords = listOf("đáng ngờ", "cẩn thận", "lưu ý", "chú ý", "không chắc", "có thể")
        if (yellowWords.any { lower.contains(it) }) return RiskLevel.YELLOW
        return RiskLevel.GREEN
    }

    /**
     * Tính confidence cho L3 dựa trên response completeness.
     * - Có level hợp lệ: +0.3
     * - Có reason: +0.3
     * - Có label: +0.2
     * - Có recommendation: +0.2
     * → Tối đa 1.0 nếu response đầy đủ
     */
    private fun calculateL3Confidence(response: AnalysisResponse): Float {
        var conf = 0f
        if (!response.level.isNullOrBlank() && response.level.lowercase() in listOf("green", "yellow", "orange", "red")) conf += 0.3f
        if (!response.reason.isNullOrBlank()) conf += 0.3f
        if (!response.label.isNullOrBlank()) conf += 0.2f
        if (!response.recommendation.isNullOrBlank()) conf += 0.2f
        return conf.coerceIn(0.0f, 1.0f)
    }
}
