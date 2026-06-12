package com.example.lachancuocgoi

import androidx.compose.ui.graphics.Color

enum class RiskLevel(val vietnameseName: String, val color: Color) {
    GREEN("An toàn", Color.Green),
    YELLOW("Chú ý", Color.Yellow),
    ORANGE("Có nguy cơ", Color(0xFFFFA500)),
    RED("Nguy hiểm", Color.Red);

    val level: Int
        get() = ordinal

    /** Giảm 1 bậc risk level an toàn. GREEN không giảm được thêm. */
    fun deescalate(): RiskLevel = when (this) {
        RED -> ORANGE
        ORANGE -> YELLOW
        YELLOW -> GREEN
        GREEN -> GREEN
    }

    companion object {
        fun fromString(value: String?): RiskLevel {
            return when (value?.uppercase()) {
                "RED" -> RED
                "ORANGE" -> ORANGE
                "YELLOW" -> YELLOW
                else -> GREEN
            }
        }

        // (SỬA LỖI) Thêm hàm fromInt bị thiếu
        fun fromInt(value: Int): RiskLevel {
            return when (value) {
                3 -> RED
                2 -> ORANGE
                1 -> YELLOW
                else -> GREEN
            }
        }
    }
}
