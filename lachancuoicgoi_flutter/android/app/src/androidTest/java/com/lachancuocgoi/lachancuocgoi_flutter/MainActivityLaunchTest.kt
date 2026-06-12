package com.lachancuocgoi.lachancuocgoi_flutter

import android.content.Context
import android.content.Intent
import android.view.View
import android.view.ViewGroup
import androidx.test.core.app.ApplicationProvider
import androidx.test.ext.junit.runners.AndroidJUnit4
import androidx.test.platform.app.InstrumentationRegistry
import org.junit.After
import org.junit.Assert.assertEquals
import org.junit.Assert.assertNotNull
import org.junit.Assert.assertTrue
import org.junit.Test
import org.junit.runner.RunWith

@RunWith(AndroidJUnit4::class)
class MainActivityLaunchTest {

    private var activity: MainActivity? = null

    @After
    fun tearDown() {
        activity?.finish()
        InstrumentationRegistry.getInstrumentation().waitForIdleSync()
        activity = null
    }

    @Test
    fun activity_launches() {
        val launched = launchActivity()
        assertNotNull(launched.findViewById(android.R.id.content))
    }

    @Test
    fun app_package_matches_manifest() {
        val ctx = ApplicationProvider.getApplicationContext<Context>()
        assertEquals("com.lachancuocgoi.lachancuocgoi_flutter", ctx.packageName)
    }

    @Test
    fun flutter_engine_attaches() {
        val launched = launchActivity()
        val content = launched.findViewById<ViewGroup>(android.R.id.content)
        assertTrue(
            "Expected FlutterView to attach under android.R.id.content",
            containsFlutterView(content)
        )
    }

    private fun launchActivity(): MainActivity {
        val instrumentation = InstrumentationRegistry.getInstrumentation()
        val ctx = ApplicationProvider.getApplicationContext<Context>()
        val intent = Intent(ctx, MainActivity::class.java).apply {
            addFlags(Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TASK)
        }
        val launched = instrumentation.startActivitySync(intent) as MainActivity
        instrumentation.waitForIdleSync()
        activity = launched
        return launched
    }

    private fun containsFlutterView(view: View): Boolean {
        if (view.javaClass.name.endsWith("FlutterView")) {
            return true
        }
        if (view is ViewGroup) {
            for (index in 0 until view.childCount) {
                if (containsFlutterView(view.getChildAt(index))) {
                    return true
                }
            }
        }
        return false
    }
}
