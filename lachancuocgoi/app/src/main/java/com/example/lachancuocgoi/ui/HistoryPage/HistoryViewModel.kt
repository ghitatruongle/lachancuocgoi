package com.example.lachancuocgoi.ui.HistoryPage

import androidx.lifecycle.ViewModel
import androidx.lifecycle.ViewModelProvider
import androidx.lifecycle.asFlow
import androidx.lifecycle.viewModelScope
import com.example.lachancuocgoi.data.CallHistory
import com.example.lachancuocgoi.data.CallHistoryDao
import kotlinx.coroutines.ExperimentalCoroutinesApi
import kotlinx.coroutines.FlowPreview
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.SharingStarted
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.flow.combine
import kotlinx.coroutines.flow.debounce
import kotlinx.coroutines.flow.flatMapLatest
import kotlinx.coroutines.flow.flowOf
import kotlinx.coroutines.flow.stateIn
import kotlinx.coroutines.launch

class HistoryViewModel(private val callHistoryDao: CallHistoryDao) : ViewModel() {

    private val _rawSearchQuery = MutableStateFlow("")
    val searchQuery: StateFlow<String> = _rawSearchQuery.asStateFlow()

    @OptIn(FlowPreview::class, ExperimentalCoroutinesApi::class)
    val filteredHistoryItems: StateFlow<List<CallHistory>> = combine(
        callHistoryDao.getAll().asFlow(),
        _rawSearchQuery.debounce(300)
    ) { items, query ->
        if (query.isBlank()) {
            items
        } else {
            items.filter {
                it.summary.contains(query, ignoreCase = true) ||
                        it.riskLevel.contains(query, ignoreCase = true) ||
                        it.dateTime.contains(query, ignoreCase = true) ||
                        it.transcript.contains(query, ignoreCase = true) ||
                        (it.analysisType?.contains(query, ignoreCase = true) ?: false)
            }
        }
    }.stateIn(
        scope = viewModelScope,
        started = SharingStarted.WhileSubscribed(5000),
        initialValue = emptyList()
    )

    fun updateSearchQuery(query: String) {
        _rawSearchQuery.value = query
    }

    fun deleteItem(id: Long) {
        viewModelScope.launch {
            callHistoryDao.deleteById(id)
        }
    }

    fun deleteAll() {
        viewModelScope.launch {
            callHistoryDao.deleteAll()
        }
    }
}

class HistoryViewModelFactory(
    private val dao: CallHistoryDao
) : ViewModelProvider.Factory {
    override fun <T : ViewModel> create(modelClass: Class<T>): T {
        if (modelClass.isAssignableFrom(HistoryViewModel::class.java)) {
            @Suppress("UNCHECKED_CAST")
            return HistoryViewModel(dao) as T
        }
        throw IllegalArgumentException("Unknown ViewModel class")
    }
}