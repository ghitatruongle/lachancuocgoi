package com.example.lachancuocgoi.Analysis.L2.Safety

import android.content.Context
import android.util.Log
import com.google.gson.Gson
import com.google.gson.annotations.SerializedName
import java.io.InputStreamReader

/**
 * Giai đoạn 4: Bộ lọc an toàn v2 (Position-aware).
 * CHỈ giảm điểm rủi ro nếu dấu hiệu an toàn nằm ở PHẦN MỞ ĐẦU cuộc gọi.
 * Ngăn kẻ lừa đảo chèn "ăn cơm chưa" vào giữa/cuối để bypass hệ thống.
 *
 * Config được load từ safety_keywords.json thay vì hard-code.
 */
object SafetyFilter {
    private const val TAG = "SafetyFilter"

    private var openingSectionLength = 200
    private var casualPhrases = listOf(
        "ăn cơm chưa", "đi chơi không", "đang làm gì đấy", "thế à", "vậy hả",
        "mẹ đây", "bố đây", "con đang", "chút nữa gọi lại", "mua rau", "đi chợ"
    )
    private var standardTransactions = listOf(
        "chuyển khoản tiền trọ", "tiền cơm", "chia tiền nốt", "chuyển tiền học phí", "trả tiền điện"
    )
    private var dangerOverrides = listOf(
        "số tài khoản", "mã otp", "chuyển khoản", "mật khẩu",
        "cccd", "cmnd", "công an", "kiểm sát", "tải ứng dụng",
        "cài app", "link", "bắt cóc", "tống tiền"
    )
    private var casualReductionPerMatch = 0.15
    private var transactionReductionPerMatch = 0.30
    private var minMultiplier = 0.4

    private data class SafetyConfig(
        val openingSectionLength: Int = 200,
        val casualPhrases: List<String> = emptyList(),
        val standardTransactions: List<String> = emptyList(),
        val dangerOverrides: List<String> = emptyList(),
        val casualReductionPerMatch: Double = 0.15,
        val transactionReductionPerMatch: Double = 0.30,
        val minMultiplier: Double = 0.4
    )

    /**
     * Nạp config từ safety_keywords.json. Fallback sang default nếu lỗi.
     */
    fun loadConfig(context: Context) {
        try {
            val inputStream = context.assets.open("safety_keywords.json")
            val config: SafetyConfig = Gson().fromJson(
                InputStreamReader(inputStream), SafetyConfig::class.java
            )
            openingSectionLength = config.openingSectionLength
            casualPhrases = config.casualPhrases
            standardTransactions = config.standardTransactions
            dangerOverrides = config.dangerOverrides
            casualReductionPerMatch = config.casualReductionPerMatch
            transactionReductionPerMatch = config.transactionReductionPerMatch
            minMultiplier = config.minMultiplier
            Log.i(TAG, "Đã nạp SafetyFilter config từ JSON (${casualPhrases.size} casual, ${dangerOverrides.size} danger)")
        } catch (e: Exception) {
            Log.w(TAG, "Không thể nạp safety_keywords.json, dùng default config", e)
        }
    }

    /**
     * Đánh giá mức độ "an toàn" theo vị trí - v2.
     * @param fullTranscript Toàn bộ đoạn hội thoại hiện hành.
     * @return Hệ số nhân (Multiplier). < 1.0 nghĩa là giảm rủi ro (an toàn hơn).
     */
    fun calculateSafetyDiscount(fullTranscript: String): Double {
        val text = fullTranscript.lowercase()
        
        // 0. Kiểm tra phần chính (sau opening) có từ khóa nguy hiểm không
        val mainSection = if (text.length > openingSectionLength) {
            text.substring(openingSectionLength)
        } else ""
        
        val hasDangerInMain = dangerOverrides.any { mainSection.contains(it) }
        if (hasDangerInMain) {
            // Có từ khóa nguy hiểm ở phần chính → KHÔNG giảm rủi ro dù opening thân mật
            Log.d(TAG, "Danger keywords found in main section. Safety discount DISABLED.")
            return 1.0
        }

        // 1. Chỉ kiểm tra tính thân mật ở PHẦN MỞ ĐẦU
        val openingSection = text.take(openingSectionLength)
        var discountMultiplier = 1.0

        val casualMatchCount = casualPhrases.count { openingSection.contains(it) }
        if (casualMatchCount > 0) {
            val reduction = casualReductionPerMatch * casualMatchCount
            discountMultiplier -= reduction
        }

        // 2. Kiểm tra giao dịch chuẩn (toàn bộ text — vì giao dịch chuẩn có thể ở bất kỳ đâu)
        val safeTransactionMatchCount = standardTransactions.count { text.contains(it) }
        if (safeTransactionMatchCount > 0) {
            val reduction = transactionReductionPerMatch * safeTransactionMatchCount
            discountMultiplier -= reduction
        }

        // Giới hạn giảm tối đa
        val finalMultiplier = discountMultiplier.coerceAtLeast(minMultiplier)

        if (finalMultiplier < 1.0) {
            Log.d(TAG, "Safety Filter v2 Applied. Discount Multiplier: $finalMultiplier (Opening casual: $casualMatchCount, Safe transactions: $safeTransactionMatchCount)")
        }

        return finalMultiplier
    }
}
