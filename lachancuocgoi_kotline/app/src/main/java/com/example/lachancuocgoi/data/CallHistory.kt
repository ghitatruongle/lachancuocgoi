package com.example.lachancuocgoi.data

import androidx.room.ColumnInfo
import androidx.room.Entity
import androidx.room.PrimaryKey
import com.google.gson.Gson

@Entity(tableName = "call_history")
data class CallHistory(
    @PrimaryKey(autoGenerate = true)
    val id: Long = 0,
    val dateTime: String,
    val riskLevel: String,
    val summary: String,
    val duration: String,
    val flagCount: Int,
    val transcript: String,
    val audioPath: String?,
    val analysisResult: String? = null,
    val analysisType: String? = null,

    @ColumnInfo(name = "alert_history")
    val alertHistory: String? = null
) {

    fun getAlertHistoryList(): List<AlertHistoryEntry> {
        if (alertHistory.isNullOrBlank()) return emptyList()

        return try {
            val array = Gson().fromJson(
                alertHistory,
                Array<AlertHistoryEntry>::class.java
            )
            array?.toList() ?: emptyList()
        } catch (e: com.google.gson.JsonSyntaxException) {
            android.util.Log.e("CallHistory", "Invalid JSON format in alert_history: $alertHistory", e)
            emptyList()
        } catch (e: Exception) {
            android.util.Log.e("CallHistory", "Failed to parse alert history", e)
            emptyList()
        }
    }

    companion object {

        fun alertHistoryToJson(history: List<AlertHistoryEntry>): String {
            return Gson().toJson(history)
        }
    }
}
