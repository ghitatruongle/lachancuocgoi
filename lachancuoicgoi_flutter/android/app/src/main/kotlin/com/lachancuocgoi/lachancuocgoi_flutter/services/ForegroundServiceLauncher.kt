package com.lachancuocgoi.lachancuocgoi_flutter.services

import android.app.Notification
import android.app.Service
import android.content.Context
import android.content.Intent
import android.content.pm.ServiceInfo
import android.os.Build
import android.util.Log

object ForegroundServiceLauncher {

    private const val TAG = "ForegroundServiceLauncher"

    enum class LaunchResult {

        SUCCESS,

        NOT_ALLOWED,

        SECURITY_DENIED,

        UNKNOWN_ERROR,
    }

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

