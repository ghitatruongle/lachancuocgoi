import 'dart:async';

import 'package:flutter/services.dart';

import '../core/system_logger.dart';
import 'native_bridge_interface.dart';

/// Shared MethodChannel and EventChannel infrastructure for Android bridges.
///
/// Both [AndroidCallShieldBridge] and the legacy [NativeCallShieldBridge]
/// communicate with the same native channels. This abstract base class
/// eliminates ~400 lines of duplicated channel declarations, timeout wrappers,
/// and stream caching logic.
///
/// Concrete subclasses implement [NativeBridgeInterface] methods that need
/// platform-specific behavior (if any).
abstract class BaseMethodChannelBridge implements NativeBridgeInterface {
  // ─── Channel declarations ────────────────────────────────────────────────

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

  /// Default MethodChannel timeout.
  Duration get defaultTimeout;

  // ─── Timeout wrapper ─────────────────────────────────────────────────────

  Future<bool> invokeBool(
    String method, [
    Object? arguments,
    Duration? timeout,
  ]) async {
    final actualTimeout = timeout ?? defaultTimeout;
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

  Future<T?> invokeWithTimeout<T>(
    String method, [
    Object? arguments,
    Duration? timeout,
  ]) async {
    final actualTimeout = timeout ?? defaultTimeout;
    try {
      return await _methodChannel
          .invokeMethod<T>(method, arguments)
          .timeout(actualTimeout);
    } on TimeoutException {
      SystemLogger.instance.log(
        LogCategory.bridge,
        'NativeBridge.$method timed out after ${actualTimeout.inMilliseconds}ms',
        level: LogLevel.warning,
      );
      return null;
    } on PlatformException catch (e) {
      SystemLogger.instance.log(
        LogCategory.bridge,
        'NativeBridge.$method error: $e',
        level: LogLevel.error,
      );
      return null;
    }
  }

  // ─── EventChannel streams ────────────────────────────────────────────────

  late final Stream<TranscriptUpdate> cachedTranscriptStream =
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

  late final Stream<double> cachedRmsStream = _rmsChannel
      .receiveBroadcastStream()
      .map((event) {
        if (event is double) return event;
        if (event is num) return event.toDouble();
        return 0.0;
      })
      .asBroadcastStream();

  late final Stream<(MonitoringState, int?, String?)>
      cachedMonitoringStateStream = _monitoringStateChannel
          .receiveBroadcastStream()
          .map((event) => MonitoringState.parse(event?.toString() ?? ''))
          .asBroadcastStream();

  late final Stream<NativeCallEvent> cachedCallEventStream = _callEventChannel
      .receiveBroadcastStream()
      .map((event) {
        if (event is Map) return NativeCallEvent.fromMap(event);
        return const NativeCallEvent(type: 'UNKNOWN');
      })
      .asBroadcastStream();

  late final Stream<String> cachedLogsStream = _logsChannel
      .receiveBroadcastStream()
      .map((event) => event?.toString() ?? '')
      .asBroadcastStream();
}
