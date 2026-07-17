package com.lachancuocgoi.lachancuocgoi_flutter

import android.content.Context
import android.content.Intent
import androidx.test.core.app.ApplicationProvider
import androidx.test.ext.junit.runners.AndroidJUnit4
import androidx.test.platform.app.InstrumentationRegistry
import androidx.test.uiautomator.By
import androidx.test.uiautomator.UiDevice
import androidx.test.uiautomator.Until
import java.io.File
import org.junit.After
import org.junit.Assert.assertTrue
import org.junit.Before
import org.junit.Test
import org.junit.runner.RunWith

/**
 * Drives the app via UIAutomator at the device level. The activity is launched
 * through instrumentation so Android background-start restrictions do not make
 * the test flaky on physical devices.
 */
@RunWith(AndroidJUnit4::class)
class EndToEndLaunchTest {

    private lateinit var device: UiDevice
    private lateinit var packageName: String
    private var activity: MainActivity? = null

    @Before
    fun setUp() {
        device = UiDevice.getInstance(InstrumentationRegistry.getInstrumentation())
        val ctx = ApplicationProvider.getApplicationContext<Context>()
        packageName = ctx.packageName
    }

    @After
    fun tearDown() {
        activity?.finish()
        InstrumentationRegistry.getInstrumentation().waitForIdleSync()
        activity = null
    }

    @Test
    fun launches_and_reaches_a_window() {
        val instrumentation = InstrumentationRegistry.getInstrumentation()
        val ctx = ApplicationProvider.getApplicationContext<Context>()
        device.pressHome()
        device.waitForIdle()

        val launchIntent = Intent(ctx, MainActivity::class.java).apply {
            addFlags(Intent.FLAG_ACTIVITY_CLEAR_TASK or Intent.FLAG_ACTIVITY_NEW_TASK)
        }
        activity = instrumentation.startActivitySync(launchIntent) as MainActivity
        instrumentation.waitForIdleSync()

        val windowAppeared = device.wait(
            Until.hasObject(By.pkg(packageName)),
            20_000L
        )
        assertTrue(
            "Expected a visible window for $packageName within 20s",
            windowAppeared
        )

        val screenshotFile = File(ctx.cacheDir, "e2e_launch_screenshot.png")
        val saved = device.takeScreenshot(screenshotFile)
        assertTrue("Screenshot should be capturable", saved)
    }
}
