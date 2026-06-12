package com.lachancuocgoi.lachancuocgoi_flutter

import android.app.NotificationManager
import android.content.Context
import android.os.Build
import androidx.core.app.NotificationManagerCompat
import androidx.test.core.app.ApplicationProvider
import androidx.test.ext.junit.runners.AndroidJUnit4
import org.junit.Assert.assertEquals
import org.junit.Assert.assertNotNull
import org.junit.Assert.assertTrue
import org.junit.Assume.assumeTrue
import org.junit.Before
import org.junit.Test
import org.junit.runner.RunWith

@RunWith(AndroidJUnit4::class)
class NotificationChannelInstrumentationTest {

    companion object {
        private const val LOCKSCREEN_VISIBILITY_NO_OVERRIDE = -1000
    }

    private lateinit var context: Context

    @Before
    fun setUp() {
        context = ApplicationProvider.getApplicationContext()
        // minSdk = 26 so the O+ branch is always taken, but be defensive.
        assumeTrue(
            "Notification channels require API 26+",
            Build.VERSION.SDK_INT >= Build.VERSION_CODES.O
        )
    }

    private fun channel(id: String) =
        NotificationManagerCompat.from(context).getNotificationChannel(id)

    @Test
    fun background_monitoring_channel_exists_with_low_importance() {
        val ch = channel("BackgroundMonitoringChannel")
        assertNotNull("BackgroundMonitoringChannel must exist", ch)
        assertEquals(
            NotificationManager.IMPORTANCE_LOW,
            ch!!.importance
        )
    }

    @Test
    fun incoming_call_channel_exists_with_high_importance_and_vibration() {
        val ch = channel("IncomingCallChannel")
        assertNotNull("IncomingCallChannel must exist", ch)
        assertEquals(
            NotificationManager.IMPORTANCE_HIGH,
            ch!!.importance
        )
        assertEquals(
            "IncomingCallChannel should vibrate",
            true,
            ch.shouldVibrate()
        )
        assertTrue(
            "IncomingCallChannel must not force private lock-screen content",
            ch.lockscreenVisibility == android.app.Notification.VISIBILITY_PUBLIC ||
                ch.lockscreenVisibility == LOCKSCREEN_VISIBILITY_NO_OVERRIDE
        )
    }

    @Test
    fun media_projection_channel_exists_with_high_importance() {
        val ch = channel("media_projection_channel")
        assertNotNull("media_projection_channel must exist", ch)
        assertEquals(
            NotificationManager.IMPORTANCE_HIGH,
            ch!!.importance
        )
    }
}
