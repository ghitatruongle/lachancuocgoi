package com.example.lachancuocgoi.Analysis.L2

import com.example.lachancuocgoi.Analysis.AnalysisLevel
import com.example.lachancuocgoi.Analysis.AnalysisResult
import com.example.lachancuocgoi.Analysis.L2.GDetection.GResult
import com.example.lachancuocgoi.Analysis.KeywordMatch
import com.example.lachancuocgoi.RiskLevel

object L2ResultParser {

    fun parse(gResult: GResult): AnalysisResult {
        val allEvidence = mutableListOf<KeywordMatch>()

        allEvidence.addAll(gResult.allMatchedKeywords)

        gResult.confirmedSituation?.let { topic ->
            val topicMatch = KeywordMatch(
                keyword = topic,
                level = RiskLevel.RED,
                category = "Chủ đề Lừa đảo"
            )

            allEvidence.add(0, topicMatch)
        }

        val sortedMatches = allEvidence.distinct().sortedByDescending { it.level.ordinal }

        return AnalysisResult(
            overallRiskLevel = gResult.riskLevel,
            matches = sortedMatches,
            reason = gResult.reason,
            analysisLevel = AnalysisLevel.L2,
            alertEnabled = gResult.alertEnabled,
            confidence = gResult.riskScore?.finalScore ?: -1f
        )
    }
}
