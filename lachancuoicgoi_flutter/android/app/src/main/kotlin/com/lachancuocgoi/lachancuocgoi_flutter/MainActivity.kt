package com.lachancuocgoi.lachancuocgoi_flutter

import android.Manifest
import android.accessibilityservice.AccessibilityServiceInfo
import android.app.role.RoleManager
import android.content.Context
import android.content.Intent
import android.content.pm.PackageManager
import android.media.projection.MediaProjectionManager
import android.os.Build
import android.provider.Settings
import android.util.Log
import android.view.accessibility.AccessibilityManager
import android.widget.Toast
import androidx.annotation.NonNull
import androidx.core.content.ContextCompat
import com.lachancuocgoi.lachancuocgoi_flutter.audio.CreatorAudioCaptureManager
import com.lachancuocgoi.lachancuocgoi_flutter.services.BackgroundMonitoringService
import com.lachancuocgoi.lachancuocgoi_flutter.services.CreatorMediaProjectionService
import com.lachancuocgoi.lachancuocgoi_flutter.services.NativeBridgeEventSink
import com.lachancuocgoi.lachancuocgoi_flutter.ui.OverlayManager
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {

    companion object {
        private const val TAG = "MainActivity"
        private const val METHOD_CHANNEL = "com.lachancuocgoi/native_bridge"
        private const val TRANSCRIPT_CHANNEL = "com.lachancuocgoi/transcript_stream"
        private const val RMS_CHANNEL = "com.lachancuocgoi/rms_stream"
        private const val MONITORING_STATE_CHANNEL = "com.lachancuocgoi/monitoring_state"
        private const val CALL_EVENT_CHANNEL = "com.lachancuocgoi/call_events"
        private const val REQUEST_CALL_SCREENING_ROLE = 1001
        private const val REQUEST_CREATOR_PROJECTION = 1002
        private const val REQUEST_PHONE_PERMISSIONS = 1003
    }

    private var pendingPhonePermissionResult: MethodChannel.Result? = null
    private var pendingCreatorMonitoringResult: MethodChannel.Result? = null
    private var pendingCreatorDevModeExpiresAtMs: Long = 0L

    override fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?) {
        if (requestCode == REQUEST_CREATOR_PROJECTION) {
            handleCreatorProjectionResult(resultCode, data)
            return
        }
        super.onActivityResult(requestCode, resultCode, data)
    }

    private fun handleCreatorProjectionResult(resultCode: Int, data: Intent?) {
        val result = pendingCreatorMonitoringResult
        val devModeExpiresAtMs = pendingCreatorDevModeExpiresAtMs
        pendingCreatorMonitoringResult = null
        pendingCreatorDevModeExpiresAtMs = 0L

        if (resultCode == RESULT_OK && data != null) {
            val intent = Intent(this, CreatorMediaProjectionService::class.java).apply {
                action = CreatorMediaProjectionService.ACTION_START
                putExtra("code", resultCode)
                putExtra("data", data)
                putExtra("devModeExpiresAtMs", devModeExpiresAtMs)
            }
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                startForegroundService(intent)
            } else {
                startService(intent)
            }
            result?.success(true)
        } else {
            Toast.makeText(
                this,
                "Bạn cần cấp quyền ghi màn hình để bật Creator Mode.",
                Toast.LENGTH_LONG
            ).show()
            result?.success(false)
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
                    grantedMap[Manifest.permission.READ_CALL_LOG] == PackageManager.PERMISSION_GRANTED
            pendingPhonePermissionResult?.success(granted)
            pendingPhonePermissionResult = null
            return
        }
        super.onRequestPermissionsResult(requestCode, permissions, grantResults)
    }

    override fun configureFlutterEngine(@NonNull flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        // MethodChannel
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, METHOD_CHANNEL)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "startMonitoring" -> {
                        val phoneNumber = call.argument<String>("phoneNumber")
                        val enableSpeakerphone = call.argument<Boolean>("enableSpeakerphone") ?: false
                        startMonitoringService(phoneNumber, enableSpeakerphone)
                        result.success(true)
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
                        // Check if BackgroundMonitoringService is running
                        result.success(isServiceRunning(BackgroundMonitoringService::class.java))
                    }
                    "isCreatorMonitoringActive" -> {
                        result.success(isServiceRunning(CreatorMediaProjectionService::class.java))
                    }
                    else -> {
                        result.notImplemented()
                    }
                }
            }

        // EventChannel: Transcript stream
        EventChannel(flutterEngine.dartExecutor.binaryMessenger, TRANSCRIPT_CHANNEL)
            .setStreamHandler(object : EventChannel.StreamHandler {
                override fun onListen(arguments: Any?, events: EventChannel.EventSink?) {
                    NativeBridgeEventSink.transcriptSink = events
                    val currentCreatorTranscript =
                        CreatorAudioCaptureManager.creatorTranscriptFlow.value
                    if (currentCreatorTranscript.isNotBlank()) {
                        events?.success(currentCreatorTranscript)
                    }
                }
                override fun onCancel(arguments: Any?) {
                    NativeBridgeEventSink.transcriptSink = null
                }
            })

        // EventChannel: RMS stream
        EventChannel(flutterEngine.dartExecutor.binaryMessenger, RMS_CHANNEL)
            .setStreamHandler(object : EventChannel.StreamHandler {
                override fun onListen(arguments: Any?, events: EventChannel.EventSink?) {
                    NativeBridgeEventSink.rmsSink = events
                }
                override fun onCancel(arguments: Any?) {
                    NativeBridgeEventSink.rmsSink = null
                }
            })

        // EventChannel: Monitoring state
        EventChannel(flutterEngine.dartExecutor.binaryMessenger, MONITORING_STATE_CHANNEL)
            .setStreamHandler(object : EventChannel.StreamHandler {
                override fun onListen(arguments: Any?, events: EventChannel.EventSink?) {
                    NativeBridgeEventSink.monitoringStateSink = events
                    if (isServiceRunning(CreatorMediaProjectionService::class.java) ||
                        isServiceRunning(BackgroundMonitoringService::class.java)
                    ) {
                        events?.success("STARTED")
                    }
                }
                override fun onCancel(arguments: Any?) {
                    NativeBridgeEventSink.monitoringStateSink = null
                }
            })

        // EventChannel: Call events
        EventChannel(flutterEngine.dartExecutor.binaryMessenger, CALL_EVENT_CHANNEL)
            .setStreamHandler(object : EventChannel.StreamHandler {
                override fun onListen(arguments: Any?, events: EventChannel.EventSink?) {
                    NativeBridgeEventSink.callEventSink = events
                }
                override fun onCancel(arguments: Any?) {
                    NativeBridgeEventSink.callEventSink = null
                }
            })
    }

    private fun startMonitoringService(phoneNumber: String?, enableSpeakerphone: Boolean) {
        val intent = Intent(this, BackgroundMonitoringService::class.java).apply {
            action = BackgroundMonitoringService.ACTION_START
            phoneNumber?.let { putExtra("PHONE_NUMBER", it) }
            putExtra("ENABLE_SPEAKERPHONE", enableSpeakerphone)
        }
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            startForegroundService(intent)
        } else {
            startService(intent)
        }
        Log.d(TAG, "Started BackgroundMonitoringService")
    }

    private fun stopMonitoringService() {
        val intent = Intent(this, BackgroundMonitoringService::class.java).apply {
            action = BackgroundMonitoringService.ACTION_STOP
        }
        // Always use startService for ACTION_STOP because we don't want a new foreground notification
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
        if (devModeExpiresAtMs <= System.currentTimeMillis()) {
            result.success(false)
            return
        }
        if (isServiceRunning(CreatorMediaProjectionService::class.java)) {
            result.success(true)
            return
        }
        pendingCreatorMonitoringResult = result
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

        if (hasPhoneState && hasCallLog) {
            result.success(true)
            return
        }

        pendingPhonePermissionResult = result
        requestPermissions(
            arrayOf(
                Manifest.permission.READ_PHONE_STATE,
                Manifest.permission.READ_CALL_LOG,
            ),
            REQUEST_PHONE_PERMISSIONS
        )
    }

    private fun getPermissionSnapshot(): Map<String, Boolean> {
        return mapOf(
            "recordAudio" to (checkSelfPermission(android.Manifest.permission.RECORD_AUDIO) == android.content.pm.PackageManager.PERMISSION_GRANTED),
            "phoneState" to (checkSelfPermission(android.Manifest.permission.READ_PHONE_STATE) == android.content.pm.PackageManager.PERMISSION_GRANTED),
            "callLog" to (checkSelfPermission(android.Manifest.permission.READ_CALL_LOG) == android.content.pm.PackageManager.PERMISSION_GRANTED),
            "overlay" to Settings.canDrawOverlays(this),
            "notification" to hasNotificationPermission(),
            "accessibility" to isAccessibilityServiceEnabled(),
            "callScreening" to isCallScreeningRoleHeld(),
        )
    }

    private fun hasNotificationPermission(): Boolean {
        return if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
            checkSelfPermission(android.Manifest.permission.POST_NOTIFICATIONS) == android.content.pm.PackageManager.PERMISSION_GRANTED
        } else {
            true // Notifications always allowed before API 33
        }
    }

    private fun isAccessibilityServiceEnabled(): Boolean {
        val am = getSystemService(Context.ACCESSIBILITY_SERVICE) as AccessibilityManager
        val enabledServices = am.getEnabledAccessibilityServiceList(AccessibilityServiceInfo.FEEDBACK_ALL_MASK)
        for (service in enabledServices) {
            if (service.resolveInfo.serviceInfo.packageName == packageName) {
                return true
            }
        }
        return false
    }

    private fun isCallScreeningRoleHeld(): Boolean {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
            val roleManager = getSystemService(Context.ROLE_SERVICE) as RoleManager
            return roleManager.isRoleHeld(RoleManager.ROLE_CALL_SCREENING)
        }
        return false
    }

    @Suppress("DEPRECATION")
    private fun isServiceRunning(serviceClass: Class<*>): Boolean {
        val manager = getSystemService(Context.ACTIVITY_SERVICE) as android.app.ActivityManager
        for (service in manager.getRunningServices(Int.MAX_VALUE)) {
            if (serviceClass.name == service.service.className) {
                return true
            }
        }
        return false
    }
}
