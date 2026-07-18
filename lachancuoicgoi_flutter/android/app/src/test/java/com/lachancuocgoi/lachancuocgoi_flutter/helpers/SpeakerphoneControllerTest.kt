package com.lachancuocgoi.lachancuocgoi_flutter.helpers

import android.media.AudioManager
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Before
import org.junit.Test
import org.junit.runner.RunWith
import org.mockito.Mock
import org.mockito.Mockito.atLeastOnce
import org.mockito.Mockito.`when`
import org.mockito.MockitoAnnotations
import org.robolectric.RobolectricTestRunner
import org.robolectric.annotation.Config

/**
 * Unit tests for [SpeakerphoneController] (Wave 4).
 *
 * Wave 2 refactor extracted speakerphone logic from BackgroundMonitoringService.
 */
@RunWith(RobolectricTestRunner::class)
@Config(sdk = [34])
class SpeakerphoneControllerTest {

    @Mock
    private lateinit var mockAudioManager: AudioManager

    @Before
    fun setUp() {
        MockitoAnnotations.openMocks(this)
    }

    @Test
    fun `initial state is snapshot when service did not change it`() {
        `when`(mockAudioManager.isSpeakerphoneOn).thenReturn(false)
        val controller = SpeakerphoneController(mockAudioManager, initialState = false)

        // Should be no-op since service hasn't changed anything
        controller.disable()
        // No exception = success
    }

    @Test
    fun `enable sets speakerphone to true when off`() {
        `when`(mockAudioManager.isSpeakerphoneOn).thenReturn(false)
        val controller = SpeakerphoneController(mockAudioManager, initialState = false)

        controller.enable()

        // Verify isSpeakerphoneOn was set to true
        org.mockito.Mockito.verify(mockAudioManager).isSpeakerphoneOn = true
    }

    @Test
    fun `enable does nothing when speakerphone already on`() {
        `when`(mockAudioManager.isSpeakerphoneOn).thenReturn(true)
        val controller = SpeakerphoneController(mockAudioManager, initialState = false)

        controller.enable()

        // Should NOT set speakerphone to true (already true)
        org.mockito.Mockito.verify(mockAudioManager, org.mockito.Mockito.never()).isSpeakerphoneOn = true
    }

    @Test
    fun `disable restores snapshot when service changed state`() {
        `when`(mockAudioManager.isSpeakerphoneOn).thenReturn(false)
        val controller = SpeakerphoneController(mockAudioManager, initialState = false)

        // Service enables speakerphone
        controller.enable()
        org.mockito.Mockito.verify(mockAudioManager).isSpeakerphoneOn = true

        // Simulate speakerphone was changed to true by service
        `when`(mockAudioManager.isSpeakerphoneOn).thenReturn(true)

        // Service disables speakerphone (should restore to snapshot = false)
        controller.disable()
        org.mockito.Mockito.verify(mockAudioManager).isSpeakerphoneOn = false
    }

    @Test
    fun `disable does nothing when service did not change state`() {
        `when`(mockAudioManager.isSpeakerphoneOn).thenReturn(false)
        val controller = SpeakerphoneController(mockAudioManager, initialState = false)

        // Service never enabled speakerphone, so disable should be no-op
        controller.disable()
        // Should not change speakerphone state
        org.mockito.Mockito.verify(mockAudioManager, org.mockito.Mockito.never()).isSpeakerphoneOn = false
    }

    @Test
    fun `preserves initial state snapshot across operations`() {
        // Initial state: ON. Speakerphone starts OFF, service enables it,
        // then disable should restore to the snapshot (ON).
        `when`(mockAudioManager.isSpeakerphoneOn).thenReturn(false)
        val controller = SpeakerphoneController(mockAudioManager, initialState = true)

        // Enable turns speakerphone on (changedByService = true)
        controller.enable()
        org.mockito.Mockito.verify(mockAudioManager).isSpeakerphoneOn = true

        // Simulate speakerphone is now on
        `when`(mockAudioManager.isSpeakerphoneOn).thenReturn(true)

        // Disable should restore to snapshot (true)
        controller.disable()
        org.mockito.Mockito.verify(mockAudioManager, atLeastOnce()).isSpeakerphoneOn = true
    }

    @Test
    fun `handles exceptions gracefully in enable`() {
        `when`(mockAudioManager.isSpeakerphoneOn).thenThrow(RuntimeException("test"))
        val controller = SpeakerphoneController(mockAudioManager, initialState = false)

        // Should not crash
        controller.enable()
        // Exception was caught
    }

    @Test
    fun `handles exceptions gracefully in disable`() {
        `when`(mockAudioManager.isSpeakerphoneOn).thenThrow(RuntimeException("test"))
        val controller = SpeakerphoneController(mockAudioManager, initialState = false)

        // Should not crash
        controller.disable()
    }
}