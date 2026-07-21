package com.lachancuocgoi.lachancuocgoi_flutter.services

import android.accessibilityservice.AccessibilityService
import android.content.Context
import android.os.Handler
import android.os.Looper
import android.util.Log
import android.view.accessibility.AccessibilityEvent
import android.view.accessibility.AccessibilityNodeInfo
import com.lachancuocgoi.lachancuocgoi_flutter.diagnostics.MonitoringPerfProbe
import java.lang.ref.WeakReference

/** Detects and controls explicitly supported system and OTT call screens. */
class UnifiedAccessibilityService : AccessibilityService() {
    private val handler = Handler(Looper.getMainLooper())
    private var isCallActive = false
    private var lastDetectionAtMs = 0L
    private var lastScanAtMs = 0L
    private var lastCaptionScanAtMs = 0L
    private var pendingEndCheck: Runnable? = null

    override fun onServiceConnected() {
        super.onServiceConnected()
        serviceRef = WeakReference(this)
        MonitoringPerfProbe.mark("accessibility_service_connected")
        when (pendingAction(this)) {
            ACTION_ANSWER -> answerWithRetry()
            ACTION_END -> endWithRetry()
        }
        clearPendingAction(this)
    }

    override fun onAccessibilityEvent(event: AccessibilityEvent?) {
        event ?: return
        val packageName = event.packageName?.toString().orEmpty()
        val now = System.currentTimeMillis()

        if (event.eventType == AccessibilityEvent.TYPE_WINDOW_STATE_CHANGED ||
            (event.eventType == AccessibilityEvent.TYPE_WINDOW_CONTENT_CHANGED &&
                isTargetCallPackage(packageName) && now - lastScanAtMs >= SCAN_THROTTLE_MS)
        ) {
            lastScanAtMs = now
            val scanToken = MonitoringPerfProbe.begin("accessibility_incoming_scan")
            try {
                scanForIncomingCall()
            } finally {
                MonitoringPerfProbe.end(scanToken)
            }
        }

        if ((event.eventType == AccessibilityEvent.TYPE_WINDOW_STATE_CHANGED ||
                event.eventType == AccessibilityEvent.TYPE_WINDOW_CONTENT_CHANGED) &&
            isTargetCaptionPackage(packageName) &&
            now - lastCaptionScanAtMs >= CAPTION_THROTTLE_MS
        ) {
            lastCaptionScanAtMs = now
            val captionToken = MonitoringPerfProbe.begin("accessibility_caption_scan")
            try {
                rootInActiveWindow?.let(::traverseNodeForCaptions)
            } finally {
                MonitoringPerfProbe.end(captionToken)
            }
        }
    }

    override fun onInterrupt() = Unit

    override fun onDestroy() {
        if (serviceRef?.get() === this) serviceRef = null
        pendingEndCheck?.let(handler::removeCallbacks)
        pendingEndCheck = null
        super.onDestroy()
    }

    private fun scanForIncomingCall() {
        val detectedCall = runCatching {
            windows.orEmpty().firstNotNullOfOrNull { window ->
                window.root?.let(::getDetectedCall)
            }
        }.onFailure { Log.w(TAG, "Accessibility call scan failed", it) }.getOrNull()

        if (detectedCall != null) {
            lastDetectionAtMs = System.currentTimeMillis()
            pendingEndCheck?.let(handler::removeCallbacks)
            pendingEndCheck = null
            if (!isCallActive && detectedCall.isIncoming) {
                isCallActive = true
                CallSessionCoordinator.onIncomingCall(
                    context = this,
                    source = detectedCall.source,
                    maskedNumber = null,
                    numberAvailable = false,
                    reason = "accessibility_incoming_call",
                )
            } else if (!isCallActive) {
                // The service may connect after the user already answered.
                // Track the active screen, but never prompt without incoming
                // call semantics.
                isCallActive = true
            }
            return
        }

        if (!isCallActive || pendingEndCheck != null) return
        val endCheck = Runnable {
            pendingEndCheck = null
            if (isCallActive && System.currentTimeMillis() - lastDetectionAtMs >= END_DEBOUNCE_MS) {
                isCallActive = false
                CallSessionCoordinator.onCallEnded(this, "accessibility_call_screen_closed")
            }
        }
        pendingEndCheck = endCheck
        handler.postDelayed(endCheck, END_DEBOUNCE_MS)
    }

    private data class DetectedCall(val source: String, val isIncoming: Boolean)

    private fun getDetectedCall(root: AccessibilityNodeInfo): DetectedCall? {
        val packageName = root.packageName?.toString().orEmpty()
        val source = when {
            SYSTEM_DIALER_PACKAGES.any(packageName::contains) ->
                CallSessionCoordinator.SYSTEM_CALL_SOURCE
            else -> OTT_CALL_PACKAGES.entries
                .firstOrNull { packageName.contains(it.key) }
                ?.value
                ?: return null
        }
        return when {
            containsAnyText(root, INCOMING_KEYWORDS) -> DetectedCall(source, true)
            containsAnyText(root, ACTIVE_CALL_KEYWORDS) -> DetectedCall(source, false)
            else -> null
        }
    }

    private fun containsAnyText(node: AccessibilityNodeInfo?, keywords: Set<String>): Boolean {
        node ?: return false
        val candidates = sequenceOf(node.text, node.contentDescription)
            .mapNotNull { it?.toString() }
        if (candidates.any { value -> keywords.any { value.contains(it, ignoreCase = true) } }) {
            return true
        }
        for (index in 0 until node.childCount) {
            if (containsAnyText(node.getChild(index), keywords)) return true
        }
        return false
    }

    private fun answerWithRetry(attempt: Int = 0) {
        val scanToken = MonitoringPerfProbe.begin(
            "accessibility_answer_scan",
            "attempt=${attempt + 1}",
        )
        val clicked = try {
            findAndClick(ANSWER_TEXT, ANSWER_DESCRIPTIONS)
        } finally {
            MonitoringPerfProbe.end(scanToken)
        }
        if (clicked) {
            MonitoringPerfProbe.mark(
                "accessibility_answer_retry_finished",
                "attempt=${attempt + 1},clicked=true",
            )
            clearPendingAction(this)
            Log.i(TAG, "Supported call was answered through accessibility")
            return
        }
        if (attempt + 1 >= CONTROL_RETRY_COUNT) {
            MonitoringPerfProbe.mark(
                "accessibility_answer_retry_finished",
                "attempt=${attempt + 1},clicked=false",
            )
            Log.w(TAG, "No supported answer control was found")
            return
        }
        MonitoringPerfProbe.mark(
            "accessibility_answer_retry_scheduled",
            "next_attempt=${attempt + 2},delay_ms=$CONTROL_RETRY_DELAY_MS",
        )
        handler.postDelayed({ answerWithRetry(attempt + 1) }, CONTROL_RETRY_DELAY_MS)
    }

    private fun endWithRetry(attempt: Int = 0) {
        val clicked = findAndClick(END_TEXT, END_DESCRIPTIONS)
        if (clicked) {
            clearPendingAction(this)
            Log.i(TAG, "Supported call was ended through accessibility")
            return
        }
        if (attempt + 1 >= CONTROL_RETRY_COUNT) {
            Log.w(TAG, "No supported end-call control was found")
            return
        }
        handler.postDelayed({ endWithRetry(attempt + 1) }, CONTROL_RETRY_DELAY_MS)
    }

    private fun findAndClick(
        textKeywords: List<String>,
        descriptionKeywords: List<String>,
    ): Boolean {
        return runCatching {
            windows.orEmpty().any { window ->
                val root = window.root ?: return@any false
                if (!isTargetCallPackage(root.packageName?.toString().orEmpty())) {
                    return@any false
                }
                textKeywords.any { keyword ->
                    root.findAccessibilityNodeInfosByText(keyword).orEmpty().any(::clickNodeOrParent)
                } || findAndClickByDescription(root, descriptionKeywords)
            }
        }.onFailure { Log.w(TAG, "Accessibility control lookup failed", it) }.getOrDefault(false)
    }

    private fun clickNodeOrParent(node: AccessibilityNodeInfo): Boolean {
        var candidate: AccessibilityNodeInfo? = node
        while (candidate != null) {
            if (candidate.isClickable && candidate.performAction(AccessibilityNodeInfo.ACTION_CLICK)) {
                return true
            }
            candidate = candidate.parent
        }
        return false
    }

    private fun findAndClickByDescription(
        node: AccessibilityNodeInfo,
        descriptions: List<String>,
    ): Boolean {
        val description = node.contentDescription?.toString()
        if (description != null &&
            descriptions.any { description.contains(it, ignoreCase = true) } &&
            clickNodeOrParent(node)
        ) {
            return true
        }
        for (index in 0 until node.childCount) {
            val child = node.getChild(index) ?: continue
            if (findAndClickByDescription(child, descriptions)) return true
        }
        return false
    }

    private fun traverseNodeForCaptions(node: AccessibilityNodeInfo?) {
        node ?: return
        val packageName = node.packageName?.toString().orEmpty()
        val text = node.text?.toString()?.trim().orEmpty()
        if (text.isNotEmpty() && isTargetCaptionPackage(packageName)) {
            TranscriptionHub.postTranscript(text)
        }
        for (index in 0 until node.childCount) {
            traverseNodeForCaptions(node.getChild(index))
        }
    }

    private fun isTargetCallPackage(packageName: String): Boolean =
        packageName.isEmpty() ||
            SYSTEM_DIALER_PACKAGES.any(packageName::contains) ||
            OTT_CALL_PACKAGES.keys.any(packageName::contains)

    private fun isTargetCaptionPackage(packageName: String): Boolean =
        packageName == "com.google.android.as" ||
            packageName.contains("livecaption", ignoreCase = true) ||
            packageName.contains("live_caption", ignoreCase = true) ||
            packageName.contains("samsung.accessibility", ignoreCase = true)

    companion object {
        private const val TAG = "UnifiedAccessibility"
        private const val PREFS = "accessibility_call_actions"
        private const val KEY_PENDING_ACTION = "pending_action"
        private const val ACTION_ANSWER = "answer"
        private const val ACTION_END = "end"
        private const val SCAN_THROTTLE_MS = 350L
        private const val CAPTION_THROTTLE_MS = 200L
        private const val END_DEBOUNCE_MS = 2500L
        private const val CONTROL_RETRY_DELAY_MS = 350L
        private const val CONTROL_RETRY_COUNT = 8

        private var serviceRef: WeakReference<UnifiedAccessibilityService>? = null
        private val mainHandler = Handler(Looper.getMainLooper())

        private val SYSTEM_DIALER_PACKAGES = setOf(
            "com.google.android.dialer",
            "com.android.dialer",
            "com.samsung.android.dialer",
            "com.android.server.telecom",
            "com.android.systemui",
        )
        private val OTT_CALL_PACKAGES = mapOf(
            "com.zing.zalo" to "Zalo",
            "com.facebook.orca" to "Messenger",
            "com.whatsapp" to "WhatsApp",
            "org.telegram.messenger" to "Telegram",
            "com.viber.voip" to "Viber",
            "jp.naver.line.android" to "LINE",
            "org.thoughtcrime.securesms" to "Signal",
            "com.skype.raider" to "Skype",
        )
        private val INCOMING_KEYWORDS = setOf(
            "Cuộc gọi đến", "Incoming call", "Trả lời", "Answer",
            "Đang gọi đến", "Video call from", "Voice call from",
        )
        private val ACTIVE_CALL_KEYWORDS = setOf(
            "Kết thúc cuộc gọi", "Kết thúc", "End call", "Hang up",
            "Đang kết nối", "Cuộc gọi đang diễn ra", "Connected",
            "Call in progress", "Ongoing call",
        )
        private val ANSWER_TEXT = listOf("Trả lời", "Answer", "Chấp nhận", "Accept")
        private val ANSWER_DESCRIPTIONS = listOf(
            "Trả lời", "Nhấc máy", "Answer call", "Accept call",
        )
        private val END_TEXT = listOf("Kết thúc", "End", "End call", "Từ chối", "Decline")
        private val END_DESCRIPTIONS = listOf(
            "Kết thúc cuộc gọi", "End call", "Hang up", "Từ chối cuộc gọi",
        )

        fun requestAnswer(context: Context) = requestAction(context, ACTION_ANSWER)

        fun requestEnd(context: Context) = requestAction(context, ACTION_END)

        private fun requestAction(context: Context, action: String) {
            val appContext = context.applicationContext
            appContext.getSharedPreferences(PREFS, Context.MODE_PRIVATE)
                .edit()
                .putString(KEY_PENDING_ACTION, action)
                .apply()
            mainHandler.post {
                val service = serviceRef?.get()
                if (service == null) {
                    MonitoringPerfProbe.mark(
                        "accessibility_action_not_dispatched",
                        "action=$action,reason=service_unavailable",
                    )
                    return@post
                }
                MonitoringPerfProbe.mark("accessibility_action_dispatched", "action=$action")
                if (action == ACTION_ANSWER) service.answerWithRetry() else service.endWithRetry()
            }
        }

        private fun pendingAction(context: Context): String? =
            context.getSharedPreferences(PREFS, Context.MODE_PRIVATE)
                .getString(KEY_PENDING_ACTION, null)

        private fun clearPendingAction(context: Context) {
            context.getSharedPreferences(PREFS, Context.MODE_PRIVATE)
                .edit()
                .remove(KEY_PENDING_ACTION)
                .apply()
        }
    }
}
