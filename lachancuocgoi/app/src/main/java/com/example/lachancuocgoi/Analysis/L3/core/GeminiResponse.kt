package com.example.lachancuocgoi.Analysis.L3.core

import com.google.gson.annotations.SerializedName

/**
 * Response model cho analysis request.
 * Khớp với JSON format được định nghĩa trong prompt.
 */
data class AnalysisResponse(
    @SerializedName("level")
    val level: String?, // "green", "yellow", "orange", "red"

    @SerializedName("label")
    val label: String?, // Loại lừa đảo

    @SerializedName("reason")
    val reason: String?, // Giải thích ngắn gọn

    @SerializedName("recommendation")
    val recommendation: String? // Khuyến cáo ngắn gọn
)
