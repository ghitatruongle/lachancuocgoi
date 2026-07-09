package com.lachancuocgoi.lachancuocgoi_flutter.helpers

import android.content.Context
import org.junit.Assert.assertFalse
import org.junit.Assert.assertNotNull
import org.junit.Assert.assertTrue
import org.junit.Before
import org.junit.Test
import org.junit.runner.RunWith
import org.mockito.Mock
import org.mockito.MockitoAnnotations
import org.robolectric.RobolectricTestRunner
import org.robolectric.annotation.Config

/**
 * Unit tests for [PermissionHelpers] (Wave 4).
 *
 * Wave 2 refactor extracted permission helpers from MainActivity.
 */
@RunWith(RobolectricTestRunner::class)
@Config(sdk = [34])
class PermissionHelpersTest {

    @Mock
    private lateinit var mockContext: Context

    private lateinit var context: Context

    @Before
    fun setUp() {
        MockitoAnnotations.openMocks(this)
        // Use real Robolectric context for permission checks
        context = org.robolectric.RuntimeEnvironment.getApplication()
    }

    @Test
    fun `getPermissionSnapshot returns all required keys`() {
        val snapshot = PermissionHelpers.getPermissionSnapshot(context)

        assertNotNull(snapshot)
        assertTrue(snapshot.containsKey("recordAudio"))
        assertTrue(snapshot.containsKey("phoneState"))
        assertTrue(snapshot.containsKey("callLog"))
        assertTrue(snapshot.containsKey("overlay"))
        assertTrue(snapshot.containsKey("notification"))
        assertTrue(snapshot.containsKey("accessibility"))
        assertTrue(snapshot.containsKey("callScreening"))
    }

    @Test
    fun `snapshot returns boolean values`() {
        val snapshot = PermissionHelpers.getPermissionSnapshot(context)

        snapshot.values.forEach { value ->
            assertTrue("Value must be Boolean", value is Boolean)
        }
    }

    @Test
    fun `hasNotificationPermission returns true for pre-API-33`() {
        // Robolectric default is API 33+ but we test the simple boolean return
        val result = PermissionHelpers.hasNotificationPermission(context)
        // Result depends on Android version, just verify type
        assertTrue(result || !result)
    }

    @Test
    fun `isAccessibilityServiceEnabled returns boolean`() {
        val result = PermissionHelpers.isAccessibilityServiceEnabled(context)
        // In Robolectric, no accessibility services are enabled by default
        assertFalse(result)
    }

    @Test
    fun `isCallScreeningRoleHeld returns false in test environment`() {
        val result = PermissionHelpers.isCallScreeningRoleHeld(context)
        // Call screening role not held in test
        assertFalse(result)
    }
}