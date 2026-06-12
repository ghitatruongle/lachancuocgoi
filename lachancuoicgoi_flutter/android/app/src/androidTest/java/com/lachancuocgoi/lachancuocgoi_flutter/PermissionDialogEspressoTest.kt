package com.lachancuocgoi.lachancuocgoi_flutter

import android.Manifest
import android.content.Context
import android.content.pm.PackageManager
import androidx.test.core.app.ApplicationProvider
import androidx.test.espresso.intent.rule.IntentsTestRule
import androidx.test.ext.junit.runners.AndroidJUnit4
import androidx.test.filters.LargeTest
import org.junit.Assert.assertNotNull
import org.junit.Assert.assertTrue
import org.junit.Rule
import org.junit.Test
import org.junit.runner.RunWith

@RunWith(AndroidJUnit4::class)
@LargeTest
class PermissionDialogEspressoTest {

    @get:Rule
    val intentsRule = IntentsTestRule(MainActivity::class.java)

    @Test
    fun phone_and_calllog_permissions_are_declared_in_manifest() {
        val ctx = ApplicationProvider.getApplicationContext<Context>()
        val pm = ctx.packageManager
        val info = pm.getPackageInfo(
            ctx.packageName,
            PackageManager.GET_PERMISSIONS
        )
        val requested = info.requestedPermissions?.toList().orEmpty()
        assertTrue(
            "Manifest must declare READ_PHONE_STATE",
            requested.contains(Manifest.permission.READ_PHONE_STATE)
        )
        assertTrue(
            "Manifest must declare READ_CALL_LOG",
            requested.contains(Manifest.permission.READ_CALL_LOG)
        )
    }

    @Test
    fun overlay_permission_is_declared_in_manifest() {
        val ctx = ApplicationProvider.getApplicationContext<Context>()
        val pm = ctx.packageManager
        val info = pm.getPackageInfo(
            ctx.packageName,
            PackageManager.GET_PERMISSIONS
        )
        val requested = info.requestedPermissions?.toList().orEmpty()
        assertTrue(
            "Manifest must declare SYSTEM_ALERT_WINDOW",
            requested.contains(Manifest.permission.SYSTEM_ALERT_WINDOW)
        )
    }

    @Test
    fun record_audio_permission_is_declared_in_manifest() {
        val ctx = ApplicationProvider.getApplicationContext<Context>()
        val pm = ctx.packageManager
        val info = pm.getPackageInfo(
            ctx.packageName,
            PackageManager.GET_PERMISSIONS
        )
        val requested = info.requestedPermissions?.toList().orEmpty()
        assertTrue(
            "Manifest must declare RECORD_AUDIO",
            requested.contains(Manifest.permission.RECORD_AUDIO)
        )
    }

    /**
     * This is a placeholder. The original spec asked for a test that fires the
     * permission request via a debug-only intent extra on MainActivity. That
     * hook is intentionally NOT being added because the spec rule
     * "DO NOT TOUCH android/app/src/main/kotlin/..." takes precedence over
     * the optional 5-line hook suggested in the brief.
     *
     * When/if a debug hook is added (e.g. `if (BuildConfig.DEBUG &&
     * intent?.action == "TEST_REQUEST_PHONE_PERMISSIONS")` block in
     * MainActivity.onCreate), the actual system-dialog flow should be tested
     * by sending that intent with
     * `Intents.intending(hasAction("TEST_REQUEST_PHONE_PERMISSIONS"))` and
     * then verifying that `pendingPhonePermissionResult` resolves to a
     * Boolean. Until then, this test simply asserts the manifest declares
     * the permissions the flow would request.
     */
    @Test
    fun debug_hook_for_permission_dialog_is_not_yet_implemented() {
        val ctx = ApplicationProvider.getApplicationContext<Context>()
        val intent = android.content.Intent("TEST_REQUEST_PHONE_PERMISSIONS")
        intent.setPackage(ctx.packageName)
        val resolves = ctx.packageManager.resolveActivity(
            intent,
            PackageManager.MATCH_DEFAULT_ONLY
        )
        assertNotNull(
            "No TEST_REQUEST_PHONE_PERMISSIONS handler is wired up. " +
                "Add a BuildConfig.DEBUG hook to MainActivity to enable " +
                "end-to-end permission-dialog instrumentation tests.",
            resolves
        )
    }
}
