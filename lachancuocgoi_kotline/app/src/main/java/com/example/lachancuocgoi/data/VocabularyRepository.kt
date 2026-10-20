package com.example.lachancuocgoi.data

import android.content.Context
import com.google.gson.Gson
import com.google.gson.annotations.SerializedName
import java.io.InputStreamReader

private data class RiskModelSentences(val situations: List<String>)

object VocabularyRepository {

    private const val SENTENCES_FILE = "risk_model_sentences.json"

    fun getSituationSentences(context: Context): List<String> {
        return try {
            val inputStream = context.assets.open(SENTENCES_FILE)
            val model: RiskModelSentences = Gson().fromJson(InputStreamReader(inputStream), RiskModelSentences::class.java)
            model.situations
        } catch (e: Exception) {

            e.printStackTrace()
            emptyList()
        }
    }
}
