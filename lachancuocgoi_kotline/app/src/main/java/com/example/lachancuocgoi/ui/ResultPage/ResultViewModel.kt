package com.example.lachancuocgoi.ui.ResultPage

import android.content.ContentValues
import android.content.Context
import android.os.Build
import android.provider.MediaStore
import androidx.lifecycle.ViewModel
import androidx.lifecycle.ViewModelProvider
import androidx.lifecycle.viewModelScope
import com.example.lachancuocgoi.data.CallHistory
import com.example.lachancuocgoi.data.CallHistoryDao
import com.example.lachancuocgoi.data.AlertHistoryEntry
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.launch
import kotlinx.coroutines.withContext
import java.io.IOException

class ResultViewModel(
    private val callHistoryDao: CallHistoryDao
) : ViewModel() {

    private val _alertHistory = MutableStateFlow<List<AlertHistoryEntry>>(emptyList())
    val alertHistory: StateFlow<List<AlertHistoryEntry>> = _alertHistory.asStateFlow()

    private val _isSaving = MutableStateFlow(false)
    val isSaving: StateFlow<Boolean> = _isSaving.asStateFlow()

    private val _saveResult = MutableStateFlow<String?>(null)
    val saveResult: StateFlow<String?> = _saveResult.asStateFlow()

    fun clearSaveResult() {
        _saveResult.value = null
    }

    fun processAlertHistory(item: CallHistory?) {
        if (item == null) return
        viewModelScope.launch(Dispatchers.IO) {
            val list = item.getAlertHistoryList()
            _alertHistory.value = list
        }
    }

    fun saveTranscript(context: Context, transcript: String, dateTime: String) {
        viewModelScope.launch {
            _isSaving.value = true
            try {
                withContext(Dispatchers.IO) {
                    val fileName = dateTime.replace("[:/]", "_").replace(" ", "_") + ".txt"
                    val contentValues = ContentValues().apply {
                        put(MediaStore.MediaColumns.DISPLAY_NAME, fileName)
                        put(MediaStore.MediaColumns.MIME_TYPE, "text/plain")
                        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
                            put(MediaStore.MediaColumns.RELATIVE_PATH, "Download/")
                        }
                    }
                    val resolver = context.contentResolver
                    val uri = resolver.insert(MediaStore.Files.getContentUri("external"), contentValues)

                    if (uri != null) {
                        resolver.openOutputStream(uri)?.use { outputStream ->
                            outputStream.write(transcript.toByteArray())
                        }
                    } else {
                        throw IOException("Không thể tạo tệp để lưu")
                    }
                }
                _saveResult.value = "Đã lưu bản ghi vào thư mục Download"
            } catch (e: Exception) {
                _saveResult.value = "Lỗi khi lưu bản ghi: ${e.message}"
            } finally {
                _isSaving.value = false
            }
        }
    }
}

class ResultViewModelFactory(
    private val callHistoryDao: CallHistoryDao
) : ViewModelProvider.Factory {
    override fun <T : ViewModel> create(modelClass: Class<T>): T {
        if (modelClass.isAssignableFrom(ResultViewModel::class.java)) {
            @Suppress("UNCHECKED_CAST")
            return ResultViewModel(callHistoryDao) as T
        }
        throw IllegalArgumentException("Unknown ViewModel class")
    }
}
