package com.lachancuocgoi.lachancuocgoi_flutter

import android.Manifest
import android.app.NotificationManager
import android.content.Context
import android.content.Intent
import android.content.pm.PackageManager
import android.media.AudioAttributes
import android.media.AudioFocusRequest
import android.media.AudioManager
import android.os.SystemClock
import android.provider.Settings
import android.util.Log
import androidx.core.content.ContextCompat
import androidx.test.core.app.ApplicationProvider
import androidx.test.ext.junit.runners.AndroidJUnit4
import androidx.test.platform.app.InstrumentationRegistry
import androidx.test.uiautomator.UiDevice
import com.lachancuocgoi.lachancuocgoi_flutter.diagnostics.MonitoringPerfProbe
import com.lachancuocgoi.lachancuocgoi_flutter.helpers.PermissionHelpers
import com.lachancuocgoi.lachancuocgoi_flutter.receiver.CallActionReceiver
import com.lachancuocgoi.lachancuocgoi_flutter.services.BackgroundMonitoringService
import com.lachancuocgoi.lachancuocgoi_flutter.services.CallSessionCoordinator
import com.lachancuocgoi.lachancuocgoi_flutter.ui.OverlayManager
import java.io.File
import org.junit.After
import org.junit.Assert.assertNotNull
import org.junit.Assert.assertTrue
import org.junit.Before
import org.junit.Test
import org.junit.runner.RunWith

/** Physical-device timing tests for the incoming-call monitoring startup path. */
@RunWith(AndroidJUnit4::class)
class MonitoringStartupDeviceTest {
    private val instrumentation = InstrumentationRegistry.getInstrumentation()
    private val context = ApplicationProvider.getApplicationContext<Context>()
    private val device = UiDevice.getInstance(instrumentation)

    @Before
    fun setUp() {
        assertTrue(
            "This test must use -PmonitoringDevicePerf=true",
            BuildConfig.MONITORING_PERF_PROBES,
        )
        assertTrue("SYSTEM_ALERT_WINDOW must be granted", Settings.canDrawOverlays(context))
        assertTrue(
            "RECORD_AUDIO must be granted",
            ContextCompat.checkSelfPermission(context, Manifest.permission.RECORD_AUDIO) ==
                PackageManager.PERMISSION_GRANTED,
        )
        device.wakeUp()
        device.pressHome()
        device.waitForIdle()
        cleanSyntheticSession()
    }

    @After
    fun tearDown() {
        MonitoringPerfProbe.stopRun("test_teardown")
        cleanSyntheticSession()
    }

    @Test
    fun coldAndWarmAcceptPipeline_reportsActualDeviceStages() {
        assertTrue(
            "Do not launch MainActivity before the cold run",
            (context.applicationContext as MainApplication).existingFlutterEngine() == null,
        )

        val cold = runAcceptScenario("cold")
        waitForAccessibilityRetriesToFinish()
        cleanSyntheticSession()
        waitUntil(5_000L) { !BackgroundMonitoringService.isRunning }
        SystemClock.sleep(750L)

        val warm = runAcceptScenario("warm")

        val coldDraw = deltaMs(cold, "accept_enter", "overlay_first_visible_predraw")
        val warmDraw = deltaMs(warm, "accept_enter", "overlay_first_visible_predraw")
        val coldEngine = spanMs(cold, "flutter_engine_total")
        val warmEngine = spanMs(warm, "flutter_engine_total")

        Log.i(
            RESULT_TAG,
            "COMPARISON|cold_draw_ms=$coldDraw|warm_draw_ms=$warmDraw|" +
                "cold_engine_ms=$coldEngine|warm_engine_ms=$warmEngine",
        )

        assertNotNull("Cold overlay never reached a visible pre-draw", coldDraw)
        assertNotNull("Warm overlay never reached a visible pre-draw", warmDraw)
        assertNotNull("Cold Flutter engine stage was not recorded", coldEngine)
        assertNotNull("Warm Flutter engine stage was not recorded", warmEngine)
        assertTrue("Cold overlay visibility exceeded 2 seconds: $coldDraw ms", coldDraw!! < 2_000.0)
        assertTrue("Warm overlay visibility exceeded 2 seconds: $warmDraw ms", warmDraw!! < 2_000.0)
    }

    @Test
    fun audioFocusRoundTrip_reportsMainThreadBinderLatency() {
        MonitoringPerfProbe.startRun("audio-focus-baseline")
        val audioManager = context.getSystemService(Context.AUDIO_SERVICE) as AudioManager
        val request = AudioFocusRequest.Builder(AudioManager.AUDIOFOCUS_GAIN)
            .setAudioAttributes(
                AudioAttributes.Builder()
                    .setUsage(AudioAttributes.USAGE_ASSISTANT)
                    .setContentType(AudioAttributes.CONTENT_TYPE_SPEECH)
                    .build(),
            )
            .setWillPauseWhenDucked(true)
            .setAcceptsDelayedFocusGain(true)
            .setOnAudioFocusChangeListener { }
            .build()

        var result = AudioManager.AUDIOFOCUS_REQUEST_FAILED
        instrumentation.runOnMainSync {
            val token = MonitoringPerfProbe.begin("test_audio_focus_request_ipc")
            try {
                result = audioManager.requestAudioFocus(request)
            } finally {
                MonitoringPerfProbe.end(token, "result=$result")
            }
        }
        instrumentation.runOnMainSync {
            val token = MonitoringPerfProbe.begin("test_audio_focus_abandon_ipc")
            try {
                audioManager.abandonAudioFocusRequest(request)
            } finally {
                MonitoringPerfProbe.end(token)
            }
        }

        MonitoringPerfProbe.dumpToLog("audio-focus-baseline")
        val events = MonitoringPerfProbe.snapshot()
        val requestMs = spanMs(events, "test_audio_focus_request_ipc")
        Log.i(RESULT_TAG, "AUDIO_FOCUS|request_ms=$requestMs|result=$result")
        assertNotNull("Audio-focus request timing was not recorded", requestMs)
    }

    private fun runAcceptScenario(label: String): List<MonitoringPerfProbe.Event> {
        MonitoringPerfProbe.startRun(label)
        instrumentation.runOnMainSync {
            CallSessionCoordinator.onIncomingCall(
                context = context,
                source = CallSessionCoordinator.SYSTEM_CALL_SOURCE,
                maskedNumber = null,
                numberAvailable = false,
                reason = "instrumentation_$label",
            )
            val sessionId = context.getSharedPreferences(CALL_SESSION_PREFS, Context.MODE_PRIVATE)
                .getString("session_id", null)
            check(!sessionId.isNullOrBlank()) { "Synthetic session was not created" }

            CallActionReceiver().onReceive(
                context,
                Intent(context, CallActionReceiver::class.java).apply {
                    action = CallSessionCoordinator.ACTION_ACCEPT
                    putExtra(CallSessionCoordinator.EXTRA_SESSION_ID, sessionId)
                },
            )
        }

        val startupArrived = waitUntil(15_000L) {
            MonitoringPerfProbe.hasStage("overlay_first_visible_predraw") &&
                MonitoringPerfProbe.hasStage("flutter_engine_total_end") &&
                MonitoringPerfProbe.hasStage("monitoring_service_running") &&
                MonitoringPerfProbe.hasStage("speech_main_task_end")
        }
        assertTrue("Startup stages timed out for $label", startupArrived)

        waitUntil(5_000L) {
            MonitoringPerfProbe.hasStage("speech_on_ready") ||
                MonitoringPerfProbe.hasStage("speech_on_error")
        }
        waitUntil(4_000L) {
            MonitoringPerfProbe.hasStage("accessibility_answer_retry_finished") ||
                MonitoringPerfProbe.hasStage("accessibility_action_not_dispatched")
        }
        waitUntil(8_000L) {
            MonitoringPerfProbe.hasStage("vosk_model_ready") ||
                MonitoringPerfProbe.hasStage("vosk_model_load_failed") ||
                MonitoringPerfProbe.hasStage("vosk_model_unpack_failed")
        }

        val screenshot = File(
            context.getExternalFilesDir(null),
            "monitoring_startup_${label}.png",
        )
        val screenshotSaved = device.takeScreenshot(screenshot)
        Log.i(RESULT_TAG, "SCREENSHOT|label=$label|saved=$screenshotSaved|path=${screenshot.absolutePath}")

        MonitoringPerfProbe.dumpToLog(label)
        val events = MonitoringPerfProbe.snapshot()
        logSummary(label, events)
        MonitoringPerfProbe.stopRun("scenario_complete")
        return events
    }

    private fun logSummary(label: String, events: List<MonitoringPerfProbe.Event>) {
        val accessibilityScans = events.filter { it.stage == "accessibility_answer_scan_end" }
        val accessibilityBusyMs = accessibilityScans.sumOf { it.wallMs ?: 0.0 }
        val summary = buildString {
            append("SUMMARY|label=$label")
            append("|receiver_ms=${spanMs(events, "call_action_receiver")}")
            append("|overlay_add_ms=${spanMs(events, "overlay_add_view")}")
            append("|overlay_visible_ms=${deltaMs(events, "accept_enter", "overlay_first_visible_predraw")}")
            append("|fgs_request_ms=${spanMs(events, "accept_fgs_start_request")}")
            append("|service_on_create_ms=${spanMs(events, "monitoring_service_on_create")}")
            append("|foreground_promote_ms=${spanMs(events, "monitoring_service_promote_foreground")}")
            append("|engine_ms=${spanMs(events, "flutter_engine_total")}")
            append("|engine_ctor_ms=${spanMs(events, "flutter_engine_constructor")}")
            append("|dart_request_ms=${spanMs(events, "flutter_dart_entrypoint_request")}")
            append("|speech_create_ms=${spanMs(events, "speech_create_recognizer")}")
            append("|speech_start_ipc_ms=${spanMs(events, "speech_start_listening_ipc")}")
            append("|accessibility_scans=${accessibilityScans.size}")
            append("|accessibility_busy_ms=$accessibilityBusyMs")
            append("|audio_focus_called=${events.any { it.stage == "audio_focus_request_ipc_end" }}")
            append("|google_available=${detailFor(events, "speech_recognition_availability")}")
        }
        Log.i(RESULT_TAG, summary)
    }

    private fun waitForAccessibilityRetriesToFinish() {
        waitUntil(4_000L) {
            MonitoringPerfProbe.hasStage("accessibility_answer_retry_finished") ||
                MonitoringPerfProbe.hasStage("accessibility_action_not_dispatched")
        }
    }

    private fun cleanSyntheticSession() {
        instrumentation.runOnMainSync {
            OverlayManager.removeAll(context)
            context.stopService(
                Intent(context, BackgroundMonitoringService::class.java).apply {
                    action = BackgroundMonitoringService.ACTION_STOP
                },
            )
            context.getSharedPreferences(CALL_SESSION_PREFS, Context.MODE_PRIVATE)
                .edit()
                .clear()
                .commit()
            context.getSharedPreferences(BackgroundMonitoringService.WATCHDOG_PREFS, Context.MODE_PRIVATE)
                .edit()
                .clear()
                .commit()
            (context.getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager)
                .cancel(CallSessionCoordinator.INCOMING_NOTIFICATION_ID)
        }
    }

    private fun waitUntil(timeoutMs: Long, condition: () -> Boolean): Boolean {
        val deadline = SystemClock.elapsedRealtime() + timeoutMs
        while (SystemClock.elapsedRealtime() < deadline) {
            if (condition()) return true
            SystemClock.sleep(25L)
        }
        return condition()
    }

    private fun spanMs(events: List<MonitoringPerfProbe.Event>, stage: String): Double? =
        events.lastOrNull { it.stage == "${stage}_end" }?.wallMs

    private fun deltaMs(
        events: List<MonitoringPerfProbe.Event>,
        fromStage: String,
        toStage: String,
    ): Double? {
        val from = events.firstOrNull { it.stage == fromStage }?.atMs ?: return null
        val to = events.firstOrNull { it.stage == toStage }?.atMs ?: return null
        return to - from
    }

    private fun detailFor(events: List<MonitoringPerfProbe.Event>, stage: String): String =
        events.lastOrNull { it.stage == stage }?.details.orEmpty()

    companion object {
        private const val TAG = "MonitoringStartupTest"
        private const val RESULT_TAG = "MON_PERF_RESULT"
        private const val CALL_SESSION_PREFS = "call_session_coordinator"
    }
}
