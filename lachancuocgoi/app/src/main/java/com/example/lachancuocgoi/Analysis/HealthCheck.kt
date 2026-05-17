package com.example.lachancuocgoi.Analysis

/**
 * Health check system cho mỗi analysis engine.
 * Cho phép Coordinator phát hiện engine bị lỗi và tự fallback.
 */
enum class HealthStatus {
    HEALTHY,    // Engine hoạt động bình thường
    DEGRADED,   // Engine hoạt động nhưng chất lượng giảm (vd: Trie rỗng, model cũ)
    DOWN        // Engine không hoạt động (vd: API key hết quota, model crash)
}

/**
 * Kết quả chi tiết của health check.
 */
data class HealthReport(
    val status: HealthStatus,
    val engineName: String,
    val details: String,            // Mô tả chi tiết vấn đề
    val lastCheckedMs: Long = System.currentTimeMillis()
)

/**
 * Interface cho các engine có thể kiểm tra sức khỏe.
 */
interface HealthCheckable {
    fun healthCheck(): HealthReport
}
