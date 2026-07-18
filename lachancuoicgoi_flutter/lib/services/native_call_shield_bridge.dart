import 'dart:async';
import 'package:flutter/foundation.dart' show visibleForTesting;
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/system_logger.dart';
import 'native_bridge_interface.dart';

// Re-export the interface + models so existing imports of this file keep
// working. Consumers that only need types should import native_bridge_interface
// directly; this export is for backward compatibility.
export 'native_bridge_interface.dart';

// ─── Legacy Android bridge (P2-8) ───────────────────────────────────────────
//
// Phase 2 (P2-8): This class is kept for backward compatibility with existing
// tests that reference [NativeCallShieldBridge.instance] directly. Production
// code now uses [NativeBridgeInterface.create()] which selects
// [AndroidCallShieldBridge] or [SimulatorCallShieldBridge] per platform.
//
// All iOS/desktop simulation code has been removed — the single source of
// truth for simulation is [SimulatorCallShieldBridge]. This class is now a
// clean Android-only MethodChannel bridge (functionally equivalent to
// [AndroidCallShieldBridge]).

class NativeCallShieldBridge
    implements NativeBridgeInterface, TypedMonitoringStartBridge {
  NativeCallShieldBridge._();

  static final NativeCallShieldBridge instance = NativeCallShieldBridge._();

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
  static const _logsChannel = EventChannel('com.lachancuocgoi/logs');

  /// Default MethodChannel timeout (same posture as [AndroidCallShieldBridge]).
  static const Duration _defaultTimeout = Duration(seconds: 5);

  Future<bool> _invokeBool(
    String method, [
    Object? arguments,
    Duration? timeout,
  ]) async {
    final actualTimeout = timeout ?? _defaultTimeout;
    try {
      final result = await _methodChannel
          .invokeMethod<bool>(method, arguments)
          .timeout(
            actualTimeout,
            onTimeout: () {
              SystemLogger.instance.log(
                LogCategory.bridge,
                'NativeBridge.$method timed out after ${actualTimeout.inMilliseconds}ms',
                level: LogLevel.warning,
              );
              return false;
            },
          );
      return result ?? false;
    } on PlatformException catch (e) {
      SystemLogger.instance.log(
        LogCategory.bridge,
        'NativeBridge.$method error: $e',
        level: LogLevel.error,
      );
      return false;
    }
  }

  /// Tears down any cached resources. Kept for test compatibility.
  @visibleForTesting
  void dispose() {}

  // ─── MethodChannel calls (Android-only) ─────────────────────────────────

  @override
  Future<bool> startMonitoring({
    String? phoneNumber,
    bool enableSpeakerphone = false,
  }) async {
    final result = await startMonitoringTyped(
      phoneNumber: phoneNumber,
      enableSpeakerphone: enableSpeakerphone,
    );
    return result.isSuccess;
  }

  @override
  Future<MonitoringStartResult> startMonitoringTyped({
    String? phoneNumber,
    bool enableSpeakerphone = false,
  }) async {
    try {
      final raw = await _methodChannel
          .invokeMethod<Object?>('startMonitoring', {
            'phoneNumber': phoneNumber,
            'enableSpeakerphone': enableSpeakerphone,
          })
          .timeout(_defaultTimeout);
      return MonitoringStartResult.fromNative(raw);
    } on TimeoutException {
      SystemLogger.instance.log(
        LogCategory.bridge,
        'NativeBridge.startMonitoring timed out',
        level: LogLevel.warning,
      );
      return const MonitoringStartResult(
        MonitoringStartStatus.nativeFailure,
        message: 'Dịch vụ giám sát phản hồi quá chậm.',
      );
    } on PlatformException catch (e) {
      SystemLogger.instance.log(
        LogCategory.bridge,
        'NativeBridge.startMonitoring error: $e',
        level: LogLevel.error,
      );
      return MonitoringStartResult(
        MonitoringStartStatus.nativeFailure,
        message: e.message ?? 'Dịch vụ giám sát không thể khởi động.',
      );
    }
  }

  @override
  Future<bool> stopMonitoring() async {
    return _invokeBool('stopMonitoring');
  }

  @override
  Future<bool> startCreatorMonitoring({required int devModeExpiresAtMs}) async {
    return _invokeBool('startCreatorMonitoring', {
      'devModeExpiresAtMs': devModeExpiresAtMs,
    });
  }

  @override
  Future<bool> stopCreatorMonitoring() async {
    return _invokeBool('stopCreatorMonitoring');
  }

  @override
  Future<bool> showRedAlert(String reason) async {
    return _invokeBool('showRedAlert', {'reason': reason});
  }

  @override
  Future<bool> showOrangeAlert(String reason) async {
    return _invokeBool('showOrangeAlert', {'reason': reason});
  }

  @override
  Future<bool> dismissAlert() async {
    return _invokeBool('dismissAlert');
  }

  @override
  Future<PermissionSnapshot> getPermissionSnapshot() async {
    try {
      final result = await _methodChannel
          .invokeMethod<Map>('getPermissionSnapshot')
          .timeout(
            _defaultTimeout,
            onTimeout: () {
              SystemLogger.instance.log(
                LogCategory.bridge,
                'NativeBridge.getPermissionSnapshot timed out',
                level: LogLevel.warning,
              );
              return null;
            },
          );
      if (result != null) {
        return PermissionSnapshot.fromMap(result);
      }
    } on PlatformException catch (e) {
      SystemLogger.instance.log(
        LogCategory.bridge,
        'NativeBridge.getPermissionSnapshot error: $e',
        level: LogLevel.error,
      );
    }
    return const PermissionSnapshot();
  }

  @override
  Future<bool> openAccessibilitySettings() async {
    return _invokeBool('openAccessibilitySettings');
  }

  @override
  Future<bool> requestCallScreeningRole() async {
    return _invokeBool('requestCallScreeningRole');
  }

  @override
  Future<bool> requestPhoneAndCallLogPermissions() async {
    return _invokeBool('requestPhoneAndCallLogPermissions');
  }

  @override
  Future<bool> checkOverlayPermission() async {
    return _invokeBool('checkOverlayPermission');
  }

  @override
  Future<bool> requestOverlayPermission() async {
    return _invokeBool('requestOverlayPermission');
  }

  /// Extra method not on [NativeBridgeInterface] — kept for test
  /// compatibility.
  Future<bool> isAccessibilityEnabled() async {
    return _invokeBool('isAccessibilityEnabled');
  }

  @override
  Future<bool> isMonitoringActive() async {
    return _invokeBool('isMonitoringActive');
  }

  @override
  Future<bool> isCreatorMonitoringActive() async {
    return _invokeBool('isCreatorMonitoringActive');
  }

  @override
  Future<void> showIncomingCallOverlay(String callerInfo) async {
    try {
      await _methodChannel
          .invokeMethod<void>('showIncomingCallOverlay', {
            'callerInfo': callerInfo,
          })
          .timeout(_defaultTimeout);
    } on PlatformException catch (e) {
      SystemLogger.instance.log(
        LogCategory.bridge,
        'NativeBridge.showIncomingCallOverlay error: $e',
        level: LogLevel.error,
      );
    } on TimeoutException {
      SystemLogger.instance.log(
        LogCategory.bridge,
        'NativeBridge.showIncomingCallOverlay timed out',
        level: LogLevel.warning,
      );
    }
  }

  @override
  Future<void> dismissIncomingCallOverlay() async {
    try {
      await _methodChannel
          .invokeMethod<void>('dismissIncomingCallOverlay')
          .timeout(_defaultTimeout);
    } on PlatformException catch (e) {
      SystemLogger.instance.log(
        LogCategory.bridge,
        'NativeBridge.dismissIncomingCallOverlay error: $e',
        level: LogLevel.error,
      );
    } on TimeoutException {
      SystemLogger.instance.log(
        LogCategory.bridge,
        'NativeBridge.dismissIncomingCallOverlay timed out',
        level: LogLevel.warning,
      );
    }
  }

  // Phase 2 (P2-4): Call screening opt-in bridge methods.
  @override
  Future<void> setCallScreeningBlockEnabled(bool enabled) async {
    try {
      await _methodChannel
          .invokeMethod<void>('setCallScreeningBlockEnabled', {
            'enabled': enabled,
          })
          .timeout(_defaultTimeout);
    } on Exception catch (e) {
      SystemLogger.instance.log(
        LogCategory.bridge,
        'NativeBridge.setCallScreeningBlockEnabled error: $e',
        level: LogLevel.error,
      );
    }
  }

  @override
  Future<void> setBlockedNumbers(List<String> numbers) async {
    try {
      await _methodChannel
          .invokeMethod<void>('setBlockedNumbers', {'numbers': numbers})
          .timeout(_defaultTimeout);
    } on Exception catch (e) {
      SystemLogger.instance.log(
        LogCategory.bridge,
        'NativeBridge.setBlockedNumbers error: $e',
        level: LogLevel.error,
      );
    }
  }

  // ─── EventChannel streams (cached to prevent memory leaks) ─────────────

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

  late final Stream<NativeCallEvent> _cachedCallEventStream = _callEventChannel
      .receiveBroadcastStream()
      .map((event) {
        if (event is Map) return NativeCallEvent.fromMap(event);
        return const NativeCallEvent(type: 'UNKNOWN');
      })
      .asBroadcastStream();

  late final Stream<String> _cachedLogsStream = _logsChannel
      .receiveBroadcastStream()
      .map((event) => event?.toString() ?? '')
      .asBroadcastStream();

  @override
  Stream<TranscriptUpdate> get transcriptStream => _cachedTranscriptStream;

  @override
  Stream<double> get rmsStream => _cachedRmsStream;

  @override
  Stream<(MonitoringState, int?, String?)> get monitoringStateStream =>
      _cachedMonitoringStateStream;

  @override
  Stream<NativeCallEvent> get callEventStream => _cachedCallEventStream;

  @override
  Stream<String> get logsStream => _cachedLogsStream;
}

// ─── Riverpod Provider ────────────────────────────────────────────────────────
//
// Phase 2 (P2-8): the provider now delegates to [NativeBridgeInterface.create()]
// which selects [AndroidCallShieldBridge] or [SimulatorCallShieldBridge]
// depending on the platform. [NativeCallShieldBridge] is kept for backward
// compatibility with existing tests that reference [NativeCallShieldBridge.instance]
// but is no longer the production bridge.

final nativeBridgeProvider = Provider<NativeBridgeInterface>((ref) {
  return NativeBridgeInterface.create();
});
