package com.example.lachancuocgoi.Analysis

/**
 * Interface chung cho tất cả analysis engines.
 * Mỗi engine (L1, L2, L3) implement interface này để Coordinator
 * không cần biết chi tiết nội bộ của từng engine.
 */
interface Analyzer : HealthCheckable {

    /** Level của engine này */
    val level: AnalysisLevel

    /** Khởi tạo engine (load models, data, etc.) */
    suspend fun initialize()

    /** Engine đã sẵn sàng để phân tích chưa? */
    fun isReady(): Boolean

    /** Reset session state cho cuộc gọi mới */
    fun resetSession()

    /** Số ký tự đã xử lý trong session hiện tại */
    fun getProcessedTextLength(): Int

    /** Đồng bộ processed text length (cho cross-engine sync) */
    fun syncProcessedTextLength(length: Int)

    /** Kết quả phân tích gần nhất */
    fun getLastResult(): AnalysisResult
}
