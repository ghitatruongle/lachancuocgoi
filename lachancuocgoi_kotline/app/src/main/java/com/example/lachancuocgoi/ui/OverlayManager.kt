package com.example.lachancuocgoi.ui

import android.annotation.SuppressLint
import android.content.Context
import android.content.Intent
import android.graphics.PixelFormat
import android.os.Build
import android.view.Gravity
import android.view.WindowManager
import androidx.compose.animation.AnimatedVisibility
import androidx.compose.animation.core.tween
import androidx.compose.animation.fadeIn
import androidx.compose.animation.fadeOut
import androidx.compose.animation.scaleIn
import androidx.compose.animation.scaleOut
import androidx.compose.foundation.background
import androidx.compose.foundation.gestures.detectDragGestures
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.Close
import androidx.compose.material.icons.filled.Warning
import androidx.compose.material3.*
import androidx.compose.runtime.*
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.input.pointer.pointerInput
import androidx.compose.ui.platform.ComposeView
import androidx.compose.ui.platform.ViewCompositionStrategy
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import androidx.lifecycle.Lifecycle
import androidx.lifecycle.setViewTreeLifecycleOwner
import androidx.savedstate.setViewTreeSavedStateRegistryOwner
import androidx.lifecycle.setViewTreeViewModelStoreOwner
import com.example.lachancuocgoi.ui.components.ComposeOverlayLifecycleOwner
import com.example.lachancuocgoi.ui.components.WaveformVisualizer
import com.example.lachancuocgoi.ui.theme.LachancuocgoiTheme
import kotlinx.coroutines.delay

object OverlayManager {
    private var windowManager: WindowManager? = null

    // Compose Views
    private var alertOverlayView: ComposeView? = null
    private var monitoringOverlayView: ComposeView? = null
    private var incomingCallOverlayView: ComposeView? = null

    // State holders mapped to Compose
    var rmsValue by mutableFloatStateOf(0f)
    var rmsTick by mutableIntStateOf(0)
    var monitoringStartTime by mutableLongStateOf(0L)

    private fun getWindowManager(context: Context): WindowManager {
        if (windowManager == null) {
            windowManager = context.getSystemService(Context.WINDOW_SERVICE) as WindowManager
        }
        return windowManager!!
    }

    private fun createComposeOverlay(context: Context, layoutParams: WindowManager.LayoutParams, content: @Composable () -> Unit): ComposeView {
        val wm = getWindowManager(context)
        val composeView = ComposeView(context).apply {
            setViewCompositionStrategy(ViewCompositionStrategy.DisposeOnViewTreeLifecycleDestroyed)
            
            val lifecycleOwner = ComposeOverlayLifecycleOwner()
            lifecycleOwner.performRestore(null)
            lifecycleOwner.handleLifecycleEvent(Lifecycle.Event.ON_CREATE)
            lifecycleOwner.handleLifecycleEvent(Lifecycle.Event.ON_START)
            lifecycleOwner.handleLifecycleEvent(Lifecycle.Event.ON_RESUME)
            
            this.setViewTreeLifecycleOwner(lifecycleOwner)
            this.setViewTreeSavedStateRegistryOwner(lifecycleOwner)
            this.setViewTreeViewModelStoreOwner(lifecycleOwner)

            setContent {
                LachancuocgoiTheme {
                    content()
                }
            }
        }
        wm.addView(composeView, layoutParams)
        return composeView
    }

    fun showRedAlert(context: Context, reason: String) {
        showAlert(context, Color(0xFFF44336), "CẢNH BÁO LỪA ĐẢO!", reason)
    }

    fun showOrangeAlert(context: Context, reason: String) {
        showAlert(context, Color(0xFFFF9800), "CẢNH BÁO NGUY CƠ", reason)
    }

    private fun showAlert(context: Context, color: Color, title: String, summary: String) {
        removeAlertOverlay(context)
        vibrate(context)

        val params = WindowManager.LayoutParams(
            WindowManager.LayoutParams.MATCH_PARENT,
            WindowManager.LayoutParams.WRAP_CONTENT,
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                WindowManager.LayoutParams.TYPE_APPLICATION_OVERLAY
            } else {
                @Suppress("DEPRECATION") WindowManager.LayoutParams.TYPE_PHONE
            },
            WindowManager.LayoutParams.FLAG_NOT_TOUCH_MODAL or WindowManager.LayoutParams.FLAG_LAYOUT_IN_SCREEN,
            PixelFormat.TRANSLUCENT
        ).apply { gravity = Gravity.CENTER }

        alertOverlayView = createComposeOverlay(context, params) {
            var visible by remember { mutableStateOf(false) }
            LaunchedEffect(Unit) { visible = true }

            Box(modifier = Modifier.fillMaxSize(), contentAlignment = Alignment.Center) {
                AnimatedVisibility(
                    visible = visible,
                    enter = scaleIn(tween(300)) + fadeIn(tween(300)),
                    exit = scaleOut(tween(200)) + fadeOut(tween(200))
                ) {
                    Card(
                        modifier = Modifier.padding(24.dp).fillMaxWidth(),
                        colors = CardDefaults.cardColors(containerColor = color.copy(alpha = 0.95f)),
                        shape = RoundedCornerShape(16.dp),
                        elevation = CardDefaults.cardElevation(8.dp)
                    ) {
                        Column(
                            modifier = Modifier.padding(20.dp),
                            horizontalAlignment = Alignment.CenterHorizontally
                        ) {
                            Icon(Icons.Filled.Warning, contentDescription = null, tint = Color.White, modifier = Modifier.size(48.dp))
                            Spacer(Modifier.height(8.dp))
                            Text(title, color = Color.White, fontWeight = FontWeight.Bold, fontSize = 20.sp)
                            Spacer(Modifier.height(4.dp))
                            Text(summary, color = Color.White, fontSize = 16.sp, textAlign = androidx.compose.ui.text.style.TextAlign.Center)
                            Spacer(Modifier.height(16.dp))
                            Button(
                                onClick = {
                                    visible = false
                                    removeAlertOverlay(context)
                                },
                                colors = ButtonDefaults.buttonColors(containerColor = Color.White)
                            ) {
                                Text("ĐÃ HIỂU", color = color, fontWeight = FontWeight.Bold)
                            }
                        }
                    }
                }
            }
        }
    }

    fun removeAlertOverlay(context: Context) {
        alertOverlayView?.let {
            try { getWindowManager(context).removeView(it) } catch (e: Exception) {}
            alertOverlayView = null
        }
    }

    fun showIncomingCallOverlay(context: Context, callerInfo: String) {
        if (incomingCallOverlayView != null) return

        val params = WindowManager.LayoutParams(
            WindowManager.LayoutParams.MATCH_PARENT,
            WindowManager.LayoutParams.WRAP_CONTENT,
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                WindowManager.LayoutParams.TYPE_APPLICATION_OVERLAY
            } else {
                @Suppress("DEPRECATION") WindowManager.LayoutParams.TYPE_PHONE
            },
            WindowManager.LayoutParams.FLAG_NOT_TOUCH_MODAL or WindowManager.LayoutParams.FLAG_LAYOUT_IN_SCREEN or WindowManager.LayoutParams.FLAG_WATCH_OUTSIDE_TOUCH,
            PixelFormat.TRANSLUCENT
        ).apply {
            gravity = Gravity.TOP
            y = 50
        }

        incomingCallOverlayView = createComposeOverlay(context, params) {
            var visible by remember { mutableStateOf(false) }
            LaunchedEffect(Unit) { visible = true }

            Box(
                modifier = Modifier.fillMaxSize().padding(16.dp)
            ) {
                AnimatedVisibility(
                    visible = visible,
                    enter = scaleIn(tween(300)) + fadeIn(tween(300)),
                    exit = scaleOut(tween(200)) + fadeOut(tween(200))
                ) {
                    Card(
                        modifier = Modifier
                            .fillMaxWidth()
                            .pointerInput(Unit) {
                                detectDragGestures { change, dragAmount ->
                                    change.consume()
                                    if (dragAmount.y < -30) {
                                        visible = false
                                        removeIncomingCallOverlay(context)
                                    }
                                }
                            },
                        colors = CardDefaults.cardColors(containerColor = MaterialTheme.colorScheme.surfaceVariant),
                        shape = RoundedCornerShape(16.dp),
                        elevation = CardDefaults.cardElevation(8.dp)
                    ) {
                        Column(modifier = Modifier.padding(16.dp), horizontalAlignment = Alignment.CenterHorizontally) {
                            Text("Giám sát cuộc gọi này?", style = MaterialTheme.typography.titleMedium, fontWeight = FontWeight.Bold)
                            Spacer(Modifier.height(4.dp))
                            Text(callerInfo, style = MaterialTheme.typography.bodyLarge, color = MaterialTheme.colorScheme.primary)
                            Spacer(Modifier.height(16.dp))
                            Row(modifier = Modifier.fillMaxWidth(), horizontalArrangement = Arrangement.SpaceEvenly) {
                                OutlinedButton(onClick = { visible = false; removeIncomingCallOverlay(context) }) {
                                    Text("Bỏ qua")
                                }
                                Button(onClick = {
                                    visible = false
                                    val monitorIntent = Intent(context, com.example.lachancuocgoi.services.BackgroundMonitoringService::class.java).apply {
                                        action = com.example.lachancuocgoi.services.BackgroundMonitoringService.ACTION_START
                                        putExtra("PHONE_NUMBER", callerInfo)
                                    }
                                    if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                                        context.startForegroundService(monitorIntent)
                                    } else {
                                        context.startService(monitorIntent)
                                    }
                                    removeIncomingCallOverlay(context)
                                }) {
                                    Text("Bật Giám sát")
                                }
                            }
                        }
                    }
                }
            }
        }
    }

    fun removeIncomingCallOverlay(context: Context) {
        incomingCallOverlayView?.let {
            try { getWindowManager(context).removeView(it) } catch (e: Exception) {}
            incomingCallOverlayView = null
        }
    }

    fun showMonitoringOverlay(context: Context) {
        if (monitoringOverlayView != null) return
        monitoringStartTime = System.currentTimeMillis()

        val params = WindowManager.LayoutParams(
            WindowManager.LayoutParams.MATCH_PARENT,
            (90 * context.resources.displayMetrics.density).toInt(), // 90dp height mapping
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                WindowManager.LayoutParams.TYPE_APPLICATION_OVERLAY
            } else {
                @Suppress("DEPRECATION") WindowManager.LayoutParams.TYPE_PHONE
            },
            WindowManager.LayoutParams.FLAG_NOT_FOCUSABLE or WindowManager.LayoutParams.FLAG_LAYOUT_IN_SCREEN,
            PixelFormat.TRANSLUCENT
        ).apply { gravity = Gravity.TOP }

        monitoringOverlayView = createComposeOverlay(context, params) {
            // Live Timer Logic
            var currentTime by remember { mutableLongStateOf(System.currentTimeMillis()) }
            LaunchedEffect(Unit) {
                while (true) {
                    delay(1000)
                    currentTime = System.currentTimeMillis()
                }
            }
            val millis = currentTime - monitoringStartTime
            val seconds = (millis / 1000).toInt()
            val timeString = String.format("%02d:%02d", seconds / 60, seconds % 60)

            Surface(
                modifier = Modifier.fillMaxSize(),
                color = MaterialTheme.colorScheme.surface.copy(alpha = 0.95f),
                shape = RoundedCornerShape(bottomStart = 16.dp, bottomEnd = 16.dp),
                shadowElevation = 8.dp
            ) {
                Row(
                    modifier = Modifier.padding(horizontal = 16.dp, vertical = 12.dp),
                    horizontalArrangement = Arrangement.SpaceBetween,
                    verticalAlignment = Alignment.CenterVertically
                ) {
                    Row(verticalAlignment = Alignment.CenterVertically) {
                        Surface(
                            shape = RoundedCornerShape(8.dp),
                            color = MaterialTheme.colorScheme.primaryContainer,
                            modifier = Modifier.padding(end = 12.dp)
                        ) {
                            Text(
                                "AI", 
                                color = MaterialTheme.colorScheme.primary,
                                modifier = Modifier.padding(horizontal = 8.dp, vertical = 4.dp),
                                fontWeight = FontWeight.Bold,
                                fontSize = 12.sp
                            )
                        }
                        Column {
                            Text("Đang theo dõi", style = MaterialTheme.typography.bodyMedium, fontWeight = FontWeight.Bold)
                            Text(timeString, style = MaterialTheme.typography.bodySmall, color = MaterialTheme.colorScheme.onSurfaceVariant)
                        }
                    }
                    
                    // Waveform View injected purely via Compose
                    Box(modifier = Modifier.weight(1f).height(40.dp).padding(horizontal = 16.dp)) {
                        WaveformVisualizer(
                            rmsDb = rmsValue,
                            tick = rmsTick,
                            color = MaterialTheme.colorScheme.primary,
                            modifier = Modifier.fillMaxSize()
                        )
                    }

                    // Stop Button
                    IconButton(
                        onClick = { stopMonitoring(context) },
                        modifier = Modifier.background(MaterialTheme.colorScheme.errorContainer, shape = RoundedCornerShape(12.dp))
                    ) {
                        Icon(Icons.Filled.Close, contentDescription = "Dừng", tint = MaterialTheme.colorScheme.error)
                    }
                }
            }
        }
    }

    fun updateWaveform(rmsDb: Float) {
        rmsValue = rmsDb
        rmsTick++
    }

    private fun stopMonitoring(context: Context) {
        try {
            val stopIntent = Intent(context, com.example.lachancuocgoi.services.BackgroundMonitoringService::class.java).apply {
                action = com.example.lachancuocgoi.services.BackgroundMonitoringService.ACTION_STOP
            }
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                context.startForegroundService(stopIntent)
            } else {
                context.startService(stopIntent)
            }
        } catch (e: Exception) {}
    }

    fun hideMonitoringOverlay(context: Context) {
        monitoringOverlayView?.let {
            try { getWindowManager(context).removeView(it) } catch (e: Exception) {}
            monitoringOverlayView = null
        }
    }

    private fun vibrate(context: Context) {
        try {
            val vibrator = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
                val vibratorManager = context.getSystemService(Context.VIBRATOR_MANAGER_SERVICE) as android.os.VibratorManager
                vibratorManager.defaultVibrator
            } else {
                @Suppress("DEPRECATION") context.getSystemService(Context.VIBRATOR_SERVICE) as android.os.Vibrator
            }
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                vibrator.vibrate(android.os.VibrationEffect.createOneShot(500, android.os.VibrationEffect.DEFAULT_AMPLITUDE))
            } else {
                @Suppress("DEPRECATION") vibrator.vibrate(500)
            }
        } catch (e: Exception) {}
    }

    fun removeAll(context: Context) {
        removeAlertOverlay(context)
        hideMonitoringOverlay(context)
        removeIncomingCallOverlay(context)
    }
}
