import 'dart:async';
import 'package:flutter/services.dart';
import '../core/system_logger.dart';
import 'native_bridge_interface.dart';

class AndroidCallShieldBridge
    implements NativeBridgeInterface, TypedMonitoringStartBridge {
  AndroidCallShieldBridge({Duration? defaultTimeout})
    : _defaultTimeout = defaultTimeout ?? const Duration(seconds: 5);

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

  // Bug #22 fix: timeout wrapper. If the MainActivity is busy (e.g. still
  // showing a permission dialog) and the platform-thread is blocked, the
  // MethodChannel.invokeMethod call could otherwise hang indefinitely and
  // freeze the Flutter UI. Default 5s is generous enough for any realistic
  // call (the slowest operation is startCreatorMonitoring which prompts
  // MediaProjection — that completes in <1s on a healthy device).
  //
  // Bug fix (review): `null as T` crashes when T is non-nullable (e.g.
  // `bool`). All callers use `Future<bool>`, so we MUST return `false`
  // on timeout/error instead of null. Changed to return a typed default.
  //
  // BUG-BASELINE-3 fix: inject timeout via constructor for testability.
  final Duration _defaultTimeout;

  Future<bool> _invokeWithTimeout(
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
        'NativeBridge.startMonitoring timed out after '
        '${_defaultTimeout.inMilliseconds}ms',
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
    return _invokeWithTimeout('stopMonitoring');
  }

  @override
  Future<bool> startCreatorMonitoring({required int devModeExpiresAtMs}) async {
    return _invokeWithTimeout('startCreatorMonitoring', {
      'devModeExpiresAtMs': devModeExpiresAtMs,
    });
  }

  @override
  Future<bool> stopCreatorMonitoring() async {
    return _invokeWithTimeout('stopCreatorMonitoring');
  }

  @override
  Future<bool> showRedAlert(String reason) async {
    return _invokeWithTimeout('showRedAlert', {'reason': reason});
  }

  @override
  Future<bool> showOrangeAlert(String reason) async {
    return _invokeWithTimeout('showOrangeAlert', {'reason': reason});
  }

  @override
  Future<bool> dismissAlert() async {
    return _invokeWithTimeout('dismissAlert');
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
    try {
      final result = await _methodChannel.invokeMethod<bool>(
        'openAccessibilitySettings',
      );
      return result ?? false;
    } on PlatformException catch (e) {
      SystemLogger.instance.log(
        LogCategory.bridge,
        'NativeBridge.openAccessibilitySettings error: $e',
        level: LogLevel.error,
      );
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
      SystemLogger.instance.log(
        LogCategory.bridge,
        'NativeBridge.requestCallScreeningRole error: $e',
        level: LogLevel.error,
      );
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
      SystemLogger.instance.log(
        LogCategory.bridge,
        'NativeBridge.requestPhoneAndCallLogPermissions error: $e',
        level: LogLevel.error,
      );
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
      SystemLogger.instance.log(
        LogCategory.bridge,
        'NativeBridge.checkOverlayPermission error: $e',
        level: LogLevel.error,
      );
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
      SystemLogger.instance.log(
        LogCategory.bridge,
        'NativeBridge.requestOverlayPermission error: $e',
        level: LogLevel.error,
      );
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
      SystemLogger.instance.log(
        LogCategory.bridge,
        'NativeBridge.isMonitoringActive error: $e',
        level: LogLevel.error,
      );
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
      SystemLogger.instance.log(
        LogCategory.bridge,
        'NativeBridge.isCreatorMonitoringActive error: $e',
        level: LogLevel.error,
      );
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
      SystemLogger.instance.log(
        LogCategory.bridge,
        'NativeBridge.showIncomingCallOverlay error: $e',
        level: LogLevel.error,
      );
    }
  }

  @override
  Future<void> dismissIncomingCallOverlay() async {
    try {
      await _methodChannel.invokeMethod<void>('dismissIncomingCallOverlay');
    } on PlatformException catch (e) {
      SystemLogger.instance.log(
        LogCategory.bridge,
        'NativeBridge.dismissIncomingCallOverlay error: $e',
        level: LogLevel.error,
      );
    }
  }

  // Phase 2 (P2-4): Call screening opt-in bridge methods.
  @override
  Future<void> setCallScreeningBlockEnabled(bool enabled) async {
    try {
      await _methodChannel.invokeMethod<void>('setCallScreeningBlockEnabled', {
        'enabled': enabled,
      });
    } on PlatformException catch (e) {
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
      await _methodChannel.invokeMethod<void>('setBlockedNumbers', {
        'numbers': numbers,
      });
    } on PlatformException catch (e) {
      SystemLogger.instance.log(
        LogCategory.bridge,
        'NativeBridge.setBlockedNumbers error: $e',
        level: LogLevel.error,
      );
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
