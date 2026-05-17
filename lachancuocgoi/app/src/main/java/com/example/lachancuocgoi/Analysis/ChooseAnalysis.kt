package com.example.lachancuocgoi.Analysis

import com.example.lachancuocgoi.Analysis.L1.L1Analyzer
import com.example.lachancuocgoi.Analysis.L2.L2Analyzer
import com.example.lachancuocgoi.Analysis.L3.L3Analyzer

/**
 * Chịu trách nhiệm chọn bộ phân tích phù hợp dựa trên chế độ đã chọn.
 * Mỗi overload chỉ nhận 1 analyzer tương ứng với mode → đảm bảo runtime độc lập.
 */
object ChooseAnalysis {

    suspend fun analyzeL1(
        fullText: String,
        l1Analyzer: L1Analyzer
    ): AnalysisResult {
        return l1Analyzer.analyzeStream(fullText)
    }

    suspend fun analyzeL2(
        incrementalText: String,
        fullText: String,
        l2Analyzer: L2Analyzer
    ): AnalysisResult {
        return l2Analyzer.analyze(incrementalText, fullText)
    }

    suspend fun analyzeL3(
        incrementalText: String,
        l3Analyzer: L3Analyzer
    ): AnalysisResult {
        return l3Analyzer.analyze(incrementalText)
    }
}
