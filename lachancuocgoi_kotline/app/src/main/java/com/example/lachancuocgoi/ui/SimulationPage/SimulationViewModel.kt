package com.example.lachancuocgoi.ui.SimulationPage

import android.content.Context
import androidx.lifecycle.ViewModel
import androidx.lifecycle.viewModelScope
import com.google.gson.Gson
import com.google.gson.reflect.TypeToken
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.flow.*
import kotlinx.coroutines.launch

val NORMAL_MODE_TITLES = listOf(
    "Bạn bè hỏi thăm",
    "Dọa khóa SIM — Giả nhân viên viễn thông",
    "Giả danh Công an — Lệnh triệu tập",
    "Lừa đảo ngân hàng — Yêu cầu OTP"
)

data class SimulationUiState(
    val scenarios: List<SimulationScenarioData>? = null,
    val categories: List<String> = emptyList(),
    val filteredScenarios: List<SimulationScenarioData> = emptyList(),
    val searchQuery: String = "",
    val selectedCategory: String? = null,
    val isDevMode: Boolean = false
)

class SimulationViewModel : ViewModel() {
    private val allScenarios = MutableStateFlow<List<SimulationScenarioData>?>(null)
    
    private val _searchQuery = MutableStateFlow("")
    val searchQuery = _searchQuery.asStateFlow()
    
    private val _selectedCategory = MutableStateFlow<String?>(null)
    val selectedCategory = _selectedCategory.asStateFlow()
    
    private val _isDevMode = MutableStateFlow(false)

    private val _uiState = MutableStateFlow(SimulationUiState())
    val uiState: StateFlow<SimulationUiState> = _uiState.asStateFlow()

    init {
        viewModelScope.launch(Dispatchers.Default) {
            combine(allScenarios, _searchQuery, _selectedCategory, _isDevMode) { scenarios, query, category, isDev ->
                if (scenarios == null) return@combine SimulationUiState(null, emptyList(), emptyList(), query, category, isDev)
                
                val sourceList = if (isDev) {
                    scenarios
                } else {
                    scenarios.filter { it.title in NORMAL_MODE_TITLES }
                }
                
                val categories = sourceList.map { it.category }.distinct()
                
                val filtered = sourceList.filter { scenario ->
                    val matchesSearch = query.isEmpty() ||
                        scenario.title.contains(query, ignoreCase = true) ||
                        scenario.description.contains(query, ignoreCase = true)
                    val matchesCategory = category == null || scenario.category == category
                    matchesSearch && matchesCategory
                }
                
                SimulationUiState(
                    scenarios = sourceList,
                    categories = categories,
                    filteredScenarios = filtered,
                    searchQuery = query,
                    selectedCategory = category,
                    isDevMode = isDev
                )
            }.collect {
                _uiState.value = it
            }
        }
    }

    fun loadData(context: Context) {
        if (allScenarios.value != null) return
        viewModelScope.launch(Dispatchers.IO) {
            try {
                context.assets.open("situation_test.json").bufferedReader().use { reader ->
                    val type = object : TypeToken<List<SimulationScenarioData>>() {}.type
                    val loaded = Gson().fromJson<List<SimulationScenarioData>>(reader, type) ?: emptyList()
                    
                    // Xử lý lỗi Gson bỏ qua giá trị mặc định của Kotlin và gán null cho 'category'
                    val safeLoaded = loaded.map { 
                        it.copy(category = (it.category as String?) ?: "Chung")
                    }
                    allScenarios.value = safeLoaded
                }
            } catch (e: Exception) {
                e.printStackTrace()
                allScenarios.value = emptyList()
            }
        }
    }

    fun updateSearchQuery(query: String) {
        _searchQuery.value = query
    }

    fun updateSelectedCategory(category: String?) {
        _selectedCategory.value = category
    }

    fun updateDevMode(isDev: Boolean) {
        _isDevMode.value = isDev
    }
}
