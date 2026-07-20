package com.lachancuocgoi.lachancuocgoi_flutter.helpers

import android.content.Context
import org.junit.Assert.assertEquals
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
        assertTrue(snapshot.containsKey("answerPhoneCalls"))
        assertTrue(snapshot.containsKey("overlay"))
        assertTrue(snapshot.containsKey("notification"))
        assertTrue(snapshot.containsKey("accessibility"))
        assertTrue(snapshot.containsKey("callScreening"))
    }

    @Test
    fun `snapshot returns exactly eight permission flags`() {
        val snapshot = PermissionHelpers.getPermissionSnapshot(context)

        assertEquals(8, snapshot.size)
    }

    @Test
    @Config(sdk = [32])
    fun `hasNotificationPermission returns true for pre-API-33`() {
        assertTrue(PermissionHelpers.hasNotificationPermission(context))
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
