package com.example.lachancuocgoi.Analysis.L2.GDetection

import com.example.lachancuocgoi.Analysis.common.TextNormalizer

/**
 * GFlash chịu trách nhiệm tiền xử lý văn bản, token hóa và chuẩn hóa từ lóng.
 * Sử dụng TextNormalizer chung để đảm bảo nhất quán với L1.
 */
object GFlash {

    /**
     * Nạp bản đồ từ lóng và sắp xếp theo độ dài giảm dần để ưu tiên cụm từ dài.
     */
    fun loadSlangConfig(config: Map<String, String>) {
        TextNormalizer.loadSlangConfig(config)
    }

    /**
     * Tách văn bản thành tokens sau khi đã chuẩn hóa ngữ nghĩa.
     * L2 dùng NoiseMode.SPACE (giữ khoảng trắng thay vì nối liền).
     */
    fun tokenize(text: String): List<String> {
        return TextNormalizer.tokenize(text, applySlang = true, noiseMode = TextNormalizer.NoiseMode.SPACE)
    }
}
