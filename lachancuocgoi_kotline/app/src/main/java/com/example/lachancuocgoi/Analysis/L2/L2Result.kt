package com.example.lachancuocgoi.Analysis.L2

import com.example.lachancuocgoi.Analysis.AnalysisLevel
import com.example.lachancuocgoi.Analysis.AnalysisResult
import com.example.lachancuocgoi.Analysis.L2.GDetection.GResult
import com.example.lachancuocgoi.Analysis.KeywordMatch
import com.example.lachancuocgoi.RiskLevel

/**
 * (NÂNG CẤP theo logic mới) Chịu trách nhiệm tổng hợp và chuyển đổi kết quả từ L2 thành định dạng chung.
 * Đảm bảo không có thông tin nào từ các bước phân tích bị mất.
 */
object L2ResultParser {

    /**
     * Nhận vào một đối tượng GResult (kết quả từ GThinking) và chuyển đổi nó thành AnalysisResult.
     */
    fun parse(gResult: GResult): AnalysisResult {
        val allEvidence = mutableListOf<KeywordMatch>()

        // 1. Thêm tất cả các từ khóa bằng chứng đã được tìm thấy từ Bước 1.
        allEvidence.addAll(gResult.allMatchedKeywords)

        // 2. Nếu một chủ đề lừa đảo đã được xác nhận, tạo một "KeywordMatch" đặc biệt cho nó.
        // Điều này làm cho chủ đề được xác nhận xuất hiện như một bằng chứng quan trọng nhất.
        gResult.confirmedSituation?.let { topic ->
            val topicMatch = KeywordMatch(
                keyword = topic, // Tên của chủ đề, ví dụ: "Giả danh công an điều tra"
                level = RiskLevel.RED, // Chủ đề được xác nhận luôn có rủi ro cao nhất
                category = "Chủ đề Lừa đảo" // Gắn nhãn rõ ràng
            )
            // Thêm vào đầu danh sách để nó nổi bật
            allEvidence.add(0, topicMatch)
        }

        // Sắp xếp lại toàn bộ bằng chứng theo mức độ rủi ro
        val sortedMatches = allEvidence.distinct().sortedByDescending { it.level.ordinal }

        return AnalysisResult(
            overallRiskLevel = gResult.riskLevel,
            matches = sortedMatches, // Danh sách bằng chứng đầy đủ
            reason = gResult.reason, // Lý do đã được GThinking tổng hợp
            analysisLevel = AnalysisLevel.L2,
            alertEnabled = gResult.alertEnabled,  // NEW: Copy alert decision từ GResult
            confidence = gResult.riskScore?.finalScore ?: -1f  // Dùng weighted final score
        )
    }
}
