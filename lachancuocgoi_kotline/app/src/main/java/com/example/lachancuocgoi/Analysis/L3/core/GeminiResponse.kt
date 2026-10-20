package com.example.lachancuocgoi.Analysis.L3.core

import com.google.gson.annotations.SerializedName

data class AnalysisResponse(
    @SerializedName("level")
    val level: String?,

    @SerializedName("label")
    val label: String?,

    @SerializedName("reason")
    val reason: String?,

    @SerializedName("recommendation")
    val recommendation: String?
)
