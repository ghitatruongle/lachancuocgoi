package com.example.lachancuocgoi.Analysis

enum class HealthStatus {
    HEALTHY,
    DEGRADED,
    DOWN
}

data class HealthReport(
    val status: HealthStatus,
    val engineName: String,
    val details: String,
    val lastCheckedMs: Long = System.currentTimeMillis()
)

interface HealthCheckable {
    fun healthCheck(): HealthReport
}
