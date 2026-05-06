package com.example.lachancuocgoi.Analysis.L1

import android.util.Log
import com.example.lachancuocgoi.Analysis.AnalysisLevel
import com.example.lachancuocgoi.Analysis.AnalysisResult
import com.example.lachancuocgoi.Analysis.KeywordMatch
import com.example.lachancuocgoi.RiskLevel

object L1ResultParser {
    private const val TAG = "L1ResultParser"

    private val CRITICAL_KEYWORDS = setOf(
        "mã otp", "mã xác thực", "mã bảo mật", "otp", "ma otp",
        "mã số xác minh", "mã đăng nhập", "mã chuyển tiền",
        "số tài khoản", "số thẻ", "cvv", "cvc", "pin ngân hàng",
        "mật khẩu otp", "xác minh otp", "gửi mã", "nhận mã"
    )

    /**
     * Kiểm tra xem có chứa keyword nguy hiểm cần RED ngay lập tức
     */
    private fun containsCriticalKeyword(matches: Set<KeywordMatch>): Boolean {
        return matches.any { match ->
            CRITICAL_KEYWORDS.any { critical ->
                match.keyword.contains(critical, ignoreCase = true)
            }
        }
    }

    /**
     * P1 Weighted Scoring: score = max_level_ordinal × count_weight per category.
     * count_weight: 1 kw → 0.30 | 2 kw → 0.65 | 3 kw → 0.85 | 4+ kw → 1.00
     * Threshold: best_score < 1.00 → YELLOW | 1.00–1.99 → ORANGE | ≥ 2.00 → RED
     * Single Lv3 kw = 0.90 → YELLOW (reduces FP for common words like "tài khoản")
     * CRITICAL: Nếu chứa OTP/verification keywords → AUTO RED
     */
    fun parse(matches: Set<KeywordMatch>, totalTokens: Int = 0): AnalysisResult {
        Log.d(TAG, "Parsing matches: $matches")

        if (matches.isEmpty()) {
            val result = AnalysisResult(
                overallRiskLevel = RiskLevel.GREEN,
                matches = emptyList(),
                reason = "Không tìm thấy từ khóa rủi ro.",
                analysisLevel = AnalysisLevel.L1,
                alertEnabled = false,
                confidence = 0.9f  // GREEN khi không có match = rất tự tin
            )
            Log.d(TAG, "No matches found, returning: $result")
            return result
        }

        val matchedKeywords = matches.toList()

        // Nhóm theo category để tính weighted score
        val categoryGroups = matches.groupBy { it.category }

        // Category có >= 2 keywords = significant (đáng tin cậy hơn)
        val significantCategories = categoryGroups.filter { it.value.size >= 2 }

        // P1: Weighted scoring per category
        // score = max_level_ordinal * count_weight
        // count_weight: 1 kw → 0.30, 2 kw → 0.65, 3 kw → 0.85, 4+ kw → 1.00
        // Ngưỡng: score < 0.70 → YELLOW | 0.70–1.95 → ORANGE | ≥ 2.00 → RED
        data class CatScore(val score: Float, val count: Int, val maxLevel: Int)
        val catScores = categoryGroups.mapValues { (_, kws) ->
            val maxLevel = kws.maxOf { it.level.ordinal }
            val weight = when {
                kws.size >= 4 -> 1.00f
                kws.size == 3 -> 0.85f
                kws.size == 2 -> 0.65f
                else          -> 0.30f
            }
            CatScore(maxLevel * weight, kws.size, maxLevel)
        }

        val bestScore = catScores.values.maxOfOrNull { it.score } ?: 0f

        val hasCriticalKeyword = containsCriticalKeyword(matches)

        val adjustedRiskLevel = when {
            hasCriticalKeyword -> RiskLevel.RED
            bestScore < 1.00f -> RiskLevel.YELLOW   // 1 kw bất kỳ level
            bestScore < 2.00f -> RiskLevel.ORANGE   // 2 kw Lv3, hoặc 3 kw Lv2
            else              -> RiskLevel.RED       // 3+ kw Lv3, hoặc 4+ kw bất kỳ
        }

        val reason = buildString {
            when (adjustedRiskLevel) {
                RiskLevel.RED -> append("PHÁT HIỆN TỪ KHÓA NGUY HIỂM")
                RiskLevel.ORANGE -> append("PHÁT HIỆN TỪ KHÓA CÓ NGUY CƠ")
                RiskLevel.YELLOW -> append("Phát hiện từ khóa cần lưu ý")
                else -> append("Hệ thống L1 phát hiện từ khóa rủi ro.")
            }
            if (hasCriticalKeyword) {
                append(" [CẢNH BÁO OTP/BẢO MẬT]")
            }
            if (significantCategories.isNotEmpty()) {
                append(" [")
                append(significantCategories.keys.joinToString(", "))
                append("]")
            }
        }

        // Tính confidence: dựa trên co-occurrence + proportion
        val confidence = calculateConfidence(matches.size, significantCategories.size, totalTokens)

        val result = AnalysisResult(
            overallRiskLevel = adjustedRiskLevel,
            matches = matchedKeywords,
            reason = reason,
            analysisLevel = AnalysisLevel.L1,
            alertEnabled = adjustedRiskLevel != RiskLevel.GREEN,
            confidence = confidence
        )

        Log.d(TAG, "Matches found (${matches.size} kw, ${significantCategories.size} sig. categories), returning: $result")
        return result
    }

    /**
     * Tính confidence cho L1:
     * - Nhiều matches + significant categories → cao
     * - Ít matches, không có significant → thấp hơn
     * - Proportion của matches trong tổng tokens cũng ảnh hưởng
     */
    private fun calculateConfidence(matchCount: Int, significantCategoryCount: Int, totalTokens: Int): Float {
        var conf = 0.3f  // Base: có ít nhất 1 match
        // Bonus cho số lượng matches (diminishing returns)
        conf += minOf(matchCount * 0.1f, 0.3f)
        // Bonus cho significant categories (co-occurrence)
        conf += minOf(significantCategoryCount * 0.15f, 0.3f)
        // Bonus cho proportion (nếu match chiếm tỷ lệ cao trong text)
        if (totalTokens > 0) {
            val proportion = matchCount.toFloat() / totalTokens
            conf += minOf(proportion, 0.1f)
        }
        return conf.coerceIn(0.0f, 1.0f)
    }
}
