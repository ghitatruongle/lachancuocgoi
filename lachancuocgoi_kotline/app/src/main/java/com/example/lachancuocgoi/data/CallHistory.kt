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
    val analysisType: String? = null, // Thêm trường để lưu loại phân tích
    
    @ColumnInfo(name = "alert_history")
    val alertHistory: String? = null // JSON string của List<AlertHistoryEntry>
) {
    /**
     * Chuyển JSON string thành List<AlertHistoryEntry>
     * Với error handling đầy đủ và logging để debug
     */
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
        /**
         * Chuyển List<AlertHistoryEntry> thành JSON string để lưu vào database
         */
        fun alertHistoryToJson(history: List<AlertHistoryEntry>): String {
            return Gson().toJson(history)
        }
    }
}
