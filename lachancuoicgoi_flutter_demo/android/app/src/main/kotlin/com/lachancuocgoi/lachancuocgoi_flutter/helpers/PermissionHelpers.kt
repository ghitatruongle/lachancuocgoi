package com.lachancuocgoi.lachancuocgoi_flutter.helpers

import android.accessibilityservice.AccessibilityServiceInfo
import android.app.role.RoleManager
import android.content.Context
import android.content.pm.PackageManager
import android.os.Build
import android.provider.Settings
import android.view.accessibility.AccessibilityManager

/**
 * Permission helper functions extracted from `MainActivity.kt` (Wave 2 refactor).
 *
 * All functions are pure (take Context as parameter) and can be unit tested
 * with Robolectric.
 */
object PermissionHelpers {

    /**
     * Returns a snapshot of all permissions required by the app.
     */
    fun getPermissionSnapshot(context: Context): Map<String, Boolean> {
        return mapOf(
            "recordAudio" to (context.checkSelfPermission(android.Manifest.permission.RECORD_AUDIO) == PackageManager.PERMISSION_GRANTED),
            "phoneState" to (context.checkSelfPermission(android.Manifest.permission.READ_PHONE_STATE) == PackageManager.PERMISSION_GRANTED),
            "callLog" to (context.checkSelfPermission(android.Manifest.permission.READ_CALL_LOG) == PackageManager.PERMISSION_GRANTED),
            "overlay" to Settings.canDrawOverlays(context),
            "notification" to hasNotificationPermission(context),
            "accessibility" to isAccessibilityServiceEnabled(context),
            "callScreening" to isCallScreeningRoleHeld(context),
        )
    }

    /**
     * Checks if notification permission is granted (API 33+ requires runtime permission).
     */
    fun hasNotificationPermission(context: Context): Boolean {
        return if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
            context.checkSelfPermission(android.Manifest.permission.POST_NOTIFICATIONS) == PackageManager.PERMISSION_GRANTED
        } else {
            true // Notifications always allowed before API 33
        }
    }

    /**
     * Checks if the app's accessibility service is enabled in system settings.
     */
    fun isAccessibilityServiceEnabled(context: Context): Boolean {
        val am = context.getSystemService(Context.ACCESSIBILITY_SERVICE) as AccessibilityManager
        val enabledServices = am.getEnabledAccessibilityServiceList(AccessibilityServiceInfo.FEEDBACK_ALL_MASK)
        for (service in enabledServices) {
            if (service.resolveInfo.serviceInfo.packageName == context.packageName) {
                return true
            }
        }
        return false
    }

    /**
     * Checks if the app holds the call screening role (API 29+).
     */
    fun isCallScreeningRoleHeld(context: Context): Boolean {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
            val roleManager = context.getSystemService(Context.ROLE_SERVICE) as RoleManager
            return roleManager.isRoleHeld(RoleManager.ROLE_CALL_SCREENING)
        }
        return false
    }
}
