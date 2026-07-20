package com.lachancuocgoi.lachancuocgoi_flutter.services

import android.content.Context
import android.content.Intent
import android.provider.Settings
import com.lachancuocgoi.lachancuocgoi_flutter.audio.CreatorAudioCaptureManager
import com.lachancuocgoi.lachancuocgoi_flutter.helpers.PermissionHelpers
import com.lachancuocgoi.lachancuocgoi_flutter.ui.OverlayManager
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodChannel
import java.lang.ref.WeakReference

/** Channels that must remain available even when no FlutterActivity is visible. */
object NativeBridgeChannels {
    const val METHOD_CHANNEL = "com.lachancuocgoi/native_bridge"
    private const val TRANSCRIPT_CHANNEL = "com.lachancuocgoi/transcript_stream"
    private const val RMS_CHANNEL = "com.lachancuocgoi/rms_stream"
    private const val MONITORING_STATE_CHANNEL = "com.lachancuocgoi/monitoring_state"
    private const val CALL_EVENT_CHANNEL = "com.lachancuocgoi/call_events"
    private const val LOGS_CHANNEL = "com.lachancuocgoi/logs"

    private var registeredEngineRef: WeakReference<FlutterEngine>? = null

    @Synchronized
    fun registerEventChannels(context: Context, engine: FlutterEngine) {
        if (registeredEngineRef?.get() === engine) return
        registeredEngineRef = WeakReference(engine)
        val messenger = engine.dartExecutor.binaryMessenger

        EventChannel(messenger, TRANSCRIPT_CHANNEL)
            .setStreamHandler(object : EventChannel.StreamHandler {
                override fun onListen(arguments: Any?, events: EventChannel.EventSink?) {
                    NativeBridgeEventSink.transcriptSink = events
                    CreatorAudioCaptureManager.creatorTranscriptFlow.value
                        .takeIf(String::isNotBlank)
                        ?.let { events?.success(it) }
                    NativeBridgeEventSink.onSinksReconnected()
                }

                override fun onCancel(arguments: Any?) {
                    NativeBridgeEventSink.transcriptSink = null
                }
            })

        EventChannel(messenger, RMS_CHANNEL)
            .setStreamHandler(object : EventChannel.StreamHandler {
                override fun onListen(arguments: Any?, events: EventChannel.EventSink?) {
                    NativeBridgeEventSink.rmsSink = events
                }

                override fun onCancel(arguments: Any?) {
                    NativeBridgeEventSink.rmsSink = null
                }
            })

        EventChannel(messenger, MONITORING_STATE_CHANNEL)
            .setStreamHandler(object : EventChannel.StreamHandler {
                override fun onListen(arguments: Any?, events: EventChannel.EventSink?) {
                    NativeBridgeEventSink.monitoringStateSink = events
                    if (CreatorMediaProjectionService.isRunning || BackgroundMonitoringService.isRunning) {
                        events?.success("STARTED")
                    }
                    NativeBridgeEventSink.onSinksReconnected()
                }

                override fun onCancel(arguments: Any?) {
                    NativeBridgeEventSink.monitoringStateSink = null
                }
            })

        EventChannel(messenger, CALL_EVENT_CHANNEL)
            .setStreamHandler(object : EventChannel.StreamHandler {
                override fun onListen(arguments: Any?, events: EventChannel.EventSink?) {
                    NativeBridgeEventSink.callEventSink = events
                    NativeBridgeEventSink.onSinksReconnected()
                }

                override fun onCancel(arguments: Any?) {
                    NativeBridgeEventSink.callEventSink = null
                }
            })

        EventChannel(messenger, LOGS_CHANNEL)
            .setStreamHandler(object : EventChannel.StreamHandler {
                override fun onListen(arguments: Any?, events: EventChannel.EventSink?) {
                    NativeBridgeEventSink.logsSink = events
                    NativeBridgeEventSink.onSinksReconnected()
                }

                override fun onCancel(arguments: Any?) {
                    NativeBridgeEventSink.logsSink = null
                }
            })
    }

    /** Installs the subset of native methods needed by headless monitoring. */
    fun installBackgroundMethodHandler(context: Context, engine: FlutterEngine) {
        val appContext = context.applicationContext
        MethodChannel(engine.dartExecutor.binaryMessenger, METHOD_CHANNEL)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "stopMonitoring" -> {
                        startServiceAction(
                            appContext,
                            BackgroundMonitoringService::class.java,
                            BackgroundMonitoringService.ACTION_STOP,
                        )
                        result.success(true)
                    }
                    "showRedAlert" -> {
                        OverlayManager.showRedAlert(
                            appContext,
                            call.argument<String>("reason") ?: "Rủi ro cao!",
                        )
                        result.success(true)
                    }
                    "showOrangeAlert" -> {
                        OverlayManager.showOrangeAlert(
                            appContext,
                            call.argument<String>("reason") ?: "Rủi ro trung bình!",
                        )
                        result.success(true)
                    }
                    "dismissAlert" -> {
                        OverlayManager.removeAlertOverlay(appContext)
                        result.success(true)
                    }
                    "getPermissionSnapshot" ->
                        result.success(PermissionHelpers.getPermissionSnapshot(appContext))
                    "checkOverlayPermission" -> result.success(Settings.canDrawOverlays(appContext))
                    "isAccessibilityEnabled" ->
                        result.success(PermissionHelpers.isAccessibilityServiceEnabled(appContext))
                    "isMonitoringActive" -> result.success(BackgroundMonitoringService.isRunning)
                    "isCreatorMonitoringActive" ->
                        result.success(CreatorMediaProjectionService.isRunning)
                    "setAnalysisMode" -> {
                        MonitoringPreferences.writeAnalysisMode(
                            appContext,
                            call.argument<String>("mode").orEmpty(),
                        )
                        result.success(true)
                    }
                    "setAutoEnableSpeakerphone" -> {
                        MonitoringPreferences.writeAutoEnableSpeakerphone(
                            appContext,
                            call.argument<Boolean>("enabled") ?: true,
                        )
                        result.success(true)
                    }
                    "setCallScreeningBlockEnabled" -> {
                        val enabled = call.argument<Boolean>("enabled") ?: false
                        appContext.getSharedPreferences(
                            CallScreeningPreferences.PREFS_NAME,
                            Context.MODE_PRIVATE,
                        ).edit().putBoolean(CallScreeningPreferences.KEY_BLOCK_ENABLED, enabled).apply()
                        result.success(true)
                    }
                    "setBlockedNumbers" -> {
                        val numbers = call.argument<List<String>>("numbers").orEmpty()
                        appContext.getSharedPreferences(
                            CallScreeningPreferences.PREFS_NAME,
                            Context.MODE_PRIVATE,
                        ).edit().putStringSet(
                            CallScreeningPreferences.KEY_BLOCKED_NUMBERS,
                            numbers.toSet(),
                        ).apply()
                        result.success(true)
                    }
                    "stopCreatorMonitoring" -> {
                        startServiceAction(
                            appContext,
                            CreatorMediaProjectionService::class.java,
                            CreatorMediaProjectionService.ACTION_STOP,
                        )
                        result.success(true)
                    }
                    // These operations require a visible Activity/system dialog.
                    "startCreatorMonitoring",
                    "requestCallScreeningRole",
                    "requestPhoneAndCallLogPermissions",
                    "requestOverlayPermission",
                    "openAccessibilitySettings" -> result.success(false)
                    else -> result.notImplemented()
                }
            }
    }

    private fun startServiceAction(
        context: Context,
        serviceClass: Class<*>,
        action: String,
    ) {
        val intent = Intent(context, serviceClass).apply { this.action = action }
        runCatching { context.startService(intent) }
    }
}
