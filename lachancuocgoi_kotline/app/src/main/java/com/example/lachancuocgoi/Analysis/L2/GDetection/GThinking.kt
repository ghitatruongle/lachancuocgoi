package com.example.lachancuocgoi.Analysis.L2.GDetection

import com.example.lachancuocgoi.Analysis.KeywordMatch
import com.example.lachancuocgoi.Analysis.common.TextNormalizer
import com.example.lachancuocgoi.RiskLevel

/**
 * (NÂNG CẤP - Data Optimization + Externalized Tiers) GThinking tận dụng tối đa thông tin từ scenario
 * (group, level) để đưa ra kết luận chính xác hơn.
 *
 * TIER data giờ được load từ tier_config.json thay vì hardcode.
 */
object GThinking {

    // === TIERED RISK SYSTEM DATA — loaded from tier_config.json ===
    private var TIER1_TOPICS = emptySet<String>()
    private var TIER2_URGENCY = emptySet<String>()
    private var TIER3_PII = emptySet<String>()

    /**
     * Load tier config from external JSON data.
     * Phải được gọi trong GDetectionEngine.initialize() trước khi analyze().
     */
    fun loadTierConfig(tier1: Set<String>, tier2: Set<String>, tier3: Set<String>) {
        // [FIX] Normalize all tier entries to match the no-diacritic tokens stored in KeywordMatch.
        // kw.keyword is the originalKeyword from the Trie, which was built via GFlash.tokenize()
        // → lowercase + phonetic map + strip NFD diacritics. Tier entries must match that form.
        fun normalize(s: String) = TextNormalizer.normalize(s, applySlang = false, noiseMode = TextNormalizer.NoiseMode.SPACE)
        TIER1_TOPICS = tier1.map { normalize(it) }.toSet()
        TIER2_URGENCY = tier2.map { normalize(it) }.toSet()
        TIER3_PII    = tier3.map { normalize(it) }.toSet()
        android.util.Log.i("GThinking",
            "✓ Tier config loaded (normalized): T1=${TIER1_TOPICS.size}, T2=${TIER2_URGENCY.size}, T3=${TIER3_PII.size}")
    }

    fun isTierConfigLoaded(): Boolean =
        TIER1_TOPICS.isNotEmpty() || TIER2_URGENCY.isNotEmpty() || TIER3_PII.isNotEmpty()

    /**
     * Kiểm tra xem token có chứa target như một từ riêng biệt (whole-word matching).
     * Ví dụ: "ngân hàng" khớp trong "ngân hàng" nhưng KHÔNG khớp trong "ngân hàngmới mở".
     */
    private fun matchesWholeWord(token: String, target: String): Boolean {
        if (target.isEmpty()) return false
        val idx = token.indexOf(target)
        if (idx < 0) return false
        // Kiểm tra biên trái: bắt đầu chuỗi HOẶC trước đó là khoảng trắng
        val leftBoundary = idx == 0 || token[idx - 1].isWhitespace()
        // Kiểm tra biên phải: kết thúc chuỗi HOẶC sau đó là khoảng trắng
        val rightBoundary = idx + target.length == token.length || token[idx + target.length].isWhitespace()
        return leftBoundary && rightBoundary
    }

    /**
     * Phân tích và đưa ra kết quả cuối cùng.
     */
    fun analyze(
        allMatchedKeywords: Set<KeywordMatch>,
        matchedPatterns: List<MatchedPattern> = emptyList(),
        topTopic: String?,
        contextScore: Float = 0f,
        scenarioMatch: ScenarioMatch? = null,
        sentenceMatch: SentenceMatch? = null,
        config: ScoringConfig = ScoringConfig()
    ): GResult {

        // 0. FAST TRACK: Sentence Match (Ưu tiên cao nhất - vẫn giữ nguyên)
        if (sentenceMatch != null && !sentenceMatch.isSafe) {
             val level = RiskLevel.fromInt(sentenceMatch.level)
             return GResult(
                 riskLevel = level,
                 reason = "Phát hiện câu thoại nguy hiểm: '${sentenceMatch.sentence}'",
                 allMatchedKeywords = allMatchedKeywords,
                 sentenceMatch = sentenceMatch,
                 confirmedSituation = topTopic,
                 matchedPatterns = matchedPatterns,
                 riskScore = RiskScore(1f, 1f, 1f, 1f, sentenceScore = 1f, finalScore = 1f),
                 alertEnabled = true
             )
        }
        if (sentenceMatch != null && sentenceMatch.isSafe) {
             return GResult(
                 riskLevel = RiskLevel.GREEN,
                 reason = "Phát hiện nội dung an toàn: '${sentenceMatch.sentence}'",
                 allMatchedKeywords = allMatchedKeywords,
                 sentenceMatch = sentenceMatch,
                 riskScore = RiskScore(0f, 0f, 0f, 0f, sentenceScore = -1f, finalScore = 0f),
                 alertEnabled = false
             )
        }

        // === TIERED RISK LOGIC (Hệ thống phân cấp) ===
        // 1. Detect Tiers matches (WHOLE-WORD: Token phải chứa target như một từ riêng biệt)
        val tier3Matches = allMatchedKeywords.filter { kw ->
            // [FIX] kw.keyword is already normalized (no diacritics), tier entries are now also normalized
            val token = kw.keyword.lowercase()
            TIER3_PII.any { pii -> matchesWholeWord(token, pii) }
        }

        val tier2Matches = allMatchedKeywords.filter { kw ->
            val token = kw.keyword.lowercase()
            TIER2_URGENCY.any { urgent -> matchesWholeWord(token, urgent) }
        }

        val tier1Matches = allMatchedKeywords.filter { kw ->
            val token = kw.keyword.lowercase()
            TIER1_TOPICS.any { topic -> matchesWholeWord(token, topic) }
        }

        val hasTier3 = tier3Matches.isNotEmpty()
        val hasTier2 = tier2Matches.isNotEmpty()
        val hasTier1 = tier1Matches.isNotEmpty()
        val tier1Count = tier1Matches.size
        val tier2Count = tier2Matches.size
        val baseHighestKeywordRisk = allMatchedKeywords.maxByOrNull { it.level.ordinal }?.level ?: RiskLevel.GREEN
        val totalPatternScore = matchedPatterns.sumOf { it.score.toDouble() }.toFloat().coerceAtMost(1.0f)
        val strongestPatternScore = matchedPatterns.maxOfOrNull { it.score } ?: 0f

        // 2. Determine Tier-based Risk Level
        var tieredLevel = RiskLevel.GREEN
        var tieredReason = ""

        if (hasTier3) {
            tieredLevel = RiskLevel.RED
            tieredReason = "CẢNH BÁO: Yêu cầu thông tin nhạy cảm / Lệnh chuyển tiền (Tầng 3)"
        } else if (hasTier1 && hasTier2 && tier1Count >= 2 && tier2Count >= 2) {
            // [FIX-2] High-confidence RED: TIER1≥2 + TIER2≥2 — không cần OTP
            // Ví dụ: CEO fraud, sextortion, tín dụng đen, đầu tư lừa đảo
            tieredLevel = RiskLevel.RED
            tieredReason = "CẢNH BÁO: Kịch bản lừa đảo điển hình (${tier1Count} chủ đề + ${tier2Count} ép buộc)"
        } else if (hasTier1 && hasTier2) {
            tieredLevel = RiskLevel.ORANGE
            tieredReason = "Cảnh báo: Chủ đề nhạy cảm + Thúc ép (Tầng 2)"
        } else if (hasTier1 && contextScore >= 0.3f) {
            // [B2] Context-aware tier escalation: keywords gần nhau ở đầu cuộc gọi
            tieredLevel = RiskLevel.ORANGE
            tieredReason = "Cảnh báo: Tập trung từ khóa nhạy cảm ở đầu cuộc gọi"
        } else if (hasTier1) {
            tieredLevel = RiskLevel.YELLOW
            tieredReason = "Chú ý: Đang nhắc đến chủ đề nhạy cảm (Tầng 1)"
        }

        // 3. Scenario Logic (Existing but downgraded priority if explicit tiers are present)
        val SCENARIO_ALERT_THRESHOLD = config.scenario_alert_threshold
        val hasGoodScenarioMatch = scenarioMatch != null && scenarioMatch.similarityScore >= SCENARIO_ALERT_THRESHOLD
        
        var finalLevel = tieredLevel
        var finalReason = tieredReason

        // logic combine: Max(Tiered, Scenario) but reflect user preference
        if (hasGoodScenarioMatch) {
            val scenarioLevel = RiskLevel.fromInt(scenarioMatch!!.level)
            
            // "Kịch bản" detected something high risk (e.g. Red/Orange)
            if (scenarioLevel.ordinal > finalLevel.ordinal) {
                // Kiểm tra loại kịch bản dễ nhận diện sai (False Positive)
                val isCharity = scenarioMatch.group == "CHARITY_DONATION" || scenarioMatch.situationName.lowercase().contains("chữ thập đỏ")
                
                if (isCharity && !hasTier2 && !hasTier3) {
                    // Nếu là hội thoại từ thiện bình thường (không có yếu tố đe dọa, giục giã, lấy thông tin)
                    // Hạn chế tăng level quá cao, giới hạn ở YELLOW
                    finalLevel = maxOf(finalLevel, RiskLevel.YELLOW)
                    finalReason = "Chú ý: Có nhắc đến quyên góp/từ thiện"
                } else {
                    // Các tình huống lừa đảo đặc thù khác (ví dụ: bưu phẩm, công an) -> Override luôn
                    finalLevel = scenarioLevel
                    finalReason = "Tình huống: ${scenarioMatch.situationName}"
                }
            }
        }

        if (matchedPatterns.isNotEmpty()) {
            val patternLevel = when {
                strongestPatternScore >= 0.75f -> RiskLevel.RED
                strongestPatternScore >= 0.45f && baseHighestKeywordRisk.ordinal >= RiskLevel.ORANGE.ordinal -> RiskLevel.RED
                totalPatternScore >= 0.5f -> RiskLevel.ORANGE
                strongestPatternScore >= 0.3f -> RiskLevel.YELLOW
                else -> RiskLevel.GREEN
            }

            if (patternLevel.ordinal > finalLevel.ordinal) {
                finalLevel = patternLevel
                finalReason = "Phát hiện mẫu câu rủi ro: ${matchedPatterns.first().patternId}"
            }
        }
        
        // FORCE RED if Tier 3 is present
        if (hasTier3) {
            finalLevel = RiskLevel.RED
            finalReason = "CẢNH BÁO: Yêu cầu thông tin nhạy cảm (${tier3Matches.joinToString { it.keyword }})"
        }

        // [FIX-2] FORCE RED from high-confidence TIER1+TIER2 combo
        if (hasTier1 && hasTier2 && tier1Count >= 2 && tier2Count >= 2 && finalLevel.ordinal < RiskLevel.RED.ordinal) {
            finalLevel = RiskLevel.RED
            finalReason = "CẢNH BÁO: Kịch bản lừa đảo điển hình xác nhận (${tier1Count}T1 + ${tier2Count}T2)"
        }

        // [NEW - Phase 3.1] FORCE RED if Tier1 present + ScenarioMatcher returned RED level
        // Solves: Giả danh Công an scenario that only hits 1 Tier2 keyword
        // but has strong scenario match with risk_level=3
        if (hasTier1 && hasGoodScenarioMatch && scenarioMatch!!.level >= 3 && finalLevel.ordinal < RiskLevel.RED.ordinal) {
            finalLevel = RiskLevel.RED
            finalReason = "CẢNH BÁO: Kịch bản nguy hiểm xác nhận — ${scenarioMatch.situationName}"
        }

        // 4. UPDATE KEYWORDS FOR UI HIGHLIGHTING
        // We must upgrade the level of specific keywords that triggered the tiers
        val updatedKeywords = allMatchedKeywords.map { kw ->
            var newLevel = kw.level
            
            if (tier3Matches.contains(kw) && finalLevel == RiskLevel.RED) {
                newLevel = RiskLevel.RED
            } else if (tier2Matches.contains(kw) && finalLevel.ordinal >= RiskLevel.ORANGE.ordinal) {
                if (newLevel.ordinal < RiskLevel.ORANGE.ordinal) newLevel = RiskLevel.ORANGE
            } else if (tier1Matches.contains(kw) && finalLevel.ordinal >= RiskLevel.YELLOW.ordinal) {
                if (newLevel.ordinal < RiskLevel.YELLOW.ordinal) newLevel = RiskLevel.YELLOW
            }
            
            if (newLevel != kw.level) kw.copy(level = newLevel) else kw
        }.toSet()

        // Calculate scores for UI/Debugging
        val highestKeywordRisk = updatedKeywords.maxByOrNull { it.level.ordinal }?.level ?: RiskLevel.GREEN
        val keywordScoreRaw = when (highestKeywordRisk) {
                RiskLevel.RED -> 1.0f
                RiskLevel.ORANGE -> 0.7f
                RiskLevel.YELLOW -> 0.4f
                else -> 0.0f
        }
        val keywordFinalScore = keywordScoreRaw

        // Weighted sum thay vì maxOf() — phản ánh sự cộng gộp rủi ro
        val topicScoreValue = if (topTopic != null) 1.0f else 0.0f
        val scenarioScoreValue = scenarioMatch?.similarityScore ?: 0f
        val w = config.weights
        val weightedFinalScore = (
            w.keyword * keywordFinalScore +
            w.topic * topicScoreValue +
            w.pattern * totalPatternScore +
            w.scenario * scenarioScoreValue +
            w.context * contextScore
        ).coerceAtMost(1.0f)

        // RETURN RESULT
        return GResult(
            riskLevel = finalLevel,
            reason = finalReason.ifEmpty { "Không phát hiện dấu hiệu rủi ro" },
            allMatchedKeywords = updatedKeywords, // Use the updated set with correct highlighting colors
            confirmedSituation = if (hasGoodScenarioMatch) scenarioMatch?.situationName else (if (hasTier1) "Chủ đề nhạy cảm" else null),
            matchedPatterns = matchedPatterns,
            mostLikelyScenario = scenarioMatch,
            sentenceMatch = sentenceMatch,
            riskScore = RiskScore(
                keywordScore = keywordFinalScore,
                topicScore = topicScoreValue,
                patternScore = totalPatternScore,
                scenarioScore = scenarioScoreValue,
                contextScore = contextScore,
                finalScore = weightedFinalScore
            ),
            alertEnabled = finalLevel != RiskLevel.GREEN  // Alert if Yellow/Orange/Red
        )
    }

}
