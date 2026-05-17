package com.example.lachancuocgoi.ui.MonitoringPage

import android.app.Application
import android.app.Activity
import android.content.Context
import android.media.projection.MediaProjectionManager
import android.widget.Toast
import androidx.activity.compose.rememberLauncherForActivityResult
import androidx.activity.result.contract.ActivityResultContracts
import androidx.compose.animation.animateColorAsState
import androidx.compose.animation.core.animateFloatAsState
import androidx.compose.animation.core.tween
import androidx.compose.foundation.horizontalScroll
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.CallEnd
import androidx.compose.material.icons.filled.Settings
import androidx.compose.material3.*
import androidx.compose.runtime.*
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.res.stringResource
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import androidx.lifecycle.viewmodel.compose.viewModel
import androidx.navigation.NavController
import com.example.lachancuocgoi.R
import com.example.lachancuocgoi.RiskLevel
import com.example.lachancuocgoi.data.CallHistoryDao
import com.example.lachancuocgoi.ui.HomePage.SettingsDialog.AnalysisMode
import com.example.lachancuocgoi.ui.HomePage.SettingsDialog.DeveloperModeManager
import com.example.lachancuocgoi.ui.HomePage.SettingsDialog.SettingsState
import com.example.lachancuocgoi.ui.MonitoringPage.Warning.OrangeWarning
import com.example.lachancuocgoi.ui.MonitoringPage.Warning.RedWarning
import com.example.lachancuocgoi.ui.SimulationPage.SimulationScenarioData
import kotlinx.coroutines.flow.collectLatest

@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun MonitoringPage(
    navController: NavController,
    onShowSettings: () -> Unit,
    callHistoryDao: CallHistoryDao,
    settingsState: SettingsState,
    simulatedScenarioTitle: String? = null
) {
    val context = LocalContext.current
    val viewModel: MonitoringViewModel = viewModel(
        factory = MonitoringViewModelFactory(context.applicationContext as Application, callHistoryDao)
    )

    val transcript by viewModel.transcript.collectAsState()
    val amplitudes = viewModel.amplitudes
    val elapsedTime by viewModel.elapsedTime.collectAsState()
    val analysisResult by viewModel.analysisResult.collectAsState()
    val currentAlert by viewModel.currentAlert.collectAsState()
    val effectiveMode by viewModel.effectiveMode.collectAsState()
    val networkAvailable by viewModel.networkAvailable.collectAsState()
    val isFallbackActive by viewModel.isFallbackActive.collectAsState()

    LaunchedEffect(settingsState) {
        viewModel.updateSettings(settingsState)
    }

    // ── Creator Mode: MediaProjection permission (Developer Mode only) ──────────────────────
    // Launcher nhận kết quả từ system dialog "Bắt đầu ghi màn hình?"
    val mediaProjectionManager = remember {
        context.getSystemService(Context.MEDIA_PROJECTION_SERVICE) as MediaProjectionManager
    }
    val projectionLauncher = rememberLauncherForActivityResult(
        contract = ActivityResultContracts.StartActivityForResult()
    ) { result ->
        if (result.resultCode == Activity.RESULT_OK && result.data != null) {
            com.example.lachancuocgoi.services.CreatorMediaProjectionService.onMediaProjectionReady = { projection ->
                viewModel.setMediaProjection(projection)
                // Giờ mới bắt đầu listen (projection đã sẵn)
                if (simulatedScenarioTitle == null) viewModel.startListening()
            }
            val intent = android.content.Intent(context, com.example.lachancuocgoi.services.CreatorMediaProjectionService::class.java).apply {
                action = com.example.lachancuocgoi.services.CreatorMediaProjectionService.ACTION_START
                putExtra("code", result.resultCode)
                putExtra("data", result.data)
            }
            androidx.core.content.ContextCompat.startForegroundService(context, intent)
        } else {
            Toast.makeText(context, "[Dev] Chứa cấp quyền ghi màn hình. Chạy không có audio capture.", Toast.LENGTH_LONG).show()
            if (simulatedScenarioTitle == null) viewModel.startListening() // vẫn chạy bình thường
        }
    }

    LaunchedEffect(key1 = Unit) {
        viewModel.navigationEvent.collectLatest { historyId ->
            if (historyId == -1L) {
                Toast.makeText(context, context.getString(R.string.error_save_call), Toast.LENGTH_SHORT).show()
                navController.navigate("home") { popUpTo("home") { inclusive = true } }
            } else {
                navController.navigate("result/$historyId") {
                    popUpTo("home")
                }
            }
        }
    }

    LaunchedEffect(key1 = simulatedScenarioTitle) {
        if (simulatedScenarioTitle != null) {
            viewModel.loadAndStartSimulation(context, simulatedScenarioTitle)
        } else {
            // Double-check: chỉ request MediaProjection nếu cả 2 điều kiện đúng
            // (1) Developer Mode đang active  VÀ  (2) Setting creatorAudioCapture = true
            val shouldRequestProjection = settingsState.creatorAudioCapture
                && DeveloperModeManager.isDevModeActive()
            if (shouldRequestProjection) {
                // Launch system dialog: "[App] sẽ bắt đầu chụp màn hình"
                projectionLauncher.launch(mediaProjectionManager.createScreenCaptureIntent())
                // startListening() sẽ được gọi trong projectionLauncher callback (ở trên)
            } else {
                viewModel.startListening()
            }
        }
    }

    currentAlert?.let { alert ->
        when (alert.level) {
            RiskLevel.RED -> RedWarning(
                title = alert.reason,
                onDismiss = { viewModel.onDismissAlert() }
            )
            RiskLevel.ORANGE -> OrangeWarning(
                title = alert.reason,
                onDismiss = { viewModel.onDismissAlert() }
            )
            else -> {}
        }
    }

    Scaffold(
        topBar = {
            TopAppBar(
                title = {
                    Column {
                        val title = if (simulatedScenarioTitle != null) stringResource(R.string.simulation_title_prefix, simulatedScenarioTitle) else stringResource(R.string.app_name)
                        Text(title, fontWeight = FontWeight.Bold, style = MaterialTheme.typography.titleMedium)
                        Text(stringResource(R.string.detect_scam_subtitle), style = MaterialTheme.typography.bodySmall)
                    }
                },
                actions = {
                    IconButton(onClick = onShowSettings) {
                        Icon(Icons.Default.Settings, contentDescription = stringResource(R.string.settings_icon_desc))
                    }
                }
            )
        },
        bottomBar = {
            Button(
                onClick = { viewModel.stopListeningAndSave(context) },
                modifier = Modifier
                    .fillMaxWidth()
                    .padding(16.dp),
                shape = RoundedCornerShape(12.dp),
                colors = ButtonDefaults.buttonColors(
                    containerColor = MaterialTheme.colorScheme.error,
                    contentColor = MaterialTheme.colorScheme.onError
                ),
                enabled = true
            ) {
                Row(verticalAlignment = Alignment.CenterVertically) {
                    Icon(Icons.Default.CallEnd, contentDescription = null)
                    Spacer(modifier = Modifier.padding(4.dp))
                    Text(stringResource(R.string.end_call_button), modifier = Modifier.padding(vertical = 8.dp))
                }
            }
        }
    ) { paddingValues ->
        Column(
            modifier = Modifier
                .fillMaxSize()
                .padding(paddingValues)
                .padding(horizontal = 16.dp),
            verticalArrangement = Arrangement.spacedBy(12.dp)
        ) {
            Spacer(modifier = Modifier.height(4.dp))

            Card(
                modifier = Modifier.fillMaxWidth(),
                elevation = CardDefaults.cardElevation(defaultElevation = 2.dp)
            ) {
                Column(modifier = Modifier.padding(16.dp)) {
                    AudioWaveform(
                        amplitudes = amplitudes,
                        elapsedTime = elapsedTime,
                    )
                }
            }

            ElevatedCard(
                modifier = Modifier.fillMaxWidth(),
                elevation = CardDefaults.cardElevation(defaultElevation = 4.dp)
            ) {
                Column(modifier = Modifier.padding(16.dp)) {
                    RiskLevelIndicator(riskLevel = analysisResult.overallRiskLevel)
                    Spacer(modifier = Modifier.height(12.dp))

                    Row(
                        modifier = Modifier
                            .fillMaxWidth()
                            .horizontalScroll(rememberScrollState()),
                        horizontalArrangement = Arrangement.spacedBy(8.dp),
                        verticalAlignment = Alignment.CenterVertically
                    ) {
                        AssistChip(
                            onClick = { },
                            label = { Text("Đích: ${modeLabel(settingsState.analysisMode)}") },
                            colors = AssistChipDefaults.assistChipColors(
                                containerColor = MaterialTheme.colorScheme.surfaceVariant
                            ),
                            border = null
                        )

                        AssistChip(
                            onClick = { },
                            label = { Text("Chạy: ${modeLabel(effectiveMode)}") },
                            colors = AssistChipDefaults.assistChipColors(
                                containerColor = if (isFallbackActive) MaterialTheme.colorScheme.tertiaryContainer else MaterialTheme.colorScheme.secondaryContainer,
                                labelColor = if (isFallbackActive) MaterialTheme.colorScheme.onTertiaryContainer else MaterialTheme.colorScheme.onSecondaryContainer
                            ),
                            border = null
                        )

                        AssistChip(
                            onClick = { },
                            label = { Text(if (networkAvailable) "Mạng: OK" else "Mạng: Lỗi") },
                            colors = AssistChipDefaults.assistChipColors(
                                containerColor = if (networkAvailable) MaterialTheme.colorScheme.surfaceVariant else MaterialTheme.colorScheme.errorContainer,
                                labelColor = if (networkAvailable) MaterialTheme.colorScheme.onSurfaceVariant else MaterialTheme.colorScheme.onErrorContainer
                            ),
                            border = null
                        )
                    }
                }
            }

            Card(
                modifier = Modifier
                    .fillMaxWidth()
                    .weight(1f)
            ) {
                Column(
                    modifier = Modifier
                        .padding(16.dp)
                        .fillMaxSize()
                ) {
                    Text(
                        if (simulatedScenarioTitle != null) stringResource(R.string.simulation_scenario_label) else stringResource(R.string.live_conversation_label),
                        style = MaterialTheme.typography.titleSmall,
                        color = MaterialTheme.colorScheme.onSurfaceVariant
                    )
                    Spacer(modifier = Modifier.height(8.dp))
                    LiveConversation(transcript = transcript, matches = analysisResult.matches)
                }
            }
        }
    }
}

private fun modeLabel(mode: AnalysisMode): String {
    return when (mode) {
        AnalysisMode.NORMAL -> "L1"
        AnalysisMode.GDetection -> "L2"
        AnalysisMode.GEMINI_API -> "L3"
    }
}

@Composable
fun RiskLevelIndicator(riskLevel: RiskLevel) {
    val targetProgress = riskLevel.ordinal.toFloat() / (RiskLevel.entries.size - 1).toFloat()

    val animatedProgress by animateFloatAsState(
        targetValue = targetProgress,
        animationSpec = tween(durationMillis = 800),
        label = "progress_animation"
    )
    val animatedColor by animateColorAsState(
        targetValue = riskLevel.color,
        animationSpec = tween(durationMillis = 800),
        label = "color_animation"
    )

    Column(modifier = Modifier.fillMaxWidth()) {
        Row(
            modifier = Modifier.fillMaxWidth(),
            horizontalArrangement = Arrangement.SpaceBetween,
            verticalAlignment = Alignment.CenterVertically
        ) {
            Text(stringResource(R.string.risk_level_label), style = MaterialTheme.typography.titleMedium, fontWeight = FontWeight.Bold)
            Text(
                text = riskLevel.vietnameseName,
                style = MaterialTheme.typography.titleMedium,
                fontWeight = FontWeight.Bold,
                color = animatedColor
            )
        }
        Spacer(modifier = Modifier.height(8.dp))
        LinearProgressIndicator(
            progress = { animatedProgress },
            modifier = Modifier
                .fillMaxWidth()
                .height(8.dp),
            color = animatedColor,
            trackColor = MaterialTheme.colorScheme.surfaceVariant
        )
    }
}