@file:Suppress("DEPRECATION")

package com.lachancuocgoi.lachancuocgoi_flutter.receiver

import android.content.Context
import android.content.Intent
import android.app.NotificationManager
import android.os.Looper
import android.telephony.TelephonyManager
import androidx.test.core.app.ApplicationProvider
import io.mockk.every
import io.mockk.mockk
import io.mockk.mockkObject
import io.mockk.unmockkObject
import io.mockk.verify
import org.junit.After
import org.junit.Assert.assertNotNull
import org.junit.Assert.assertEquals
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.Before
import org.junit.Test
import org.junit.runner.RunWith
import org.robolectric.RobolectricTestRunner
import org.robolectric.Shadows.shadowOf
import org.robolectric.annotation.Config
import com.lachancuocgoi.lachancuocgoi_flutter.services.NativeBridgeEventSink

/**
 * Tests for [CallReceiver].
 *
 * Bug #6: on Android 13+, `EXTRA_INCOMING_NUMBER` is often `null` because
 *         the system strips it for privacy unless the app is the default
 *         dialer or holds `READ_PHONE_NUMBERS`. The fix tags the call event
 *         with `numberAvailable` so Flutter can ask the user to enter the
 *         number manually if the system stripped it.
 */
@RunWith(RobolectricTestRunner::class)
@Config(sdk = [34])
class CallReceiverTest {

    private lateinit var context: Context
    private lateinit var receiver: CallReceiver

    @Before
    fun setUp() {
        context = ApplicationProvider.getApplicationContext()
        receiver = CallReceiver()
        context.getSharedPreferences("call_session_coordinator", Context.MODE_PRIVATE)
            .edit()
            .clear()
            .commit()
        (context.getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager)
            .cancelAll()
        mockkObject(NativeBridgeEventSink, recordPrivateCalls = false)
        every { NativeBridgeEventSink.sendCallEvent(any()) } returns Unit
        every { NativeBridgeEventSink.sendLog(any(), any(), any()) } returns Unit
        every { NativeBridgeEventSink.sendMonitoringState(any()) } returns Unit
    }

    @After
    fun tearDown() {
        unmockkObject(NativeBridgeEventSink)
        shadowOf(Looper.getMainLooper()).idle()
    }

    // ─── Bug #6: number availability flag ──────────────────────────────

    @Test
    fun `RINGING with valid number sets numberAvailable true`() {
        val intent = Intent(TelephonyManager.ACTION_PHONE_STATE_CHANGED).apply {
            putExtra(TelephonyManager.EXTRA_STATE, TelephonyManager.EXTRA_STATE_RINGING)
            putExtra(TelephonyManager.EXTRA_INCOMING_NUMBER, "+84912345678")
        }
        receiver.onReceive(context, intent)
        shadowOf(Looper.getMainLooper()).idle()

        verify(atLeast = 1) {
            NativeBridgeEventSink.sendCallEvent(match { event ->
                event["type"] == "RINGING" &&
                    event["maskedNumber"] == "••••5678" &&
                    event["numberAvailable"] == true &&
                    !event.containsKey("phoneNumber")
            })
        }
    }

    @Test
    fun `RINGING with null number sets numberAvailable false (Bug 6)`() {
        // Android 13+ privacy: system strips EXTRA_INCOMING_NUMBER.
        val intent = Intent(TelephonyManager.ACTION_PHONE_STATE_CHANGED).apply {
            putExtra(TelephonyManager.EXTRA_STATE, TelephonyManager.EXTRA_STATE_RINGING)
            // Note: no EXTRA_INCOMING_NUMBER
        }
        receiver.onReceive(context, intent)
        shadowOf(Looper.getMainLooper()).idle()

        verify(atLeast = 1) {
            NativeBridgeEventSink.sendCallEvent(match { event ->
                event["type"] == "RINGING" &&
                    event["maskedNumber"] == null &&
                    event["numberAvailable"] == false &&
                    !event.containsKey("phoneNumber")
            })
        }
    }

    @Test
    fun `RINGING with empty-string number also flagged as unavailable`() {
        val intent = Intent(TelephonyManager.ACTION_PHONE_STATE_CHANGED).apply {
            putExtra(TelephonyManager.EXTRA_STATE, TelephonyManager.EXTRA_STATE_RINGING)
            putExtra(TelephonyManager.EXTRA_INCOMING_NUMBER, "")
        }
        receiver.onReceive(context, intent)
        shadowOf(Looper.getMainLooper()).idle()

        verify(atLeast = 1) {
            NativeBridgeEventSink.sendCallEvent(match { event ->
                event["maskedNumber"] == null &&
                    event["numberAvailable"] == false &&
                    !event.containsKey("phoneNumber")
            })
        }
    }

    // ─── IDLE / OFFHOOK also include numberAvailable ───────────────────

    @Test
    fun `IDLE includes numberAvailable flag`() {
        val intent = Intent(TelephonyManager.ACTION_PHONE_STATE_CHANGED).apply {
            putExtra(TelephonyManager.EXTRA_STATE, TelephonyManager.EXTRA_STATE_IDLE)
        }
        receiver.onReceive(context, intent)
        shadowOf(Looper.getMainLooper()).idle()

        verify(atLeast = 1) {
            NativeBridgeEventSink.sendCallEvent(match { event ->
                event["type"] == "IDLE" &&
                    event.containsKey("numberAvailable")
            })
        }
    }

    // ─── Dismiss action is no-op for events ─────────────────────────────

    @Test
    fun `dismiss action does not send call event`() {
        val intent = Intent("ACTION_DISMISS_NOTIFICATION")
        receiver.onReceive(context, intent)
        shadowOf(Looper.getMainLooper()).idle()

        verify(exactly = 0) { NativeBridgeEventSink.sendCallEvent(any()) }
    }

    // ─── Unknown action is a no-op ─────────────────────────────────────

    @Test
    fun `unknown action is silently ignored`() {
        val intent = Intent("com.example.NOTHING")
        receiver.onReceive(context, intent)
        shadowOf(Looper.getMainLooper()).idle()

        verify(exactly = 0) { NativeBridgeEventSink.sendCallEvent(any()) }
    }

    // ─── Consent notification must never open the application ──────────

    @Test
    fun `incoming call notification has actions but no activity intent`() {
        val intent = Intent(TelephonyManager.ACTION_PHONE_STATE_CHANGED).apply {
            putExtra(TelephonyManager.EXTRA_STATE, TelephonyManager.EXTRA_STATE_RINGING)
            putExtra(TelephonyManager.EXTRA_INCOMING_NUMBER, "+84999999999")
        }
        receiver.onReceive(context, intent)
        shadowOf(Looper.getMainLooper()).idle()

        val notificationManager =
            context.getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
        val notifications = shadowOf(notificationManager).allNotifications
        assertEquals(1, notifications.size)
        val notification = notifications.single()
        assertNull(notification.fullScreenIntent)
        assertNull(notification.contentIntent)
        assertNotNull(notification.actions)
        assertEquals(2, notification.actions.size)
    }

    @Test
    fun `No action cancels prompt and emits declined once`() {
        val intent = Intent(TelephonyManager.ACTION_PHONE_STATE_CHANGED).apply {
            putExtra(TelephonyManager.EXTRA_STATE, TelephonyManager.EXTRA_STATE_RINGING)
            putExtra(TelephonyManager.EXTRA_INCOMING_NUMBER, "+84999999999")
        }
        receiver.onReceive(context, intent)
        shadowOf(Looper.getMainLooper()).idle()

        val notificationManager =
            context.getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
        val notification = shadowOf(notificationManager).allNotifications.single()
        notification.actions[1].actionIntent.send()
        shadowOf(Looper.getMainLooper()).idle()

        assertTrue(shadowOf(notificationManager).allNotifications.isEmpty())
        verify(exactly = 1) {
            NativeBridgeEventSink.sendCallEvent(match { event ->
                event["type"] == "MONITORING_DECLINED"
            })
        }
    }

    @Test
    fun `duplicate RINGING broadcasts create one consent session`() {
        val intent = Intent(TelephonyManager.ACTION_PHONE_STATE_CHANGED).apply {
            putExtra(TelephonyManager.EXTRA_STATE, TelephonyManager.EXTRA_STATE_RINGING)
            putExtra(TelephonyManager.EXTRA_INCOMING_NUMBER, "+84912345678")
        }
        receiver.onReceive(context, intent)
        receiver.onReceive(context, intent)
        shadowOf(Looper.getMainLooper()).idle()

        val notificationManager =
            context.getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
        assertEquals(1, shadowOf(notificationManager).allNotifications.size)
        verify(exactly = 1) {
            NativeBridgeEventSink.sendCallEvent(match { it["type"] == "RINGING" })
        }
    }
}
