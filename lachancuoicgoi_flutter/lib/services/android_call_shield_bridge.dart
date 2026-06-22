import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'native_bridge_interface.dart';

class AndroidCallShieldBridge implements NativeBridgeInterface {
  AndroidCallShieldBridge();

  static const _methodChannel = MethodChannel(
    'com.lachancuocgoi/native_bridge',
  );
  static const _transcriptChannel = EventChannel(
    'com.lachancuocgoi/transcript_stream',
  );
  static const _rmsChannel = EventChannel('com.lachancuocgoi/rms_stream');
  static const _monitoringStateChannel = EventChannel(
    'com.lachancuocgoi/monitoring_state',
  );
  static const _callEventChannel = EventChannel(
    'com.lachancuocgoi/call_events',
  );

  @override
  Future<bool> startMonitoring({
    String? phoneNumber,
    bool enableSpeakerphone = false,
  }) async {
    try {
      final result = await _methodChannel.invokeMethod<bool>(
        'startMonitoring',
        {'phoneNumber': phoneNumber, 'enableSpeakerphone': enableSpeakerphone},
      );
      return result ?? false;
    } on PlatformException catch (e) {
      debugPrint('NativeBridge.startMonitoring error: $e');
      return false;
    }
  }

  @override
  Future<bool> stopMonitoring() async {
    try {
      final result = await _methodChannel.invokeMethod<bool>('stopMonitoring');
      return result ?? false;
    } on PlatformException catch (e) {
      debugPrint('NativeBridge.stopMonitoring error: $e');
      return false;
    }
  }

  @override
  Future<bool> startCreatorMonitoring({required int devModeExpiresAtMs}) async {
    try {
      final result = await _methodChannel.invokeMethod<bool>(
        'startCreatorMonitoring',
        {'devModeExpiresAtMs': devModeExpiresAtMs},
      );
      return result ?? false;
    } on PlatformException catch (e) {
      debugPrint('NativeBridge.startCreatorMonitoring error: $e');
      return false;
    }
  }

  @override
  Future<bool> stopCreatorMonitoring() async {
    try {
      final result = await _methodChannel.invokeMethod<bool>(
        'stopCreatorMonitoring',
      );
      return result ?? false;
    } on PlatformException catch (e) {
      debugPrint('NativeBridge.stopCreatorMonitoring error: $e');
      return false;
    }
  }

  @override
  Future<bool> showRedAlert(String reason) async {
    try {
      final result = await _methodChannel.invokeMethod<bool>('showRedAlert', {
        'reason': reason,
      });
      return result ?? false;
    } on PlatformException catch (e) {
      debugPrint('NativeBridge.showRedAlert error: $e');
      return false;
    }
  }

  @override
  Future<bool> showOrangeAlert(String reason) async {
    try {
      final result = await _methodChannel.invokeMethod<bool>(
        'showOrangeAlert',
        {'reason': reason},
      );
      return result ?? false;
    } on PlatformException catch (e) {
      debugPrint('NativeBridge.showOrangeAlert error: $e');
      return false;
    }
  }

  @override
  Future<bool> dismissAlert() async {
    try {
      final result = await _methodChannel.invokeMethod<bool>('dismissAlert');
      return result ?? false;
    } on PlatformException catch (e) {
      debugPrint('NativeBridge.dismissAlert error: $e');
      return false;
    }
  }

  @override
  Future<PermissionSnapshot> getPermissionSnapshot() async {
    try {
      final result = await _methodChannel.invokeMethod<Map>(
        'getPermissionSnapshot',
      );
      if (result != null) {
        return PermissionSnapshot.fromMap(result);
      }
    } on PlatformException catch (e) {
      debugPrint('NativeBridge.getPermissionSnapshot error: $e');
    }
    return const PermissionSnapshot();
  }

  @override
  Future<bool> openAccessibilitySettings() async {
    try {
      final result = await _methodChannel.invokeMethod<bool>(
        'openAccessibilitySettings',
      );
      return result ?? false;
    } on PlatformException catch (e) {
      debugPrint('NativeBridge.openAccessibilitySettings error: $e');
      return false;
    }
  }

  @override
  Future<bool> requestCallScreeningRole() async {
    try {
      final result = await _methodChannel.invokeMethod<bool>(
        'requestCallScreeningRole',
      );
      return result ?? false;
    } on PlatformException catch (e) {
      debugPrint('NativeBridge.requestCallScreeningRole error: $e');
      return false;
    }
  }

  @override
  Future<bool> requestPhoneAndCallLogPermissions() async {
    try {
      final result = await _methodChannel.invokeMethod<bool>(
        'requestPhoneAndCallLogPermissions',
      );
      return result ?? false;
    } on PlatformException catch (e) {
      debugPrint('NativeBridge.requestPhoneAndCallLogPermissions error: $e');
      return false;
    }
  }

  @override
  Future<bool> checkOverlayPermission() async {
    try {
      final result = await _methodChannel.invokeMethod<bool>(
        'checkOverlayPermission',
      );
      return result ?? false;
    } on PlatformException catch (e) {
      debugPrint('NativeBridge.checkOverlayPermission error: $e');
      return false;
    }
  }

  @override
  Future<bool> requestOverlayPermission() async {
    try {
      final result = await _methodChannel.invokeMethod<bool>(
        'requestOverlayPermission',
      );
      return result ?? false;
    } on PlatformException catch (e) {
      debugPrint('NativeBridge.requestOverlayPermission error: $e');
      return false;
    }
  }

  @override
  Future<bool> isMonitoringActive() async {
    try {
      final result = await _methodChannel.invokeMethod<bool>(
        'isMonitoringActive',
      );
      return result ?? false;
    } on PlatformException catch (e) {
      debugPrint('NativeBridge.isMonitoringActive error: $e');
      return false;
    }
  }

  @override
  Future<bool> isCreatorMonitoringActive() async {
    try {
      final result = await _methodChannel.invokeMethod<bool>(
        'isCreatorMonitoringActive',
      );
      return result ?? false;
    } on PlatformException catch (e) {
      debugPrint('NativeBridge.isCreatorMonitoringActive error: $e');
      return false;
    }
  }

  @override
  Future<void> showIncomingCallOverlay(String callerInfo) async {
    try {
      await _methodChannel.invokeMethod<void>('showIncomingCallOverlay', {
        'callerInfo': callerInfo,
      });
    } on PlatformException catch (e) {
      debugPrint('NativeBridge.showIncomingCallOverlay error: $e');
    }
  }

  @override
  Future<void> dismissIncomingCallOverlay() async {
    try {
      await _methodChannel.invokeMethod<void>('dismissIncomingCallOverlay');
    } on PlatformException catch (e) {
      debugPrint('NativeBridge.dismissIncomingCallOverlay error: $e');
    }
  }

  late final Stream<TranscriptUpdate> _cachedTranscriptStream =
      _transcriptChannel
          .receiveBroadcastStream()
          .map<TranscriptUpdate>((event) {
            if (event is Map) {
              return TranscriptUpdate(
                text: event['text']?.toString() ?? '',
                isPartial: event['isPartial'] == true,
              );
            }
            return TranscriptUpdate(
              text: event?.toString() ?? '',
              isPartial: false,
            );
          })
          .where((u) => u.text.isNotEmpty)
          .asBroadcastStream();

  late final Stream<double> _cachedRmsStream = _rmsChannel
      .receiveBroadcastStream()
      .map((event) {
        if (event is double) return event;
        if (event is num) return event.toDouble();
        return 0.0;
      })
      .asBroadcastStream();

  late final Stream<(MonitoringState, int?, String?)>
  _cachedMonitoringStateStream = _monitoringStateChannel
      .receiveBroadcastStream()
      .map((event) => MonitoringState.parse(event?.toString() ?? ''))
      .asBroadcastStream();

  late final Stream<CallEvent> _cachedCallEventStream = _callEventChannel
      .receiveBroadcastStream()
      .map((event) {
        if (event is Map) return CallEvent.fromMap(event);
        return const CallEvent(type: 'UNKNOWN');
      })
      .asBroadcastStream();

  @override
  Stream<TranscriptUpdate> get transcriptStream => _cachedTranscriptStream;

  @override
  Stream<double> get rmsStream => _cachedRmsStream;

  @override
  Stream<(MonitoringState, int?, String?)> get monitoringStateStream =>
      _cachedMonitoringStateStream;

  @override
  Stream<CallEvent> get callEventStream => _cachedCallEventStream;
}
