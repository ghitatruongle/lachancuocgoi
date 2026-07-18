package com.lachancuocgoi.lachancuocgoi_flutter.services

import android.os.Looper
import io.flutter.plugin.common.MethodChannel
import io.mockk.mockk
import io.mockk.verify
import org.junit.After
import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Test
import org.junit.runner.RunWith
import org.robolectric.RobolectricTestRunner
import org.robolectric.Shadows.shadowOf
import org.robolectric.annotation.Config

@RunWith(RobolectricTestRunner::class)
@Config(sdk = [34])
class MonitoringStartCoordinatorTest {

    @After
    fun tearDown() {
        MonitoringStartCoordinator.cancel()
        shadowOf(Looper.getMainLooper()).idle()
    }

    @Test
    fun `service confirmation completes typed result exactly once`() {
        val result = mockk<MethodChannel.Result>(relaxed = true)
        assertTrue(MonitoringStartCoordinator.begin(result))

        MonitoringStartCoordinator.complete(
            MonitoringStartResponse(
                MonitoringStartStatus.STARTED,
                "started",
            )
        )
        shadowOf(Looper.getMainLooper()).idle()

        MonitoringStartCoordinator.complete(
            MonitoringStartResponse(
                MonitoringStartStatus.NATIVE_FAILURE,
                "late failure",
            )
        )
        shadowOf(Looper.getMainLooper()).idle()

        verify(exactly = 1) {
            result.success(match { payload ->
                @Suppress("UNCHECKED_CAST")
                (payload as Map<String, String>)["status"] == "started"
            })
        }
        assertFalse(MonitoringStartCoordinator.isPending())
    }

    @Test
    fun `second start cannot replace pending result`() {
        val first = mockk<MethodChannel.Result>(relaxed = true)
        val second = mockk<MethodChannel.Result>(relaxed = true)

        assertTrue(MonitoringStartCoordinator.begin(first))
        assertFalse(MonitoringStartCoordinator.begin(second))
    }
}
