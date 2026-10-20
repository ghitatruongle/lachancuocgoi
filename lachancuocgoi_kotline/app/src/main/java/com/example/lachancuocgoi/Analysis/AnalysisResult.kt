package com.example.lachancuocgoi.Analysis

import com.example.lachancuocgoi.RiskLevel

data class AnalysisResult(
    val overallRiskLevel: RiskLevel,
    val matches: List<KeywordMatch>,
    val reason: String? = null,
    val analysisLevel: AnalysisLevel = AnalysisLevel.L1,
    val alertEnabled: Boolean = true,
    val isError: Boolean = false,
    val confidence: Float = -1f,
    val modelName: String? = null
)

data class KeywordMatch(
    val keyword: String,
    val level: RiskLevel,
    val category: String,
    val startIndex: Int = -1,
    val endIndex: Int = -1,
    val isFuzzy: Boolean = false
)
