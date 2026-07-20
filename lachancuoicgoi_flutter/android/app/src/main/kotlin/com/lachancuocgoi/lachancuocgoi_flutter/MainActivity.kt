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

    // Bug #1, #23 fix: replace raw MethodChannel.Result? fields with PendingResult
    // helpers that auto-clear in onDestroy and never fire twice. See services/PendingResult.kt.
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
        // Bug #1, #23 fix: clear pending results so they never leak across
        // Activity destruction (e.g. config change while permission dialog is up).
        pendingPhonePermissionResult.cancel()
        pendingCreatorMonitoringResult.cancel()
        MonitoringStartCoordinator.cancel()
        // Read the process-owned engine directly. This remains safe if Android
        // destroys a partially-created Activity whose Flutter delegate was
        // never initialized.
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
            // Bug #4 fix: when the user returns from the system role-picker
            // dialog, refresh the permission snapshot so Flutter UI reflects
            // the actual state. Without this, the UI would stay "not granted"
            // until the user manually relaunched the page.
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
            // Bug #23 fix: idempotent — calling success multiple times is safe,
            // and if the Activity was destroyed, cancel() in onDestroy already
            // cleared the pending result so this is a safe no-op.
            pendingPhonePermissionResult.success(granted)
            return
        }
        super.onRequestPermissionsResult(requestCode, permissions, grantResults)
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        // MethodChannel
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
                        // Legacy API intentionally disabled: incoming consent
                        // is notification-only and must never open an overlay.
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
                        // Check if BackgroundMonitoringService is running
                        result.success(isServiceRunning(BackgroundMonitoringService::class.java))
                    }
                    "isCreatorMonitoringActive" -> {
                        result.success(isServiceRunning(CreatorMediaProjectionService::class.java))
                    }
                    // Phase 2 (P2-4): call screening opt-in bridge methods.
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

        // EventChannels are registered once by MainApplication so transcript,
        // RMS, call, and monitoring events remain connected without an Activity.
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
        // STARTED here means only that Android accepted the asynchronous
        // service request. The service completes that response after it has
        // successfully promoted itself and entered the active state.
        if (launchResponse.status != MonitoringStartStatus.STARTED) {
            MonitoringStartCoordinator.complete(launchResponse)
        }
    }

    /** Use one parser for both the initial Activity intent and onNewIntent. */
    private fun handleCallIntent(intent: Intent?) {
        NativeCallEvent.fromActivityIntent(intent)?.let { event ->
            NativeBridgeEventSink.sendCallEvent(event.toMap())
        }
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
        // Bug #1 fix: PendingResult.set() auto-times out after 30s, preventing
        // Flutter-side deadlock if the MediaProjection dialog is dismissed.
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

        // Bug #23 fix: idempotent wrapper — auto-clears in onDestroy().
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
        // Bug #26 fix: was O(n) `firstOrNull` over a `Map<KClass, ...>` —
        // switch to direct `Class<*>` lookup, O(1).
        return serviceRunningCheckers[serviceClass]?.invoke() ?: false
    }

    /**
     * Map of [Class] → predicate. Add a new entry here when introducing a
     * new foreground service. The predicate should return the service's
     * `isRunning` flag so the bridge can answer `isXxxActive` queries
     * without using the deprecated `ActivityManager.getRunningServices`.
     */
    private val serviceRunningCheckers: Map<Class<*>, () -> Boolean> = mapOf(
        BackgroundMonitoringService::class.java to { BackgroundMonitoringService.isRunning },
        CreatorMediaProjectionService::class.java to { CreatorMediaProjectionService.isRunning },
    )

    /**
     * Bug #2 / #8 helper: wrap [Context.startForegroundService] with the
     * `ForegroundServiceLauncher.safeStartForegroundService` catch-all so
     * we never crash on Android 12+ `ForegroundServiceStartNotAllowedException`.
     *
     * On [ForegroundServiceLauncher.LaunchResult.NOT_ALLOWED], we do NOT
     * fall back to `startService()` — that would start a background service
     * that gets killed within 5s (Android 12+ background execution limits).
     * Instead, we log a warning and let the caller decide what to do.
     */
    private fun Context.safeStartForegroundService(intent: Intent): ForegroundServiceLauncher.LaunchResult {
        val result = ForegroundServiceLauncher.safeStartForegroundService(this, intent)
        if (result == ForegroundServiceLauncher.LaunchResult.NOT_ALLOWED) {
            Log.w(TAG, "ForegroundService not allowed — app is in background. Caller should handle this.")
        }
        return result
    }

    /**
     * Bug #4 helper: re-emit the current permission snapshot to Flutter so the
     * UI updates after the user returns from a system permission/settings
     * dialog (call-screening role, accessibility, overlay, notifications).
     * Called from [onActivityResult] when the user comes back from any
     * external activity we launched.
     *
     * Bug #4 fix v2: previously used `sendMonitoringState("PERMISSION_SNAPSHOT:$map")`
     * which stringified a Map<String, Boolean> via toString(). Dart side
     * would have to parse this back to a structured object — fragile and
     * locale-sensitive (toString uses platform locale for booleans? no but
     * could change). Now we send via sendCallEvent which natively carries
     * Map<String, Any?> payload — same EventChannel, no parsing needed.
     */
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
