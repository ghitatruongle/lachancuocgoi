package com.example.lachancuocgoi.data

import androidx.lifecycle.LiveData
import androidx.room.Dao
import androidx.room.Insert
import androidx.room.OnConflictStrategy
import androidx.room.Query

@Dao
interface CallHistoryDao {

    @Insert(onConflict = OnConflictStrategy.REPLACE)
    suspend fun insert(callHistory: CallHistory): Long

    @Query("SELECT * FROM call_history ORDER BY id DESC")
    fun getAll(): LiveData<List<CallHistory>>

    @Query("SELECT * FROM call_history WHERE id = :id")
    fun getById(id: Long): LiveData<CallHistory>

    @Query("DELETE FROM call_history")
    suspend fun deleteAll()

    @Query("DELETE FROM call_history WHERE id = :id")
    suspend fun deleteById(id: Long)

    @Query("UPDATE call_history SET riskLevel = :riskLevel WHERE id = :id")
    suspend fun updateRiskLevel(id: Long, riskLevel: String)
    
    @Query("SELECT * FROM call_history WHERE id = :id")
    suspend fun getByIdSync(id: Long): CallHistory?
    
    @androidx.room.Update
    suspend fun update(callHistory: CallHistory)
}
