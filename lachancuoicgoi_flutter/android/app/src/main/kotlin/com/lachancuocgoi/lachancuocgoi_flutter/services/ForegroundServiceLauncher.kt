package com.lachancuocgoi.lachancuocgoi_flutter.services

import android.app.Notification
import android.app.Service
import android.content.Context
import android.content.Intent
import android.content.pm.ServiceInfo
import android.os.Build
import android.util.Log

/**
 * Centralized helpers for starting a foreground service / transitioning a
 * service to the foreground without crashing on Android 12+ restrictions.
 *
 * Replaces the dozen ad-hoc `startForegroundService(intent)` and
 * `startForeground(NOTIFICATION_ID, notification)` call sites that used to
 * throw `ForegroundServiceStartNotAllowedException` (Bug #2) and
 * `MissingForegroundServiceTypeException` (Bug #8) uncaught.
 *
 * All public methods:
 *  - Never throw — failures are logged and reported via the returned
 *    [LaunchResult] enum.
 *  - On Android 12+ when the app is NOT in a foreground-allowed context,
 *    `startForegroundService` will throw `ForegroundServiceStartNotAllowedException`.
 *    We catch it and return [LaunchResult.NOT_ALLOWED]. We do NOT fall back
 *    to `startService()` because that would start a background service that
 *    gets killed within 5 seconds if it doesn't promote to foreground — which
 *    is worse than failing fast and letting the caller decide (e.g. show a
 *    notification instead, or queue the work for later).
 */
object ForegroundServiceLauncher {

    private const val TAG = "ForegroundServiceLauncher"

    /** Outcome of a [safeStartForegroundService] call. */
    enum class LaunchResult {
        /** Foreground service started successfully. */
        SUCCESS,
        /**
         * Android refused to start as foreground — the caller should treat
         * this as a hard failure and NOT attempt `startService()` as a
         * fallback, because the service will be killed within 5s without
         * foreground promotion.
         */
        NOT_ALLOWED,
        /** Threw `SecurityException` (e.g. permission denied). */
        SECURITY_DENIED,
        /** Other unexpected throwable. */
        UNKNOWN_ERROR,
    }

    /**
     * Safely start a foreground service. Catches Android 12+'s
     * `ForegroundServiceStartNotAllowedException` and returns
     * [LaunchResult.NOT_ALLOWED] instead of crashing.
     *
     * Bug #2 fix: was previously crashing `CallScreeningServiceImpl` when
     * invoked from a background context on Android 12+.
     *
     * IMPORTANT: On [LaunchResult.NOT_ALLOWED], the caller MUST NOT fall
     * back to `startService()` — that would start a background service
     * that gets killed within 5s (Android 12+ background execution limits).
     * Instead, the caller should:
     *  - Show a notification to the user, or
     *  - Queue the intent for later delivery when the app becomes foreground, or
     *  - Use `PendingIntent.getActivity()` to launch a visible activity first.
     *
     * @return How the call was resolved. Caller can decide whether to abort.
     */
    fun safeStartForegroundService(
        context: Context,
        intent: Intent,
    ): LaunchResult {
        return try {
            context.startForegroundService(intent)
            LaunchResult.SUCCESS
        } catch (e: Exception) {
            val name = e.javaClass.simpleName
            when {
                name == "ForegroundServiceStartNotAllowedException" -> {
                    // Bug #2 fix: DO NOT fall back to startService().
                    // On Android 12+, a background service that doesn't
                    // promote to foreground within 5s is killed by the system.
                    // Falling back would create a zombie service that dies
                    // silently, wasting resources and confusing the watchdog.
                    Log.w(TAG, "startForegroundService not allowed (app is in background) — returning NOT_ALLOWED", e)
                    LaunchResult.NOT_ALLOWED
                }
                e is SecurityException -> {
                    Log.e(TAG, "startForegroundService denied by SecurityException", e)
                    LaunchResult.SECURITY_DENIED
                }
                else -> {
                    Log.e(TAG, "startForegroundService failed unexpectedly", e)
                    LaunchResult.UNKNOWN_ERROR
                }
            }
        }
    }

    /**
     * Safely transition a [Service] to the foreground.
     *
     * Bug #8 fix: was previously crashing on Android 13+ when the user had not
     * granted `POST_NOTIFICATIONS`, because `startForeground()` then throws
     * `MissingForegroundServiceTypeException` or `ForegroundServiceStartNotAllowedException`.
     *
     * @param service          The Service to promote to foreground.
     * @param id               Notification ID.
     * @param notification     The notification to display.
     * @param foregroundType   One of `ServiceInfo.FOREGROUND_SERVICE_TYPE_*`.
     *                         Pass `0` on API < 29 (will be ignored).
     * @return true if the call succeeded; false if a recoverable error occurred.
     */
    fun safeStartForeground(
        service: Service,
        id: Int,
        notification: Notification,
        foregroundType: Int = 0,
    ): Boolean {
        return try {
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q && foregroundType != 0) {
                service.startForeground(id, notification, foregroundType)
            } else {
                service.startForeground(id, notification)
            }
            true
        } catch (e: Exception) {
            val name = e.javaClass.simpleName
            when (name) {
                "ForegroundServiceStartNotAllowedException",
                "MissingForegroundServiceTypeException",
                "SecurityException" -> {
                    Log.w(TAG, "startForeground failed (${name}) — service will not be promoted to foreground", e)
                    false
                }
                else -> {
                    Log.e(TAG, "startForeground failed unexpectedly", e)
                    false
                }
            }
        }
    }
}
