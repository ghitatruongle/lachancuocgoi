package com.lachancuocgoi.lachancuocgoi_flutter.services

import android.Manifest
import android.app.NotificationManager
import android.app.PendingIntent
import android.content.Context
import android.content.Intent
import android.content.pm.PackageManager
import android.os.Handler
import android.os.Looper
import android.provider.Settings
import android.telecom.TelecomManager
import android.util.Log
import androidx.core.app.NotificationCompat
import androidx.core.content.ContextCompat
import com.lachancuocgoi.lachancuocgoi_flutter.MainApplication
import com.lachancuocgoi.lachancuocgoi_flutter.R
import com.lachancuocgoi.lachancuocgoi_flutter.receiver.CallActionReceiver
import com.lachancuocgoi.lachancuocgoi_flutter.ui.OverlayManager
import java.util.UUID

/**
 * Single source of truth for one detected call.
 *
 * Both PHONE_STATE and Accessibility can report the same call repeatedly. This
 * coordinator de-duplicates that stream, shows one consent prompt, accepts one
 * answer, and finalizes one history-producing monitoring session.
 */
object CallSessionCoordinator {
    const val ACTION_ACCEPT = "com.lachancuocgoi.action.ACCEPT_MONITORING"
    const val ACTION_DECLINE = "com.lachancuocgoi.action.DECLINE_MONITORING"
    const val ACTION_END = "com.lachancuocgoi.action.END_CALL_AND_MONITORING"
    const val EXTRA_SESSION_ID = "callSessionId"
    const val INCOMING_NOTIFICATION_ID = 1001

    private const val TAG = "CallSessionCoordinator"
    private const val PREFS = "call_session_coordinator"
    private const val KEY_STATE = "state"
    private const val KEY_SESSION_ID = "session_id"
    private const val KEY_SOURCE = "source"
    private const val KEY_MASKED_NUMBER = "masked_number"
    private const val KEY_NUMBER_AVAILABLE = "number_available"
    private const val KEY_STARTED_AT_MS = "started_at_ms"
    private val mainHandler = Handler(Looper.getMainLooper())

    private enum class State { IDLE, PROMPTING, ACCEPTED, DECLINED, ENDING, ENDED }

    @Synchronized
    fun onIncomingCall(
        context: Context,
        source: String,
        maskedNumber: String?,
        numberAvailable: Boolean,
        reason: String,
    ) {
        val appContext = context.applicationContext
        val prefs = prefs(appContext)
        val current = readState(prefs.getString(KEY_STATE, null))
        if (current == State.PROMPTING ||
            current == State.ACCEPTED ||
            current == State.DECLINED ||
            current == State.ENDING
        ) {
            return
        }

        val sessionId = UUID.randomUUID().toString()
        prefs.edit()
            .putString(KEY_STATE, State.PROMPTING.name)
            .putString(KEY_SESSION_ID, sessionId)
            .putString(KEY_SOURCE, source)
            .putString(KEY_MASKED_NUMBER, maskedNumber)
            .putBoolean(KEY_NUMBER_AVAILABLE, numberAvailable)
            .putLong(KEY_STARTED_AT_MS, System.currentTimeMillis())
            .apply()

        showConsentNotification(appContext, sessionId, source, maskedNumber)
        NativeBridgeEventSink.sendCallEvent(
            mapOf(
                "type" to "RINGING",
                "reason" to reason,
                "numberAvailable" to numberAvailable,
                "maskedNumber" to maskedNumber,
            )
        )
    }

    @Synchronized
    fun acceptMonitoring(context: Context, requestedSessionId: String?) {
        val appContext = context.applicationContext
        val session = currentSession(appContext) ?: return
        if (session.state != State.PROMPTING || session.id != requestedSessionId) return

        val preflightFailure = when {
            !Settings.canDrawOverlays(appContext) ->
                "Hãy cấp quyền hiển thị trên ứng dụng khác trước khi giám sát."
            ContextCompat.checkSelfPermission(appContext, Manifest.permission.RECORD_AUDIO) !=
                PackageManager.PERMISSION_GRANTED ->
                "Hãy cấp quyền micro trước khi giám sát."
            !session.isSystemCall &&
                !com.lachancuocgoi.lachancuocgoi_flutter.helpers.PermissionHelpers
                    .isAccessibilityServiceEnabled(appContext) ->
                "Hãy bật Trợ năng để tự động trả lời cuộc gọi ứng dụng."
            else -> null
        }
        if (preflightFailure != null) {
            failAcceptedStart(appContext, "permission_missing", preflightFailure)
            return
        }

        val acceptedAtMs = System.currentTimeMillis()
        prefs(appContext).edit()
            .putString(KEY_STATE, State.ACCEPTED.name)
            .putLong(KEY_STARTED_AT_MS, acceptedAtMs)
            .apply()
        cancelConsentNotification(appContext)

        // Android 15 permits a microphone FGS launched from a user notification
        // action. Attach the visible overlay first when permission is available.
        val overlayVisible = OverlayManager.showMonitoringOverlay(appContext, acceptedAtMs)
        if (!overlayVisible) {
            failAcceptedStart(
                appContext,
                "overlay_attach_failed",
                "Không thể hiển thị bảng giám sát nổi trên thiết bị này.",
            )
            return
        }

        val monitoringIntent = Intent(appContext, BackgroundMonitoringService::class.java).apply {
            action = BackgroundMonitoringService.ACTION_START
        }
        val launchResult = ForegroundServiceLauncher.safeStartForegroundService(
            appContext,
            monitoringIntent,
        )
        if (launchResult != ForegroundServiceLauncher.LaunchResult.SUCCESS) {
            Log.e(TAG, "Monitoring service launch failed: $launchResult")
            failAcceptedStart(
                appContext,
                launchResult.name.lowercase(),
                "Android không cho phép khởi động dịch vụ giám sát.",
            )
            return
        }

        // Creating a FlutterEngine can be slow on low-end phones. Defer it
        // until the notification BroadcastReceiver has returned so the user
        // action cannot trigger a broadcast timeout/ANR. Native transcription
        // events are buffered until Dart attaches its EventChannel listeners.
        mainHandler.post {
            val current = currentSession(appContext)
            if (current?.state != State.ACCEPTED || current.id != session.id) {
                return@post
            }
            val engineReady = (appContext as? MainApplication)?.let { application ->
                runCatching { application.ensureFlutterEngine() }
                    .onFailure {
                        Log.e(TAG, "Unable to start the background Flutter engine", it)
                    }
                    .isSuccess
            } ?: false
            if (!engineReady) {
                requestMonitoringStop(appContext)
                failAcceptedStart(
                    appContext,
                    "analysis_engine_failed",
                    "Không thể khởi động bộ phân tích cuộc gọi.",
                )
                return@post
            }

            NativeBridgeEventSink.sendCallEvent(
                mapOf(
                    "type" to "MONITORING_ACCEPTED",
                    "reason" to "user_accepted_notification",
                    "numberAvailable" to session.numberAvailable,
                    "maskedNumber" to session.maskedNumber,
                )
            )

            val answeredByTelecom = session.isSystemCall && answerSystemCall(appContext)
            if (!answeredByTelecom) {
                UnifiedAccessibilityService.requestAnswer(appContext)
            }
        }
    }

    @Synchronized
    fun declineMonitoring(context: Context, requestedSessionId: String?) {
        val appContext = context.applicationContext
        val session = currentSession(appContext) ?: return
        if (session.state != State.PROMPTING || session.id != requestedSessionId) return
        prefs(appContext).edit().putString(KEY_STATE, State.DECLINED.name).apply()
        cancelConsentNotification(appContext)
        NativeBridgeEventSink.sendCallEvent(
            mapOf(
                "type" to "MONITORING_DECLINED",
                "reason" to "user_declined_notification",
            )
        )
    }

    /** Ends the physical call, monitoring, overlays, and history session once. */
    fun endFromUser(context: Context) {
        finishAcceptedSession(context.applicationContext, endPhysicalCall = true, "overlay_end")
    }

    /** Called for PHONE_STATE=IDLE or when an OTT call screen disappears. */
    @Synchronized
    fun onCallEnded(context: Context, reason: String) {
        val appContext = context.applicationContext
        val session = currentSession(appContext) ?: return
        when (session.state) {
            State.ACCEPTED -> finishAcceptedSession(
                appContext,
                endPhysicalCall = false,
                reason = reason,
            )
            State.PROMPTING, State.DECLINED -> {
                cancelConsentNotification(appContext)
                prefs(appContext).edit().putString(KEY_STATE, State.ENDED.name).apply()
            }
            State.IDLE, State.ENDING, State.ENDED -> Unit
        }
    }

    /** Called by the FGS so an external stop cannot leave a stale overlay. */
    fun onMonitoringServiceStopped(context: Context) {
        val appContext = context.applicationContext
        OverlayManager.removeAll(appContext)
        synchronized(this) {
            val state = currentSession(appContext)?.state ?: return
            if (state == State.ACCEPTED) {
                finishAcceptedSession(appContext, false, "monitoring_service_stopped")
            }
        }
    }

    fun isMonitoringAccepted(context: Context): Boolean =
        currentSession(context.applicationContext)?.state == State.ACCEPTED

    @Synchronized
    private fun finishAcceptedSession(
        context: Context,
        endPhysicalCall: Boolean,
        reason: String,
    ) {
        val session = currentSession(context) ?: return
        if (session.state != State.ACCEPTED) return
        prefs(context).edit().putString(KEY_STATE, State.ENDING.name).apply()

        cancelConsentNotification(context)
        OverlayManager.removeAll(context)
        if (endPhysicalCall) {
            val endedByTelecom = session.isSystemCall && endSystemCall(context)
            if (!endedByTelecom) UnifiedAccessibilityService.requestEnd(context)
        }

        requestMonitoringStop(context)

        prefs(context).edit().putString(KEY_STATE, State.ENDED.name).apply()
        NativeBridgeEventSink.sendCallEvent(
            mapOf(
                "type" to "CALL_SESSION_ENDED",
                "reason" to reason,
                "numberAvailable" to session.numberAvailable,
                "maskedNumber" to session.maskedNumber,
            )
        )
    }

    @Suppress("DEPRECATION")
    private fun answerSystemCall(context: Context): Boolean {
        if (ContextCompat.checkSelfPermission(context, Manifest.permission.ANSWER_PHONE_CALLS) !=
            PackageManager.PERMISSION_GRANTED
        ) {
            return false
        }
        return runCatching {
            val telecom = context.getSystemService(Context.TELECOM_SERVICE) as TelecomManager
            telecom.acceptRingingCall()
            true
        }.getOrElse {
            Log.w(TAG, "Telecom auto-answer failed; using accessibility fallback", it)
            false
        }
    }

    @Suppress("DEPRECATION")
    private fun endSystemCall(context: Context): Boolean {
        if (android.os.Build.VERSION.SDK_INT < android.os.Build.VERSION_CODES.P ||
            ContextCompat.checkSelfPermission(context, Manifest.permission.ANSWER_PHONE_CALLS) !=
            PackageManager.PERMISSION_GRANTED
        ) {
            return false
        }
        return runCatching {
            val telecom = context.getSystemService(Context.TELECOM_SERVICE) as TelecomManager
            telecom.endCall()
        }.getOrElse {
            Log.w(TAG, "Telecom end-call failed; using accessibility fallback", it)
            false
        }
    }

    private fun showConsentNotification(
        context: Context,
        sessionId: String,
        source: String,
        maskedNumber: String?,
    ) {
        val acceptIntent = Intent(context, CallActionReceiver::class.java).apply {
            action = ACTION_ACCEPT
            putExtra(EXTRA_SESSION_ID, sessionId)
        }
        val declineIntent = Intent(context, CallActionReceiver::class.java).apply {
            action = ACTION_DECLINE
            putExtra(EXTRA_SESSION_ID, sessionId)
        }
        val flags = PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        val acceptPendingIntent = PendingIntent.getBroadcast(context, 1101, acceptIntent, flags)
        val declinePendingIntent = PendingIntent.getBroadcast(context, 1102, declineIntent, flags)
        val caller = maskedNumber?.takeIf { it.isNotBlank() } ?: source

        val notification = NotificationCompat.Builder(
            context,
            MainApplication.INCOMING_CALL_CHANNEL_ID,
        )
            .setSmallIcon(R.mipmap.ic_launcher)
            .setContentTitle("Lá chắn cuộc gọi")
            .setContentText("Phát hiện cuộc gọi từ $caller. Bạn có muốn giám sát không?")
            .setStyle(
                NotificationCompat.BigTextStyle().bigText(
                    "Phát hiện cuộc gọi từ $caller. Bạn có muốn tự động trả lời và giám sát không?"
                )
            )
            .setPriority(NotificationCompat.PRIORITY_HIGH)
            .setCategory(NotificationCompat.CATEGORY_CALL)
            .setVisibility(NotificationCompat.VISIBILITY_PUBLIC)
            .addAction(0, "Có", acceptPendingIntent)
            .addAction(0, "Không", declinePendingIntent)
            .setOngoing(true)
            .setAutoCancel(false)
            .build()

        val manager = context.getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
        manager.notify(INCOMING_NOTIFICATION_ID, notification)
    }

    private fun cancelConsentNotification(context: Context) {
        val manager = context.getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
        manager.cancel(INCOMING_NOTIFICATION_ID)
    }

    private fun failAcceptedStart(context: Context, reason: String, message: String) {
        // Keep the session in a terminal-for-this-call state until IDLE/the
        // OTT call screen closes. Marking it ENDED here would allow another
        // repeated RINGING accessibility event to show the consent prompt in
        // a loop during the same physical call.
        prefs(context).edit().putString(KEY_STATE, State.DECLINED.name).apply()
        OverlayManager.removeAll(context)
        cancelConsentNotification(context)
        NativeBridgeEventSink.sendCallEvent(
            mapOf(
                "type" to "MONITORING_START_FAILED",
                "reason" to reason,
            )
        )
        val notification = NotificationCompat.Builder(
            context,
            MainApplication.INCOMING_CALL_CHANNEL_ID,
        )
            .setSmallIcon(R.mipmap.ic_launcher)
            .setContentTitle("Không thể bắt đầu giám sát")
            .setContentText(message)
            .setStyle(NotificationCompat.BigTextStyle().bigText(message))
            .setPriority(NotificationCompat.PRIORITY_HIGH)
            .setAutoCancel(true)
            .build()
        val manager = context.getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
        manager.notify(INCOMING_NOTIFICATION_ID, notification)
    }

    private fun requestMonitoringStop(context: Context) {
        val stopIntent = Intent(context, BackgroundMonitoringService::class.java).apply {
            action = BackgroundMonitoringService.ACTION_STOP
        }
        runCatching { context.startService(stopIntent) }
            .onFailure { Log.w(TAG, "Unable to stop monitoring service", it) }
    }

    private data class Session(
        val id: String,
        val state: State,
        val source: String,
        val maskedNumber: String?,
        val numberAvailable: Boolean,
        val startedAtMs: Long,
    ) {
        val isSystemCall: Boolean
            get() = source == SYSTEM_CALL_SOURCE
    }

    private fun currentSession(context: Context): Session? {
        val prefs = prefs(context)
        val id = prefs.getString(KEY_SESSION_ID, null) ?: return null
        return Session(
            id = id,
            state = readState(prefs.getString(KEY_STATE, null)),
            source = prefs.getString(KEY_SOURCE, SYSTEM_CALL_SOURCE) ?: SYSTEM_CALL_SOURCE,
            maskedNumber = prefs.getString(KEY_MASKED_NUMBER, null),
            numberAvailable = prefs.getBoolean(KEY_NUMBER_AVAILABLE, false),
            startedAtMs = prefs.getLong(KEY_STARTED_AT_MS, System.currentTimeMillis()),
        )
    }

    private fun prefs(context: Context) =
        context.getSharedPreferences(PREFS, Context.MODE_PRIVATE)

    private fun readState(raw: String?): State =
        runCatching { State.valueOf(raw ?: State.IDLE.name) }.getOrDefault(State.IDLE)

    const val SYSTEM_CALL_SOURCE = "Điện thoại"
}
