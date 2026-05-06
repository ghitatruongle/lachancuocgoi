package com.example.lachancuocgoi.Analysis.L2.GDetection

import com.example.lachancuocgoi.Analysis.KeywordMatch
import com.example.lachancuocgoi.RiskLevel
import com.google.gson.annotations.SerializedName

// ================= RESULTS =================

/**
 * Đại diện cho kết quả phân tích cuối cùng từ toàn bộ hệ thống L2 (GDetectionEngine).
 */
data class GResult(
    val riskLevel: RiskLevel,
    val reason: String,
    val allMatchedKeywords: Set<KeywordMatch> = emptySet(),
    val confirmedSituation: String? = null,
    val matchedPatterns: List<MatchedPattern> = emptyList(),
    val riskScore: RiskScore? = null,
    // NEW FIELDS
    val sentenceMatch: SentenceMatch? = null,
    val mostLikelyScenario: ScenarioMatch? = null,
    val alertEnabled: Boolean = false  // NEW: Điều khiển alert (true = trigger alert, false = chỉ highlight)
)

/**
 * Chi tiết điểm số thành phần (Multi-Layer Scoring).
 */
data class RiskScore(
    val keywordScore: Float,      // Điểm từ khóa thuần
    val topicScore: Float,        // Điểm chủ đề
    val patternScore: Float,      // Điểm khớp mẫu câu
    val contextScore: Float,      // Điểm ngữ cảnh (Proximity + Position)
    val sentenceScore: Float = 0f,// Điểm khớp câu thoại
    val scenarioScore: Float = 0f,// Điểm khớp kịch bản
    val finalScore: Float         // Tổng điểm trọng số (0.0 - 1.0)
)

data class SituationMatchResult(
    val confirmedSituationName: String?,
    val allMatchedSituations: Map<String?, Float> = emptyMap()
)

data class SentenceMatch(
    val sentence: String,
    val level: Int,
    val isSafe: Boolean = false
)

data class ScenarioMatch(
    val scenarioId: Int,
    val situationName: String,
    val similarityScore: Float,
    val group: String? = null, // NEW: Scam group if available
    val level: Int = 0 // NEW: Risk level of matched scenario
)

// ================= INTERNAL ENGINE MODELS =================

internal data class KeywordTrieData(
    val riskLevel: RiskLevel,
    val category: String,
    val originalKeyword: String
)

internal class TrieNode {
    val children: MutableMap<String, TrieNode> = mutableMapOf()
    var keywordData: KeywordTrieData? = null
}

// ================= JSON CONFIG MODELS =================

data class RiskModelVocabulary(@SerializedName("riskLevels") val riskLevels: List<RiskLevelData>?)
data class RiskLevelData(
    val level: Int,
    val keywords: List<String>?,
    val threats: Map<String, List<String>>?
)

data class AiCheckModel(@SerializedName("situations") val situations: List<AiCheckSituation>?)
data class AiCheckSituation(
    val name: String,
    @SerializedName("trigger_phrases") val triggerPhrases: List<String>?,
    @SerializedName("required_context") val requiredContext: List<String>?,
    @SerializedName("risk_level") val riskLevel: String? = null
)

data class SlangConfig(
    @SerializedName("slang_map") val slangMap: Map<String, String>?
)

// Tier Config — loaded from tier_config.json (externalized from GThinking hardcode)
data class TierConfig(
    @SerializedName("tier1_topics") val tier1Topics: List<String>?,
    @SerializedName("tier2_urgency") val tier2Urgency: List<String>?,
    @SerializedName("tier3_pii") val tier3Pii: List<String>?
)

// Scoring Configuration
data class ScoringConfig(
    val topicConfirmationThreshold: Int = 3,
    val scenarioSimilarityThreshold: Float = 0.3f,
    val scenario_alert_threshold: Float = 0.6f,  // NEW: >= 60% scenario match để trigger alert
    val high_keyword_threshold: Float = 0.5f,    // NEW: >= 50% keyword score cho orange fallback
    val riskLevelThresholds: RiskThresholds = RiskThresholds(),
    val weights: ScoringWeights = ScoringWeights()
)

data class RiskThresholds(
    val red: Float = 0.70f,
    val orange: Float = 0.50f,
    val yellow: Float = 0.30f
)

data class ScoringWeights(
    val keyword: Float = 0.20f,
    val topic: Float = 0.15f,
    val pattern: Float = 0.25f,
    val scenario: Float = 0.25f,
    val context: Float = 0.10f,
    val sentiment: Float = 0.05f   // [FIX] Was missing — causes total weight to be 0.95 without it
)


// NEW: Risk Model Situation (Scenario-based)
data class RiskModelSituation(@SerializedName("riskLevels") val riskLevels: List<RiskSituationLevel>?)
data class RiskSituationLevel(
    val level: Int,
    val labelId: String?,
    val vietnameseName: String?,
    val scenarios: List<RiskScenario>?
)
data class RiskScenario(
    val id: Int,
    val group: String?,
    val situation: String?,
    val dialogue: String?
)

// NEW: Risk Model Sentences
data class RiskModelSentences(@SerializedName("riskLevels") val riskLevels: List<RiskSentenceLevel>?)
data class RiskSentenceLevel(
    val level: Int,
    val vietnameseName: String?,
    val sentences: List<String>?, // For level 0
    val threats: Map<String, List<String>>? // For level 1, 2, 3
)

// ================= PATTERN MODELS =================

data class ScamPattern(
    val id: String,
    val description: String,
    val template: List<PatternElement>,
    val riskBonus: Float = 0.5f,
    val minGap: Int = 0,
    val maxGap: Int = 5
)

sealed class PatternElement {
    data class Keyword(val value: String) : PatternElement()
    data class Category(val categoryName: String) : PatternElement()
    object Wildcard : PatternElement()
}

data class MatchedPattern(
    val patternId: String,
    val matchedElements: List<String>,
    val score: Float
)

// ================= PATTERN DTOs =================

data class PatternConfigDTO(
    val patterns: List<ScamPatternDTO>?
)

data class ScamPatternDTO(
    val id: String,
    val description: String?,
    val risk_bonus: Float?,
    val min_gap: Int?,
    val max_gap: Int?,
    val template: List<PatternElementDTO>?
) {
    fun toDomain(): ScamPattern {
        return ScamPattern(
            id = id,
            description = description ?: "",
            template = template?.map { it.toDomain() } ?: emptyList(),
            riskBonus = risk_bonus ?: 0.5f,
            minGap = min_gap ?: 0,
            maxGap = max_gap ?: 5
        )
    }
}

data class PatternElementDTO(
    val type: String,
    val value: String?
) {
    fun toDomain(): PatternElement {
        return when (type.lowercase()) {
            "keyword" -> PatternElement.Keyword(value ?: "")
            "category" -> PatternElement.Category(value ?: "")
            "wildcard" -> PatternElement.Wildcard
            else -> PatternElement.Keyword(value ?: "")
        }
    }
}
