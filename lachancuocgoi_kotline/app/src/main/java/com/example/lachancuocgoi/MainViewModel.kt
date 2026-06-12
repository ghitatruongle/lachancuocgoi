package com.example.lachancuocgoi

import android.app.Application
import androidx.lifecycle.AndroidViewModel
import androidx.lifecycle.viewModelScope
import com.example.lachancuocgoi.data.AppDatabase
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.launch

class MainViewModel(application: Application) : AndroidViewModel(application) {
    private val _isReady = MutableStateFlow(false)
    val isReady = _isReady.asStateFlow()

    private val _database = MutableStateFlow<AppDatabase?>(null)
    val database = _database.asStateFlow()

    init {
        viewModelScope.launch(Dispatchers.IO) {
            _database.value = AppDatabase.getDatabase(application)
            _isReady.value = true
        }
    }
}
