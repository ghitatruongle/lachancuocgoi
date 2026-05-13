package com.example.lachancuoicgoi.permissions;

import android.app.AppOpsManager;
import android.content.Context;
import android.content.Intent;
import android.net.Uri;
import android.os.Build;
import android.provider.Settings;
import android.util.Log;

/**
 * Quản lý kiểm tra và yêu cầu các quyền hệ thống đặc biệt:
 * - Accessibility Service
 * - Overlay (Draw over other apps)
 * - Notification (Android 13+)
 */
public class PermissionChecker {
    private static final String TAG = "PermissionChecker";
    private final Context context;

    public PermissionChecker(Context context) {
        this.context = context;
    }

    /**
     * Kiểm tra quyền Accessibility Service đã được cấp chưa
     */
    public boolean hasAccessibilityPermission() {
        try {
            int accessibilityEnabled = Settings.Secure.getInt(
                context.getContentResolver(),
                Settings.Secure.ACCESSIBILITY_ENABLED
            );
            
            if (accessibilityEnabled == 1) {
                // Kiểm tra xem service cụ thể của app đã được bật chưa
                String enabledServices = Settings.Secure.getString(
                    context.getContentResolver(),
                    Settings.Secure.ENABLED_ACCESSIBILITY_SERVICES
                );
                
                if (enabledServices != null && !enabledServices.isEmpty()) {
                    return enabledServices.contains(context.getPackageName());
                }
            }
            return false;
        } catch (Settings.SettingNotFoundException e) {
            Log.e(TAG, "Không tìm thấy setting Accessibility", e);
            return false;
        }
    }

    /**
     * Kiểm tra quyền Overlay (SYSTEM_ALERT_WINDOW) đã được cấp chưa
     */
    public boolean hasOverlayPermission() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
            return Settings.canDrawOverlays(context);
        }
        // Dưới Android 6.0 không cần quyền này
        return true;
    }

    /**
     * Kiểm tra quyền Notification đã được cấp chưa (Android 13+)
     */
    public boolean hasNotificationPermission() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
            AppOpsManager appOps = (AppOpsManager) context.getSystemService(Context.APP_OPS_SERVICE);
            int mode = appOps.unsafeCheckOpNoThrow(
                AppOpsManager.OPSTR_POST_NOTIFICATION,
                android.os.Process.myUid(),
                context.getPackageName()
            );
            return mode == AppOpsManager.MODE_ALLOWED;
        }
        // Dưới Android 13, notification permission được cấp mặc định khi cài đặt
        return true;
    }

    /**
     * Trả về Intent để mở màn hình cài đặt Accessibility Service
     */
    public Intent getAccessibilityIntent() {
        Intent intent = new Intent(Settings.ACTION_ACCESSIBILITY_SETTINGS);
        intent.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK);
        return intent;
    }

    /**
     * Trả về Intent để mở màn hình cài đặt Overlay Permission
     */
    public Intent getOverlayIntent() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
            Intent intent = new Intent(
                Settings.ACTION_MANAGE_OVERLAY_PERMISSION,
                Uri.parse("package:" + context.getPackageName())
            );
            intent.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK);
            return intent;
        }
        return null;
    }

    /**
     * Trả về Intent để mở màn hình cài đặt Notification Permission (Android 13+)
     */
    public Intent getNotificationIntent() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
            Intent intent = new Intent(Settings.ACTION_APP_NOTIFICATION_SETTINGS);
            intent.putExtra(Settings.EXTRA_APP_PACKAGE, context.getPackageName());
            intent.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK);
            return intent;
        }
        return null;
    }

    /**
     * Lấy trạng thái tất cả các quyền dưới dạng Map
     */
    public java.util.Map<String, Boolean> getAllPermissionsStatus() {
        java.util.Map<String, Boolean> status = new java.util.HashMap<>();
        status.put("accessibility", hasAccessibilityPermission());
        status.put("overlay", hasOverlayPermission());
        status.put("notification", hasNotificationPermission());
        return status;
    }
}
