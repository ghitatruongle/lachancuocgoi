package com.example.lachancuocgoi.data

import android.content.Context
import com.google.gson.Gson
import com.google.gson.annotations.SerializedName
import java.io.InputStreamReader

// --- Cấu trúc dữ liệu cho JSON câu tình huống (Chỉ dùng cho L2) ---
private data class RiskModelSentences(val situations: List<String>)


/**
 * Repository trung tâm cho hệ thống L2.
 * Chịu trách nhiệm tải và chuẩn bị dữ liệu câu tình huống cho bộ phân tích ngữ nghĩa.
 * Hoạt động độc lập với L1.
 */
object VocabularyRepository {

    private const val SENTENCES_FILE = "risk_model_sentences.json"

    /**
     * Tải danh sách các câu tình huống từ `risk_model_sentences.json`.
     * @return a List<String> chứa các câu kịch bản cho L2.
     */
    fun getSituationSentences(context: Context): List<String> {
        return try {
            val inputStream = context.assets.open(SENTENCES_FILE)
            val model: RiskModelSentences = Gson().fromJson(InputStreamReader(inputStream), RiskModelSentences::class.java)
            model.situations
        } catch (e: Exception) {
            // Trong ứng dụng thực tế, nên log lỗi này
            e.printStackTrace()
            emptyList()
        }
    }
}
