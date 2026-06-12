package com.example.lachancuocgoi

import android.Manifest
import android.app.Activity
import android.app.role.RoleManager
import android.content.Context
import android.content.Intent
import android.content.pm.PackageManager
import android.net.Uri
import android.os.Build
import android.os.Bundle
import android.provider.Settings
import android.util.Log
import android.widget.Toast
import androidx.activity.ComponentActivity
import androidx.activity.compose.setContent
import androidx.activity.result.contract.ActivityResultContracts
import androidx.activity.viewModels
import androidx.compose.foundation.isSystemInDarkTheme
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.runtime.*
import androidx.compose.ui.Modifier
import androidx.compose.ui.platform.LocalContext
import androidx.core.content.ContextCompat
import androidx.core.splashscreen.SplashScreen.Companion.installSplashScreen
import androidx.navigation.NavType
import androidx.navigation.compose.NavHost
import androidx.navigation.compose.composable
import androidx.navigation.compose.rememberNavController
import androidx.navigation.navArgument
import com.example.lachancuocgoi.data.AppDatabase
import com.example.lachancuocgoi.ui.HistoryPage.HistoryPage
import com.example.lachancuocgoi.ui.HomePage.HomePage
import com.example.lachancuocgoi.ui.HomePage.InstructDialog.InstructDialog
import com.example.lachancuocgoi.ui.MonitoringPage.MonitoringPage
import com.example.lachancuocgoi.ui.ResultPage.ResultPage
import com.example.lachancuocgoi.ui.HomePage.RightsDialog.RightsDialog
import com.example.lachancuocgoi.ui.HomePage.SettingsDialog.AnalysisMode
import com.example.lachancuocgoi.ui.HomePage.SettingsDialog.SettingsDialog
import com.example.lachancuocgoi.ui.HomePage.SettingsDialog.SettingsState
import com.example.lachancuocgoi.ui.MonitoringPage.Warning.OrangeWarning
import com.example.lachancuocgoi.ui.MonitoringPage.Warning.RedWarning
import com.example.lachancuocgoi.ui.SimulationPage.SimulationPage
import com.example.lachancuocgoi.ui.SimulationPage.SimulationScenarioData
import com.example.lachancuocgoi.ui.TipsLessonPage.TipsLessonPage
import com.example.lachancuocgoi.ui.theme.LachancuocgoiTheme
import com.google.gson.Gson
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import java.net.URLEncoder

class MainActivity : ComponentActivity() {

    private val mainViewModel: MainViewModel by viewModels()

    private val _intentFlow = MutableStateFlow<Intent?>(null)
    private val intentFlow = _intentFlow.asStateFlow()

    private val permissionPrefs by lazy {
        getSharedPreferences("app_permissions", MODE_PRIVATE)
    }

    private val settingsLauncher = registerForActivityResult(ActivityResultContracts.StartActivityForResult()) {}

    private val requestRoleLauncher = registerForActivityResult(ActivityResultContracts.StartActivityForResult()) { result ->
        if (result.resultCode != Activity.RESULT_OK) {
            Toast.makeText(this, "Vui lòng cấp quyền Sàng lọc cuộc gọi thủ công.", Toast.LENGTH_LONG).show()
            openAppSettings()
        }
    }

    private fun openAppSettings() {
        val intent = Intent(Settings.ACTION_APPLICATION_DETAILS_SETTINGS).apply {
            data = Uri.fromParts("package", packageName, null)
        }
        settingsLauncher.launch(intent)
    }

    private val requestPermissionLauncher = registerForActivityResult(ActivityResultContracts.RequestPermission()) { isGranted: Boolean ->
        if (!isGranted) {
            Toast.makeText(this, "Quyền bị từ chối. Vui lòng cấp quyền trong cài đặt.", Toast.LENGTH_LONG).show()
            openAppSettings()
        } else {
            Toast.makeText(this, "Quyền đã được cấp.", Toast.LENGTH_SHORT).show()
        }
    }

    private val requestPhonePermissionsLauncher = registerForActivityResult(ActivityResultContracts.RequestMultiplePermissions()) { permissions ->
        val readPhoneStateGranted = permissions[Manifest.permission.READ_PHONE_STATE] ?: false
        val readCallLogGranted = permissions[Manifest.permission.READ_CALL_LOG] ?: false
        
        if (readPhoneStateGranted && readCallLogGranted) {
            Toast.makeText(this, "Quyền điện thoại đã được cấp", Toast.LENGTH_SHORT).show()
        } else {
            Toast.makeText(this, "Cần quyền điện thoại để phát hiện cuộc gọi", Toast.LENGTH_LONG).show()
            openAppSettings()
        }
    }

    private fun requestCallScreeningRole() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
            val roleManager = getSystemService(ROLE_SERVICE) as? RoleManager
            if (roleManager == null) {
                Log.w(TAG, "RoleManager unavailable; cannot request ROLE_CALL_SCREENING.")
                Toast.makeText(this, "Thiết bị không hỗ trợ Call Screening đầy đủ.", Toast.LENGTH_LONG).show()
                return
            }
            if (!roleManager.isRoleHeld(RoleManager.ROLE_CALL_SCREENING)) {
                val intent = roleManager.createRequestRoleIntent(RoleManager.ROLE_CALL_SCREENING)
                requestRoleLauncher.launch(intent)
            }
        } else {
            Toast.makeText(this, "Tính năng này yêu cầu Android 10 trở lên.", Toast.LENGTH_SHORT).show()
        }
    }

    private fun requestCallLogPermission() {
        requestPhonePermissionsLauncher.launch(
            arrayOf(
                Manifest.permission.READ_PHONE_STATE,
                Manifest.permission.READ_CALL_LOG
            )
        )
    }

    private fun requestRecordAudioPermission() {
        requestPermissionLauncher.launch(Manifest.permission.RECORD_AUDIO)
    }

    private fun requestDrawOverlayPermission() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M && !Settings.canDrawOverlays(this)) {
            val intent = Intent(Settings.ACTION_MANAGE_OVERLAY_PERMISSION, Uri.parse("package:$packageName"))
            settingsLauncher.launch(intent)
        }
    }

    private fun requestNotificationsPermission() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
            requestPermissionLauncher.launch(Manifest.permission.POST_NOTIFICATIONS)
        }
    }

    private fun requestForegroundServicePermission() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.P) {
            requestPermissionLauncher.launch(Manifest.permission.FOREGROUND_SERVICE)
        }
    }

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)

        installSplashScreen().setKeepOnScreenCondition {
            !mainViewModel.isReady.value
        }

        _intentFlow.value = intent
        
        checkAndRequestInitialPermissions()
        
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M && !Settings.canDrawOverlays(this)) {
            requestDrawOverlayPermission()
        }

        setContent {
            val database by mainViewModel.database.collectAsState()
            val db = database

            if (db != null) {
                CallShieldApp(
                    database = db,
                    intentFlow = intentFlow,
                    onIntentHandled = { _intentFlow.value = null },
                    onRequestCallScreening = ::requestCallScreeningRole,
                    onRequestCallLog = ::requestCallLogPermission,
                    onRequestRecordAudio = ::requestRecordAudioPermission,
                    onRequestDrawOverlay = ::requestDrawOverlayPermission,
                    onRequestNotifications = ::requestNotificationsPermission,
                    onRequestForegroundService = ::requestForegroundServicePermission
                )
            }
        }
    }

    private fun checkAndRequestInitialPermissions() {
        val phonePermissionRequested = permissionPrefs.getBoolean(KEY_PHONE_PERMISSION_REQUESTED, false)
        val audioPermissionRequested = permissionPrefs.getBoolean(KEY_AUDIO_PERMISSION_REQUESTED, false)
        val hasPhoneAccess =
            ContextCompat.checkSelfPermission(this, Manifest.permission.READ_PHONE_STATE) == PackageManager.PERMISSION_GRANTED &&
            ContextCompat.checkSelfPermission(this, Manifest.permission.READ_CALL_LOG) == PackageManager.PERMISSION_GRANTED
        
        if (!phonePermissionRequested && !hasPhoneAccess) {
            requestCallLogPermission()
            permissionPrefs.edit().putBoolean(KEY_PHONE_PERMISSION_REQUESTED, true).apply()
        }
        
        if (!audioPermissionRequested &&
            ContextCompat.checkSelfPermission(this, Manifest.permission.RECORD_AUDIO) != PackageManager.PERMISSION_GRANTED) {
            requestRecordAudioPermission()
            permissionPrefs.edit().putBoolean(KEY_AUDIO_PERMISSION_REQUESTED, true).apply()
        }
    }

    override fun onNewIntent(intent: Intent?) {
        super.onNewIntent(intent)
        _intentFlow.value = intent
    }

    companion object {
        private const val TAG = "MainActivity"
        const val ACTION_START_MONITORING = "com.example.lachancuocgoi.ACTION_START_MONITORING"
        const val ACTION_SHOW_RED_ALERT = "com.example.lachancuocgoi.ACTION_SHOW_RED_ALERT"
        const val EXTRA_ALERT_REASON = "com.example.lachancuocgoi.EXTRA_ALERT_REASON"
        const val ACTION_SHOW_ORANGE_ALERT = "com.example.lachancuocgoi.ACTION_SHOW_ORANGE_ALERT"
        const val EXTRA_ORANGE_ALERT_REASON = "com.example.lachancuocgoi.EXTRA_ORANGE_ALERT_REASON"
        
        private const val KEY_PHONE_PERMISSION_REQUESTED = "phone_permission_requested"
        private const val KEY_AUDIO_PERMISSION_REQUESTED = "audio_permission_requested"
    }
}

@Composable
fun CallShieldApp(
    database: AppDatabase,
    intentFlow: StateFlow<Intent?>,
    onIntentHandled: () -> Unit,
    onRequestCallScreening: () -> Unit,
    onRequestCallLog: () -> Unit,
    onRequestRecordAudio: () -> Unit,
    onRequestDrawOverlay: () -> Unit,
    onRequestNotifications: () -> Unit,
    onRequestForegroundService: () -> Unit
) {
    val navController = rememberNavController()
    val systemIsDark = isSystemInDarkTheme()
    val coroutineScope = rememberCoroutineScope()
    val context = LocalContext.current

    val sharedPreferences = remember { context.getSharedPreferences("settings", Context.MODE_PRIVATE) }
    val savedAnalysisMode = remember { sharedPreferences.getString("ANALYSIS_MODE", AnalysisMode.GDetection.name) ?: AnalysisMode.GDetection.name }
    val initialAnalysisMode = remember(savedAnalysisMode) {
        runCatching { AnalysisMode.valueOf(savedAnalysisMode) }
            .getOrElse {
                Log.w("CallShieldApp", "Unknown ANALYSIS_MODE='$savedAnalysisMode', fallback to GDetection.")
                AnalysisMode.GDetection
            }
    }

    var settingsState by remember { mutableStateOf(SettingsState(isDarkTheme = systemIsDark, analysisMode = initialAnalysisMode, audioBoost = false)) }
    var showSettingsDialog by remember { mutableStateOf(false) }
    var showInstructDialog by remember { mutableStateOf(false) }
    var showRightsDialog by remember { mutableStateOf(false) }

    var redAlertReason by remember { mutableStateOf<String?>(null) }
    var orangeAlertReason by remember { mutableStateOf<String?>(null) }

    LaunchedEffect(intentFlow) {
        intentFlow.collect { intent ->
            intent?.let { validIntent ->
                if (validIntent.getBooleanExtra("NAVIGATE_TO_MONITORING", false)) {
                    navController.navigate("monitoring") { launchSingleTop = true }
                    onIntentHandled()
                }
                
                when (validIntent.action) {
                    MainActivity.ACTION_START_MONITORING -> {
                        if (ContextCompat.checkSelfPermission(context, Manifest.permission.RECORD_AUDIO) == PackageManager.PERMISSION_GRANTED) {
                            navController.navigate("monitoring") { launchSingleTop = true }
                        } else {
                            onRequestRecordAudio()
                        }
                        onIntentHandled()
                    }
                    MainActivity.ACTION_SHOW_RED_ALERT -> {
                        redAlertReason = validIntent.getStringExtra(MainActivity.EXTRA_ALERT_REASON)
                        onIntentHandled()
                    }
                    MainActivity.ACTION_SHOW_ORANGE_ALERT -> {
                        orangeAlertReason = validIntent.getStringExtra(MainActivity.EXTRA_ORANGE_ALERT_REASON)
                        onIntentHandled()
                    }
                }
            }
        }
    }

    LachancuocgoiTheme(darkTheme = settingsState.isDarkTheme) {
        Box(modifier = Modifier.fillMaxSize()) {
            NavHost(navController = navController, startDestination = "home") {
                val onShowSettings = { showSettingsDialog = true }
                val onShowInstruct = { showInstructDialog = true }
                val onShowRights = { showRightsDialog = true }

                composable("home") {
                    HomePage(
                        navController = navController,
                        onShowSettings = onShowSettings,
                        onShowSimulation = { navController.navigate("simulation") },
                        onShowInstruct = onShowInstruct,
                        onShowRights = onShowRights,
                        onRequestCallScreeningRole = onRequestCallScreening,
                        onRequestRecordAudio = onRequestRecordAudio
                    )
                }
                composable("simulation") {
                    SimulationPage(
                        onNavigateBack = { navController.popBackStack() },
                        onScenarioSelected = { scenario ->
                            val titleEncoded = URLEncoder.encode(scenario.title, "UTF-8").replace("+", "%20")
                            navController.navigate("monitoring?simulatedScenarioTitle=$titleEncoded")
                        }
                    )
                }
                composable(
                    "monitoring?simulatedScenarioTitle={simulatedScenarioTitle}",
                    arguments = listOf(navArgument("simulatedScenarioTitle") { type = NavType.StringType; nullable = true; defaultValue = null })
                ) { backStackEntry ->
                    val scenarioTitle = backStackEntry.arguments?.getString("simulatedScenarioTitle")
                    
                    MonitoringPage(
                        navController = navController,
                        onShowSettings = onShowSettings,
                        callHistoryDao = database.callHistoryDao(),
                        settingsState = settingsState,
                        simulatedScenarioTitle = scenarioTitle
                    )
                }
                composable(
                    "result/{historyId}",
                    arguments = listOf(navArgument("historyId") { type = NavType.LongType })
                ) { backStackEntry ->
                    ResultPage(
                        navController = navController,
                        onShowSettings = onShowSettings,
                        historyId = backStackEntry.arguments?.getLong("historyId"),
                        callHistoryDao = database.callHistoryDao()
                    )
                }
                composable("history") {
                    HistoryPage(
                        navController = navController,
                        callHistoryDao = database.callHistoryDao(),
                        onShowSettings = onShowSettings,
                        coroutineScope = coroutineScope
                    )
                }
                composable("tips_lesson") {
                    TipsLessonPage(navController = navController)
                }
            }

            if (showSettingsDialog) {
                SettingsDialog(
                    settings = settingsState, 
                    onSettingsChange = { newSettings ->
                        settingsState = newSettings
                        with(sharedPreferences.edit()) {
                            putString("ANALYSIS_MODE", newSettings.analysisMode.name)
                            apply()
                        }
                    },
                    onDismiss = { showSettingsDialog = false }
                )
            }
            if (showInstructDialog) {
                InstructDialog(onDismiss = { showInstructDialog = false })
            }
            if (showRightsDialog) {
                RightsDialog(
                    onDismiss = { showRightsDialog = false },
                    onRequestCallScreening = onRequestCallScreening,
                    onRequestCallLog = onRequestCallLog,
                    onRequestDrawOverlay = onRequestDrawOverlay,
                    onRequestNotifications = onRequestNotifications,
                    onRequestForegroundService = onRequestForegroundService
                )
            }


            redAlertReason?.let { reason ->
                RedWarning(title = reason, onDismiss = { redAlertReason = null })
            }

            orangeAlertReason?.let { reason ->
                OrangeWarning(title = reason, onDismiss = { orangeAlertReason = null })
            }
        }
    }
}
