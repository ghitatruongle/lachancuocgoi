package com.example.lachancuocgoi.ui.HomePage.RightsDialog

import android.Manifest
import android.accessibilityservice.AccessibilityServiceInfo
import android.annotation.SuppressLint
import android.app.role.RoleManager
import android.content.Context
import android.content.pm.PackageManager
import android.os.Build
import android.provider.Settings
import android.view.accessibility.AccessibilityManager
import androidx.core.content.ContextCompat
import com.example.lachancuocgoi.services.UnifiedAccessibilityService

object PermissionUtils {
    private const val TAG = "PermissionUtils"

    fun hasPhoneCallAccess(context: Context): Boolean {
        val hasPhonePerm = ContextCompat.checkSelfPermission(context, Manifest.permission.READ_PHONE_STATE) == PackageManager.PERMISSION_GRANTED
        val hasCallLogPerm = ContextCompat.checkSelfPermission(context, Manifest.permission.READ_CALL_LOG) == PackageManager.PERMISSION_GRANTED
        return hasPhonePerm && hasCallLogPerm
    }

    @SuppressLint("NewApi")
    fun isCallScreeningRoleHeld(context: Context): Boolean {
        return if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
            val roleManager = context.getSystemService(Context.ROLE_SERVICE) as? RoleManager
            if (roleManager == null) {
                android.util.Log.w(TAG, "RoleManager unavailable on this device/emulator.")
                false
            } else {
                runCatching { roleManager.isRoleHeld(RoleManager.ROLE_CALL_SCREENING) }
                    .getOrElse {
                        android.util.Log.e(TAG, "Failed to check call-screening role.", it)
                        false
                    }
            }
        } else {
            true
        }
    }

    fun isDrawOverlayGranted(context: Context): Boolean {
        return if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
            Settings.canDrawOverlays(context)
        } else {
            true
        }
    }
    
    fun isRecordAudioGranted(context: Context): Boolean {
        return ContextCompat.checkSelfPermission(context, Manifest.permission.RECORD_AUDIO) == PackageManager.PERMISSION_GRANTED
    }

    @Suppress("UNUSED_PARAMETER")
    fun isStoragePermissionGranted(context: Context): Boolean {
        return true // Android 10+ không cần
    }

    fun isForegroundServiceGranted(context: Context): Boolean {
        return if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.P) {
            ContextCompat.checkSelfPermission(context, Manifest.permission.FOREGROUND_SERVICE) == PackageManager.PERMISSION_GRANTED
        } else {
            true
        }
    }
    
    fun isCallDetectionEnabled(context: Context): Boolean {
        return isSpecificAccessibilityServiceEnabled(context, UnifiedAccessibilityService::class.java.name)
    }

    fun isCallCaptionEnabled(context: Context): Boolean {
        return isSpecificAccessibilityServiceEnabled(context, UnifiedAccessibilityService::class.java.name)
    }

    fun isAccessibilityProtectionEnabled(context: Context): Boolean {
        return isSpecificAccessibilityServiceEnabled(context, UnifiedAccessibilityService::class.java.name)
    }

    private fun isSpecificAccessibilityServiceEnabled(context: Context, serviceName: String): Boolean {
        // 1. Check using AccessibilityManager (Standard way - checks if actually running)
        val am = context.getSystemService(Context.ACCESSIBILITY_SERVICE) as AccessibilityManager
        val enabledServices = am.getEnabledAccessibilityServiceList(AccessibilityServiceInfo.FEEDBACK_GENERIC)
        
        if (enabledServices != null) {
            for (service in enabledServices) {
                val enabledServiceInfo = service.resolveInfo.serviceInfo
                if (enabledServiceInfo.packageName == context.packageName && enabledServiceInfo.name == serviceName) {
                    return true
                }
            }
        }

        // 2. Fallback: Check Settings.Secure (Robust way - checks if enabled in settings, even if not currently running/crashed)
        // This fixes the loop issue where the service is enabled but not yet "active" in the manager list.
        try {
            val componentName = "${context.packageName}/$serviceName"
            val enabledServicesSetting = Settings.Secure.getString(
                context.contentResolver,
                Settings.Secure.ENABLED_ACCESSIBILITY_SERVICES
            )
            if (enabledServicesSetting != null) {
                val colonSplitter = android.text.TextUtils.SimpleStringSplitter(':')
                colonSplitter.setString(enabledServicesSetting)
                while (colonSplitter.hasNext()) {
                    val componentNameString = colonSplitter.next()
                    if (componentNameString.equals(componentName, ignoreCase = true)) {
                        return true
                    }
                }
            }
        } catch (e: Exception) {
            e.printStackTrace()
        }

        return false
    }

    fun isNotificationsGranted(context: Context): Boolean {
        return if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
            ContextCompat.checkSelfPermission(context, Manifest.permission.POST_NOTIFICATIONS) == PackageManager.PERMISSION_GRANTED
        } else {
            true
        }
    }

    fun isCallLogGranted(context: Context): Boolean {
        return hasPhoneCallAccess(context)
    }
}
