package com.example.lachancuocgoi.ui.HomePage

import android.content.Context
import androidx.lifecycle.ViewModel
import com.example.lachancuocgoi.ui.HomePage.RightsDialog.PermissionUtils
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.flow.update

data class HomeUiState(
    val isRecordAudioGranted: Boolean = false,
    val isCallCaptionEnabled: Boolean = false,
    val isCallDetectionEnabled: Boolean = false,
    val isCallScreeningEnabled: Boolean = false
)

class HomeViewModel : ViewModel() {
    private val _uiState = MutableStateFlow(HomeUiState())
    val uiState: StateFlow<HomeUiState> = _uiState.asStateFlow()

    fun checkPermissions(context: Context) {
        _uiState.update { currentState ->
            currentState.copy(
                isRecordAudioGranted = PermissionUtils.isRecordAudioGranted(context),
                isCallCaptionEnabled = PermissionUtils.isCallCaptionEnabled(context),
                isCallDetectionEnabled = PermissionUtils.isCallDetectionEnabled(context),
                isCallScreeningEnabled = PermissionUtils.isCallScreeningRoleHeld(context)
            )
        }
    }
}
