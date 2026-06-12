package com.example.lachancuocgoi.Analysis

import com.example.lachancuocgoi.RiskLevel

/**
 * Đại diện cho kết quả của một phiên phân tích văn bản.
 *
 * @param overallRiskLevel Mức độ rủi ro tổng thể được tính toán.
 * @param matches Danh sách các từ khóa đáng ngờ được tìm thấy.
 * @param reason Lý do cho kết quả phân tích (thường được sử dụng với phân tích AI).
 * @param analysisLevel Cấp độ phân tích tạo ra kết quả này ("L1", "L2", hoặc "L3").
 */
data class AnalysisResult(
    val overallRiskLevel: RiskLevel,
    val matches: List<KeywordMatch>,
    val reason: String? = null,
    val analysisLevel: AnalysisLevel = AnalysisLevel.L1,
    val alertEnabled: Boolean = true,  // NEW: Điều khiển alert (default true for L1 compatibility)
    val isError: Boolean = false,      // MỚI: Cờ xác định có lỗi mạng/API để chuyển chế độ sang L2
    val confidence: Float = -1f,       // -1 = chưa tính, 0.0-1.0 = độ tin cậy của engine
    val modelName: String? = null      // NEW: Lưu tên cụ thể của model AI đã dùng (nếu có)
)

/**
 * Đại diện cho một từ khóa đáng ngờ được tìm thấy trong văn bản.
 *
 * @param keyword Từ khóa gốc (chưa qua chuẩn hóa).
 * @param level Mức độ rủi ro của từ khóa.
 * @param category Danh mục của từ khóa (ví dụ: LỪA ĐẢO, BẠO LỰC).
 */
data class KeywordMatch(
    val keyword: String,
    val level: RiskLevel,
    val category: String,
    val startIndex: Int = -1, // Vị trí bắt đầu của từ khóa trong danh sách tokens
    val endIndex: Int = -1,   // Vị trí kết thúc của từ khóa
    val isFuzzy: Boolean = false // True nếu match qua fuzzy matching (Levenshtein)
)
