package com.lachancuocgoi.lachancuocgoi_flutter.services

import android.accessibilityservice.AccessibilityService
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.content.Context
import android.content.Intent
import android.os.Build
import android.os.Handler
import android.os.Looper
import android.util.Log
import android.view.accessibility.AccessibilityEvent
import android.view.accessibility.AccessibilityNodeInfo
import android.view.accessibility.AccessibilityWindowInfo
import androidx.core.app.NotificationCompat
import com.lachancuocgoi.lachancuocgoi_flutter.MainActivity
import com.lachancuocgoi.lachancuocgoi_flutter.R

/**
 * Unified Accessibility Service handles:
 * 1. Call Detection (OTT apps like Zalo, Messenger and System Dialer).
 * 2. Call Captioning (Reading Live Caption content).
 * 3. Auto Answer & Monitor (nhấc máy và bắt đầu giám sát).
 * 4. End Call (kết thúc cuộc gọi).
 */
@Suppress("DEPRECATION")
class UnifiedAccessibilityService : AccessibilityService() {

    private var lastCheckTime: Long = 0L
    private var isCallActive: Boolean = false
    private var lastServiceStartTime: Long = 0L
    private var isNotificationShown: Boolean = false

    companion object {
        private const val TAG = "UnifiedAccesService"
        private const val CALL_ANSWER_DELAY_MS = 2500L
        private const val CALL_DETECTION_THROTTLE_MS = 5000L
        const val ACTION_ANSWER_AND_MONITOR = "ACTION_ANSWER_AND_MONITOR"
        const val ACTION_END_CALL = "ACTION_END_CALL"
    }

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        when (intent?.action) {
            ACTION_ANSWER_AND_MONITOR -> {
                Log.d(TAG, "Received ACTION_ANSWER_AND_MONITOR")
                answerCallAndStartMonitoring()
            }
            ACTION_END_CALL -> {
                Log.d(TAG, "Received ACTION_END_CALL")
                endCall()
            }
            "ACTION_DISMISS_NOTIFICATION" -> {
                Log.d(TAG, "Received ACTION_DISMISS_NOTIFICATION")
                val notificationManager = getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
                notificationManager.cancel(1001)
                isNotificationShown = false
            }
        }
        return START_STICKY
    }

    override fun onAccessibilityEvent(event: AccessibilityEvent?) {
        if (event == null) return

        if (event.eventType == AccessibilityEvent.TYPE_WINDOW_STATE_CHANGED ||
            event.eventType == AccessibilityEvent.TYPE_WINDOW_CONTENT_CHANGED) {

            handleCallDetection()

            val rootNode = rootInActiveWindow
            if (rootNode != null) {
                traverseNodeForCaptions(rootNode)
            }
        }
    }

    // =========================================================================
    // CALL DETECTION
    // =========================================================================

    private fun handleCallDetection() {
        if (System.currentTimeMillis() - lastCheckTime < CALL_DETECTION_THROTTLE_MS) return
        lastCheckTime = System.currentTimeMillis()

        var detectedApp: String? = null
        try {
            val windowList = windows
            if (windowList.isNullOrEmpty()) return

            for (window: AccessibilityWindowInfo in windowList) {
                val rootNode = window.root
                if (rootNode != null) {
                    val appName = getIncomingCallAppName(rootNode)
                    if (appName != null) {
                        detectedApp = appName
                        if (!isCallActive) {
                            isCallActive = true
                            Log.d(TAG, "Incoming call detected from $detectedApp")

                            if (!isNotificationShown && System.currentTimeMillis() - lastServiceStartTime > CALL_DETECTION_THROTTLE_MS) {
                                lastServiceStartTime = System.currentTimeMillis()
                                isNotificationShown = true
                                showIncomingCallNotification("Cuộc gọi từ $detectedApp")

                                // Notify Flutter about call event
                                NativeBridgeEventSink.sendCallEvent(mapOf(
                                    "type" to "INCOMING",
                                    "source" to detectedApp
                                ))
                            }
                        }
                        rootNode.recycle()
                        break
                    }
                    rootNode.recycle()
                }
            }
        } catch (e: Exception) {
            Log.e(TAG, "Error in handleCallDetection", e)
        }

        if (detectedApp == null && isCallActive) {
            Log.d(TAG, "Call screen no longer detected.")
            isCallActive = false
            isNotificationShown = false

            NativeBridgeEventSink.sendCallEvent(mapOf(
                "type" to "ENDED"
            ))
        }
    }

    private fun getIncomingCallAppName(rootNode: AccessibilityNodeInfo): String? {
        val packageName = rootNode.packageName?.toString() ?: return null

        val isDialer = listOf(
            "com.google.android.dialer",
            "com.android.dialer",
            "com.samsung.android.dialer",
            "com.android.server.telecom"
        ).any { packageName.contains(it) }

        val incomingKeywords = listOf("Cuộc gọi đến", "Incoming call", "Trả lời", "Answer", "đang gọi")

        if (isDialer) {
            for (keyword in incomingKeywords) {
                if (rootNode.findAccessibilityNodeInfosByText(keyword).isNotEmpty()) return "Điện thoại"
            }
        }

        if (packageName.contains("com.zing.zalo")) {
            for (keyword in incomingKeywords) {
                if (rootNode.findAccessibilityNodeInfosByText(keyword).isNotEmpty()) return "Zalo"
            }
        }

        if (packageName.contains("com.facebook.orca")) {
            for (keyword in incomingKeywords) {
                if (rootNode.findAccessibilityNodeInfosByText(keyword).isNotEmpty()) return "Messenger"
            }
        }

        return null
    }

    // =========================================================================
    // AUTO-ANSWER & MONITOR
    // =========================================================================

    private fun answerCallAndStartMonitoring() {
        val notificationManager = getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
        notificationManager.cancel(1001)

        val answerText = listOf("Trả lời", "Answer")
        val answerDescriptions = listOf("Trả lời", "Answer", "Answer call", "Nhấc máy")
        val answered = findAndClick(answerText, answerDescriptions)

        if (answered) {
            Handler(Looper.getMainLooper()).postDelayed({
                val monitoringIntent = Intent(this, BackgroundMonitoringService::class.java).apply {
                    action = BackgroundMonitoringService.ACTION_START
                }
                if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                    startForegroundService(monitoringIntent)
                } else {
                    startService(monitoringIntent)
                }
                Log.d(TAG, "Started BackgroundMonitoringService after auto-answer.")
            }, CALL_ANSWER_DELAY_MS)
        } else {
            Log.e(TAG, "Could not find any answer button.")
        }
    }

    private fun endCall() {
        val endText = listOf("Kết thúc", "End", "End call")
        val endDescriptions = listOf("Kết thúc", "Kết thúc cuộc gọi", "End call", "Hang up")
        val ended = findAndClick(endText, endDescriptions)

        if (!ended) {
            performGlobalAction(GLOBAL_ACTION_BACK)
            Log.w(TAG, "Could not find end call button, used GLOBAL_ACTION_BACK fallback.")
        }
    }

    // =========================================================================
    // CLICK HELPERS
    // =========================================================================

    private fun findAndClick(textKeywords: List<String>, descriptionKeywords: List<String>): Boolean {
        try {
            for (window: AccessibilityWindowInfo in windows) {
                val rootNode = window.root ?: continue

                for (keyword in textKeywords) {
                    val textNodes = rootNode.findAccessibilityNodeInfosByText(keyword)
                    for (textNode in textNodes) {
                        val clickableNode = findClickableNode(textNode)
                        if (clickableNode != null) {
                            Log.d(TAG, "Found clickable node via text '$keyword', performing click.")
                            val clicked = clickableNode.performAction(AccessibilityNodeInfo.ACTION_CLICK)
                            Log.d(TAG, "Click action performed: $clicked")
                            clickableNode.recycle()
                            rootNode.recycle()
                            return true
                        }
                    }
                    textNodes?.forEach { it.recycle() }
                }

                val foundIcon = findClickableNodeByDescription(rootNode, descriptionKeywords)
                if (foundIcon != null) {
                    Log.d(TAG, "Found clickable node via description '${foundIcon.contentDescription}', performing click.")
                    val clicked = foundIcon.performAction(AccessibilityNodeInfo.ACTION_CLICK)
                    Log.d(TAG, "Click action performed: $clicked")
                    foundIcon.recycle()
                    rootNode.recycle()
                    return true
                }

                rootNode.recycle()
            }
        } catch (e: Exception) {
            Log.e(TAG, "Error in findAndClick", e)
        }
        return false
    }

    private fun findClickableNode(node: AccessibilityNodeInfo?): AccessibilityNodeInfo? {
        var currentNode = node
        while (currentNode != null) {
            if (currentNode.isClickable) {
                return currentNode
            }
            val parent = currentNode.parent
            if (currentNode != node) {
                currentNode.recycle()
            }
            currentNode = parent
        }
        return null
    }

    private fun findClickableNodeByDescription(node: AccessibilityNodeInfo, descriptions: List<String>): AccessibilityNodeInfo? {
        if (node.contentDescription != null) {
            val description = node.contentDescription.toString()
            if (descriptions.any { description.equals(it, ignoreCase = true) }) {
                val clickable = findClickableNode(node)
                if (clickable != null) return clickable
            }
        }
        for (i in 0 until node.childCount) {
            val child = node.getChild(i)
            if (child != null) {
                val found = findClickableNodeByDescription(child, descriptions)
                if (found != null) {
                    return found
                }
                child.recycle()
            }
        }
        return null
    }

    // =========================================================================
    // CAPTION READING
    // =========================================================================

    private fun traverseNodeForCaptions(node: AccessibilityNodeInfo?) {
        if (node == null) return
        if (node.text != null && node.text.isNotBlank()) {
            val content = node.text.toString()
            if (node.packageName == "com.google.android.as") {
                TranscriptionHub.postTranscript(content)
            }
        }
        for (i in 0 until node.childCount) {
            val child = node.getChild(i)
            if (child != null) {
                traverseNodeForCaptions(child)
                child.recycle()
            }
        }
    }

    override fun onInterrupt() {
        isCallActive = false
    }

    // =========================================================================
    // INCOMING CALL NOTIFICATION
    // =========================================================================

    private fun showIncomingCallNotification(callerInfo: String) {
        val notificationManager = getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager

        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val channel = NotificationChannel(
                "IncomingCallChannel",
                "Phát hiện cuộc gọi",
                NotificationManager.IMPORTANCE_HIGH
            ).apply {
                description = "Yêu cầu giám sát cuộc gọi"
                enableVibration(true)
                lockscreenVisibility = android.app.Notification.VISIBILITY_PUBLIC
            }
            notificationManager.createNotificationChannel(channel)
        }

        val monitorIntent = Intent(this, BackgroundMonitoringService::class.java).apply {
            action = BackgroundMonitoringService.ACTION_START
            putExtra("PHONE_NUMBER", callerInfo)
        }
        val monitorPendingIntent = PendingIntent.getService(this, 1, monitorIntent, PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE)

        val dismissIntent = Intent(this, com.lachancuocgoi.lachancuocgoi_flutter.receiver.CallReceiver::class.java).apply {
            action = "ACTION_DISMISS_NOTIFICATION"
        }
        val dismissPendingIntent = PendingIntent.getBroadcast(this, 2, dismissIntent, PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE)

        val fullScreenIntent = Intent(this, MainActivity::class.java).apply {
            flags = Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_SINGLE_TOP
            putExtra("NAVIGATE_TO_MONITORING", true)
        }
        val fullScreenPendingIntent = PendingIntent.getActivity(
            this, 0, fullScreenIntent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        )

        val notification = NotificationCompat.Builder(this, "IncomingCallChannel")
            .setSmallIcon(R.mipmap.ic_launcher)
            .setContentTitle("Lá chắn cuộc gọi")
            .setContentText("Phát hiện $callerInfo. Bạn có muốn giám sát không?")
            .setPriority(NotificationCompat.PRIORITY_HIGH)
            .setCategory(NotificationCompat.CATEGORY_CALL)
            .setFullScreenIntent(fullScreenPendingIntent, true)
            .setContentIntent(fullScreenPendingIntent)
            .addAction(R.mipmap.ic_launcher, "Có, giám sát", monitorPendingIntent)
            .addAction(R.mipmap.ic_launcher, "Không", dismissPendingIntent)
            .setOngoing(true)
            .setAutoCancel(true)
            .build()

        notificationManager.notify(1001, notification)
    }
}
