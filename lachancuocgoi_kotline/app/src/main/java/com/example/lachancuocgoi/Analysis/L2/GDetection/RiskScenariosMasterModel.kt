package com.example.lachancuocgoi.Analysis.L2.GDetection

import com.google.gson.annotations.SerializedName

/**
 * NEW Data models for risk_scenarios_master.json (v2.2, 250 scenarios)
 */

// Root model
data class RiskScenariosMaster(
    val title: String?,
    val version: String?,
    val description: String?,
    @SerializedName("total_scenarios") val totalScenarios: Int?,
    val scenarios: List<MasterScenario>?
)

// Individual scenario
data class MasterScenario(
    val id: String,
    val source: String?,
    @SerializedName("original_id") val originalId: String?,
    val name: String,
    val description: String?,
    @SerializedName("risk_level") val riskLevel: Int,
    @SerializedName("risk_level_name") val riskLevelName: String?,
    @SerializedName("risk_color") val riskColor: String?,
    val category: String?,
    @SerializedName("sub_category") val subCategory: String?,
    @SerializedName("trigger_phrases") val triggerPhrases: List<String>?,
    @SerializedName("required_context") val requiredContext: List<String>?,
    @SerializedName("dialogue_samples") val dialogueSamples: List<String>?,
    @SerializedName("red_flags") val redFlags: List<String>?,
    @SerializedName("l2_analysis_hints") val l2AnalysisHints: L2AnalysisHints?
)

data class L2AnalysisHints(
    @SerializedName("urgency_level") val urgencyLevel: String?,
    @SerializedName("authority_claim") val authorityClaim: Boolean?,
    @SerializedName("financial_request") val financialRequest: Boolean?,
    @SerializedName("information_request") val informationRequest: List<String>?,
    @SerializedName("psychological_tactics") val psychologicalTactics: List<String>?
)
