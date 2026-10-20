package com.lachancuocgoi.lachancuocgoi_flutter

import android.Manifest
import android.accessibilityservice.AccessibilityServiceInfo
import android.app.role.RoleManager
import android.content.Context
import android.content.Intent
import android.content.pm.PackageManager
import android.media.projection.MediaProjectionManager
import android.os.Build
import android.os.Bundle
import android.provider.Settings
import android.util.Log
import android.view.accessibility.AccessibilityManager
import android.widget.Toast
import androidx.core.content.ContextCompat
import com.lachancuocgoi.lachancuocgoi_flutter.services.BackgroundMonitoringService
import com.lachancuocgoi.lachancuocgoi_flutter.services.CallScreeningPreferences
import com.lachancuocgoi.lachancuocgoi_flutter.services.CreatorMediaProjectionService
import com.lachancuocgoi.lachancuocgoi_flutter.services.ForegroundServiceLauncher
import com.lachancuocgoi.lachancuocgoi_flutter.services.MonitoringStartResponse
import com.lachancuocgoi.lachancuocgoi_flutter.services.MonitoringStartCoordinator
import com.lachancuocgoi.lachancuocgoi_flutter.services.MonitoringStartStatus
import com.lachancuocgoi.lachancuocgoi_flutter.services.MonitoringPreferences
import com.lachancuocgoi.lachancuocgoi_flutter.services.NativeBridgeEventSink
import com.lachancuocgoi.lachancuocgoi_flutter.services.NativeBridgeChannels
import com.lachancuocgoi.lachancuocgoi_flutter.services.NativeCallEvent
import com.lachancuocgoi.lachancuocgoi_flutter.services.PendingResult
import com.lachancuocgoi.lachancuocgoi_flutter.ui.OverlayManager
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {

    companion object {
        private const val TAG = "MainActivity"
        private const val TEST_REQUEST_PHONE_PERMISSIONS_ACTION = "TEST_REQUEST_PHONE_PERMISSIONS"
        private const val REQUEST_CALL_SCREENING_ROLE = 1001
        private const val REQUEST_CREATOR_PROJECTION = 1002
        private const val REQUEST_PHONE_PERMISSIONS = 1003
    }

    private val pendingPhonePermissionResult = PendingResult()
    private val pendingCreatorMonitoringResult = PendingResult()
    private var pendingCreatorDevModeExpiresAtMs: Long = 0L

    override fun provideFlutterEngine(context: Context): FlutterEngine =
        (application as MainApplication).ensureFlutterEngine()

    override fun shouldDestroyEngineWithHost(): Boolean = false

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        maybeHandleDebugIntent(intent)
        handleCallIntent(intent)
    }

    override fun onDestroy() {

        pendingPhonePermissionResult.cancel()
        pendingCreatorMonitoringResult.cancel()
        MonitoringStartCoordinator.cancel()

        (application as? MainApplication)?.existingFlutterEngine()?.let { engine ->
            NativeBridgeChannels.installBackgroundMethodHandler(applicationContext, engine)
        }
        super.onDestroy()
    }

    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        setIntent(intent)
        maybeHandleDebugIntent(intent)
        handleCallIntent(intent)
    }

    override fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?) {
        if (requestCode == REQUEST_CREATOR_PROJECTION) {
            handleCreatorProjectionResult(resultCode, data)
            return
        }
        if (requestCode == REQUEST_CALL_SCREENING_ROLE) {

            refreshPermissionSnapshot()
            return
        }
        super.onActivityResult(requestCode, resultCode, data)
    }

    private fun maybeHandleDebugIntent(intent: Intent?) {
        if (!BuildConfig.DEBUG || intent?.action != TEST_REQUEST_PHONE_PERMISSIONS_ACTION) {
            return
        }
        requestPhoneAndCallLogPermissionsForDebugIntent()
    }

    private fun requestPhoneAndCallLogPermissionsForDebugIntent() {
        val hasPhoneState =
            ContextCompat.checkSelfPermission(this, Manifest.permission.READ_PHONE_STATE) ==
                PackageManager.PERMISSION_GRANTED
        val hasCallLog =
            ContextCompat.checkSelfPermission(this, Manifest.permission.READ_CALL_LOG) ==
                PackageManager.PERMISSION_GRANTED
        val canAnswerCalls =
            ContextCompat.checkSelfPermission(this, Manifest.permission.ANSWER_PHONE_CALLS) ==
                PackageManager.PERMISSION_GRANTED

        if (hasPhoneState && hasCallLog && canAnswerCalls) {
            return
        }

        requestPermissions(
            arrayOf(
                Manifest.permission.READ_PHONE_STATE,
                Manifest.permission.READ_CALL_LOG,
                Manifest.permission.ANSWER_PHONE_CALLS,
            ),
            REQUEST_PHONE_PERMISSIONS
        )
    }

    private fun handleCreatorProjectionResult(resultCode: Int, data: Intent?) {
        val devModeExpiresAtMs = pendingCreatorDevModeExpiresAtMs
        pendingCreatorDevModeExpiresAtMs = 0L

        if (resultCode == RESULT_OK && data != null) {
            val intent = Intent(this, CreatorMediaProjectionService::class.java).apply {
                action = CreatorMediaProjectionService.ACTION_START
                putExtra("code", resultCode)
                putExtra("data", data)
                putExtra("devModeExpiresAtMs", devModeExpiresAtMs)
            }
            val launchResult = safeStartForegroundService(intent)
            val accepted = launchResult == ForegroundServiceLauncher.LaunchResult.SUCCESS
            if (!accepted) CreatorMediaProjectionService.isRunning = false
            pendingCreatorMonitoringResult.success(accepted)
        } else {
            Toast.makeText(
                this,
                "Bạn cần cấp quyền ghi màn hình để bật Creator Mode.",
                Toast.LENGTH_LONG
            ).show()
            pendingCreatorMonitoringResult.success(false)
        }
    }

    override fun onRequestPermissionsResult(
        requestCode: Int,
        permissions: Array<out String>,
        grantResults: IntArray
    ) {
        if (requestCode == REQUEST_PHONE_PERMISSIONS) {
            val grantedMap = permissions.zip(grantResults.toTypedArray()).toMap()
            val granted =
                grantedMap[Manifest.permission.READ_PHONE_STATE] == PackageManager.PERMISSION_GRANTED &&
                    grantedMap[Manifest.permission.READ_CALL_LOG] == PackageManager.PERMISSION_GRANTED &&
                    grantedMap[Manifest.permission.ANSWER_PHONE_CALLS] == PackageManager.PERMISSION_GRANTED

            pendingPhonePermissionResult.success(granted)
            return
        }
        super.onRequestPermissionsResult(requestCode, permissions, grantResults)
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            NativeBridgeChannels.METHOD_CHANNEL,
        )
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "startMonitoring" -> {
                        val enableSpeakerphone = call.argument<Boolean>("enableSpeakerphone") ?: false
                        startMonitoringService(enableSpeakerphone, result)
                    }
                    "stopMonitoring" -> {
                        stopMonitoringService()
                        result.success(true)
                    }
                    "startCreatorMonitoring" -> {
                        val devModeExpiresAtMs =
                            call.argument<Number>("devModeExpiresAtMs")?.toLong() ?: 0L
                        startCreatorMonitoring(result, devModeExpiresAtMs)
                    }
                    "stopCreatorMonitoring" -> {
                        stopCreatorMonitoringService()
                        result.success(true)
                    }
                    "showRedAlert" -> {
                        val reason = call.argument<String>("reason") ?: "Rủi ro cao!"
                        OverlayManager.showRedAlert(applicationContext, reason)
                        result.success(true)
                    }
                    "showOrangeAlert" -> {
                        val reason = call.argument<String>("reason") ?: "Rủi ro trung bình!"
                        OverlayManager.showOrangeAlert(applicationContext, reason)
                        result.success(true)
                    }
                    "dismissAlert" -> {
                        OverlayManager.removeAlertOverlay(applicationContext)
                        result.success(true)
                    }
                    "showIncomingCallOverlay" -> {

                        result.success(false)
                    }
                    "dismissIncomingCallOverlay" -> {
                        result.success(true)
                    }
                    "getPermissionSnapshot" -> {
                        result.success(getPermissionSnapshot())
                    }
                    "openAccessibilitySettings" -> {
                        val intent = Intent(Settings.ACTION_ACCESSIBILITY_SETTINGS)
                        intent.flags = Intent.FLAG_ACTIVITY_NEW_TASK
                        startActivity(intent)
                        result.success(true)
                    }
                    "requestCallScreeningRole" -> {
                        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
                            val roleManager = getSystemService(Context.ROLE_SERVICE) as RoleManager
                            if (roleManager.isRoleAvailable(RoleManager.ROLE_CALL_SCREENING)) {
                                val intent = roleManager.createRequestRoleIntent(RoleManager.ROLE_CALL_SCREENING)
                                startActivityForResult(intent, REQUEST_CALL_SCREENING_ROLE)
                                result.success(true)
                            } else {
                                result.success(false)
                            }
                        } else {
                            result.success(false)
                        }
                    }
                    "requestPhoneAndCallLogPermissions" -> {
                        requestPhoneAndCallLogPermissions(result)
                    }
                    "checkOverlayPermission" -> {
                        result.success(Settings.canDrawOverlays(this))
                    }
                    "requestOverlayPermission" -> {
                        if (!Settings.canDrawOverlays(this)) {
                            val intent = Intent(
                                Settings.ACTION_MANAGE_OVERLAY_PERMISSION,
                                android.net.Uri.parse("package:$packageName")
                            )
                            intent.flags = Intent.FLAG_ACTIVITY_NEW_TASK
                            startActivity(intent)
                        }
                        result.success(true)
                    }
                    "isAccessibilityEnabled" -> {
                        result.success(isAccessibilityServiceEnabled())
                    }
                    "isMonitoringActive" -> {

                        result.success(isServiceRunning(BackgroundMonitoringService::class.java))
                    }
                    "isCreatorMonitoringActive" -> {
                        result.success(isServiceRunning(CreatorMediaProjectionService::class.java))
                    }

                    "setCallScreeningBlockEnabled" -> {
                        val enabled = call.argument<Boolean>("enabled") ?: false
                        val prefs = getSharedPreferences(
                            CallScreeningPreferences.PREFS_NAME, MODE_PRIVATE
                        )
                        prefs.edit().putBoolean(
                            CallScreeningPreferences.KEY_BLOCK_ENABLED, enabled
                        ).apply()
                        result.success(true)
                    }
                    "setBlockedNumbers" -> {
                        val numbers = call.argument<List<String>>("numbers") ?: emptyList()
                        val prefs = getSharedPreferences(
                            CallScreeningPreferences.PREFS_NAME, MODE_PRIVATE
                        )
                        prefs.edit().putStringSet(
                            CallScreeningPreferences.KEY_BLOCKED_NUMBERS,
                            numbers.toSet()
                        ).apply()
                        result.success(true)
                    }
                    "setAnalysisMode" -> {
                        val mode = call.argument<String>("mode").orEmpty()
                        MonitoringPreferences.writeAnalysisMode(applicationContext, mode)
                        result.success(true)
                    }
                    "setAutoEnableSpeakerphone" -> {
                        val enabled = call.argument<Boolean>("enabled") ?: true
                        MonitoringPreferences.writeAutoEnableSpeakerphone(
                            applicationContext,
                            enabled,
                        )
                        result.success(true)
                    }
                    else -> {
                        result.notImplemented()
                    }
                }
            }

        NativeBridgeChannels.registerEventChannels(applicationContext, flutterEngine)
    }

    private fun startMonitoringService(enableSpeakerphone: Boolean): MonitoringStartResponse {
        if (BackgroundMonitoringService.isRunning) {
            return MonitoringStartResponse(
                MonitoringStartStatus.ALREADY_RUNNING,
                "Dịch vụ giám sát đang hoạt động.",
            )
        }
        if (ContextCompat.checkSelfPermission(this, Manifest.permission.RECORD_AUDIO) !=
            PackageManager.PERMISSION_GRANTED
        ) {
            return MonitoringStartResponse(
                MonitoringStartStatus.PERMISSION_DENIED,
                "Cần cấp quyền micro để bắt đầu giám sát.",
            )
        }

        val intent = Intent(this, BackgroundMonitoringService::class.java).apply {
            action = BackgroundMonitoringService.ACTION_START
            putExtra("ENABLE_SPEAKERPHONE", enableSpeakerphone)
        }
        val launchResult = safeStartForegroundService(intent)
        return when (launchResult) {
            ForegroundServiceLauncher.LaunchResult.SUCCESS -> {
                Log.d(TAG, "BackgroundMonitoringService start request accepted")
                MonitoringStartResponse(
                    MonitoringStartStatus.STARTED,
                    "Đã gửi yêu cầu bắt đầu giám sát.",
                )
            }
            ForegroundServiceLauncher.LaunchResult.NOT_ALLOWED -> MonitoringStartResponse(
                MonitoringStartStatus.BACKGROUND_START_DENIED,
                "Android không cho phép khởi động dịch vụ từ nền.",
            )
            ForegroundServiceLauncher.LaunchResult.SECURITY_DENIED -> MonitoringStartResponse(
                MonitoringStartStatus.PERMISSION_DENIED,
                "Không đủ quyền để khởi động dịch vụ giám sát.",
            )
            ForegroundServiceLauncher.LaunchResult.UNKNOWN_ERROR -> MonitoringStartResponse(
                MonitoringStartStatus.NATIVE_FAILURE,
                "Không thể khởi động dịch vụ giám sát.",
            )
        }
    }

    private fun startMonitoringService(
        enableSpeakerphone: Boolean,
        result: MethodChannel.Result,
    ) {
        if (BackgroundMonitoringService.isRunning) {
            result.success(
                MonitoringStartResponse(
                    MonitoringStartStatus.ALREADY_RUNNING,
                    "Dịch vụ giám sát đang hoạt động.",
                ).toMap()
            )
            return
        }
        if (ContextCompat.checkSelfPermission(this, Manifest.permission.RECORD_AUDIO) !=
            PackageManager.PERMISSION_GRANTED
        ) {
            result.success(
                MonitoringStartResponse(
                    MonitoringStartStatus.PERMISSION_DENIED,
                    "Cần cấp quyền micro để bắt đầu giám sát.",
                ).toMap()
            )
            return
        }
        if (!MonitoringStartCoordinator.begin(result)) {
            result.success(
                MonitoringStartResponse(
                    MonitoringStartStatus.ALREADY_RUNNING,
                    "Yêu cầu khởi động giám sát đang được xử lý.",
                ).toMap()
            )
            return
        }

        val launchResponse = startMonitoringService(enableSpeakerphone)

        if (launchResponse.status != MonitoringStartStatus.STARTED) {
            MonitoringStartCoordinator.complete(launchResponse)
        }
    }

    private fun handleCallIntent(intent: Intent?) {
        NativeCallEvent.fromActivityIntent(intent)?.let { event ->
            NativeBridgeEventSink.sendCallEvent(event.toMap())
        }
    }

    private fun stopMonitoringService() {
        val intent = Intent(this, BackgroundMonitoringService::class.java).apply {
            action = BackgroundMonitoringService.ACTION_STOP
        }

        startService(intent)
        Log.d(TAG, "Stopped BackgroundMonitoringService")
    }

    private fun stopCreatorMonitoringService() {
        if (!isServiceRunning(CreatorMediaProjectionService::class.java)) {
            Log.d(TAG, "CreatorMediaProjectionService is not running")
            return
        }
        val intent = Intent(this, CreatorMediaProjectionService::class.java).apply {
            action = CreatorMediaProjectionService.ACTION_STOP
        }
        startService(intent)
        Log.d(TAG, "Stopped CreatorMediaProjectionService")
    }

    private fun startCreatorMonitoring(result: MethodChannel.Result, devModeExpiresAtMs: Long) {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.Q) {
            result.success(false)
            return
        }
        if (ContextCompat.checkSelfPermission(this, Manifest.permission.RECORD_AUDIO) !=
            PackageManager.PERMISSION_GRANTED
        ) {
            result.success(false)
            return
        }
        if (devModeExpiresAtMs <= System.currentTimeMillis()) {
            result.success(false)
            return
        }
        if (isServiceRunning(CreatorMediaProjectionService::class.java)) {
            result.success(true)
            return
        }

        pendingCreatorMonitoringResult.set(result)
        pendingCreatorDevModeExpiresAtMs = devModeExpiresAtMs
        val projectionManager =
            getSystemService(Context.MEDIA_PROJECTION_SERVICE) as MediaProjectionManager
        startActivityForResult(
            projectionManager.createScreenCaptureIntent(),
            REQUEST_CREATOR_PROJECTION
        )
    }

    private fun requestPhoneAndCallLogPermissions(result: MethodChannel.Result) {
        val hasPhoneState =
            ContextCompat.checkSelfPermission(this, Manifest.permission.READ_PHONE_STATE) ==
                PackageManager.PERMISSION_GRANTED
        val hasCallLog =
            ContextCompat.checkSelfPermission(this, Manifest.permission.READ_CALL_LOG) ==
                PackageManager.PERMISSION_GRANTED
        val canAnswerCalls =
            ContextCompat.checkSelfPermission(this, Manifest.permission.ANSWER_PHONE_CALLS) ==
                PackageManager.PERMISSION_GRANTED

        if (hasPhoneState && hasCallLog && canAnswerCalls) {
            result.success(true)
            return
        }

        pendingPhonePermissionResult.set(result)
        requestPermissions(
            arrayOf(
                Manifest.permission.READ_PHONE_STATE,
                Manifest.permission.READ_CALL_LOG,
                Manifest.permission.ANSWER_PHONE_CALLS,
            ),
            REQUEST_PHONE_PERMISSIONS
        )
    }

    private fun getPermissionSnapshot(): Map<String, Boolean> {
        return com.lachancuocgoi.lachancuocgoi_flutter.helpers.PermissionHelpers.getPermissionSnapshot(this)
    }

    private fun hasNotificationPermission(): Boolean {
        return com.lachancuocgoi.lachancuocgoi_flutter.helpers.PermissionHelpers.hasNotificationPermission(this)
    }

    private fun isAccessibilityServiceEnabled(): Boolean {
        return com.lachancuocgoi.lachancuocgoi_flutter.helpers.PermissionHelpers.isAccessibilityServiceEnabled(this)
    }

    private fun isCallScreeningRoleHeld(): Boolean {
        return com.lachancuocgoi.lachancuocgoi_flutter.helpers.PermissionHelpers.isCallScreeningRoleHeld(this)
    }

    private fun isServiceRunning(serviceClass: Class<*>): Boolean {

        return serviceRunningCheckers[serviceClass]?.invoke() ?: false
    }

    private val serviceRunningCheckers: Map<Class<*>, () -> Boolean> = mapOf(
        BackgroundMonitoringService::class.java to { BackgroundMonitoringService.isRunning },
        CreatorMediaProjectionService::class.java to { CreatorMediaProjectionService.isRunning },
    )

    private fun Context.safeStartForegroundService(intent: Intent): ForegroundServiceLauncher.LaunchResult {
        val result = ForegroundServiceLauncher.safeStartForegroundService(this, intent)
        if (result == ForegroundServiceLauncher.LaunchResult.NOT_ALLOWED) {
            Log.w(TAG, "ForegroundService not allowed — app is in background. Caller should handle this.")
        }
        return result
    }

    private fun refreshPermissionSnapshot() {
        val snapshot = getPermissionSnapshot()
        NativeBridgeEventSink.sendCallEvent(
            mapOf(
                "type" to "PERMISSION_SNAPSHOT",
                "permissions" to snapshot,
            )
        )
    }
}

