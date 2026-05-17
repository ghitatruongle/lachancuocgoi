import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

// ─── Data Models ──────────────────────────────────────────────────────────────

enum MonitoringState {
  idle,
  started,
  stopped,
  networkAvailable,
  networkLost;

  /// Duration and final transcript when state is [stopped].
  static (MonitoringState, int?, String?) parse(String raw) {
    if (raw.startsWith('STOPPED:')) {
      final parts = raw.split(':');
      final duration = parts.length > 1 ? int.tryParse(parts[1]) : null;
      final transcript = parts.length > 2 ? parts.sublist(2).join(':') : null;
      return (MonitoringState.stopped, duration, transcript);
    }
    return switch (raw) {
      'STARTED' => (MonitoringState.started, null, null),
      'NETWORK_AVAILABLE' => (MonitoringState.networkAvailable, null, null),
      'NETWORK_LOST' => (MonitoringState.networkLost, null, null),
      _ => (MonitoringState.idle, null, null),
    };
  }
}

class CallEvent {
  const CallEvent({required this.type, this.phoneNumber, this.source});

  final String type; // RINGING, OFFHOOK, IDLE, INCOMING, ENDED, SCREENING
  final String? phoneNumber;
  final String? source;

  factory CallEvent.fromMap(Map<Object?, Object?> map) {
    return CallEvent(
      type: map['type'] as String? ?? 'UNKNOWN',
      phoneNumber: map['phoneNumber'] as String?,
      source: map['source'] as String?,
    );
  }
}

class PermissionSnapshot {
  const PermissionSnapshot({
    this.recordAudio = false,
    this.phoneState = false,
    this.callLog = false,
    this.overlay = false,
    this.notification = false,
    this.accessibility = false,
    this.callScreening = false,
  });

  final bool recordAudio;
  final bool phoneState;
  final bool callLog;
  final bool overlay;
  final bool notification;
  final bool accessibility;
  final bool callScreening;

  factory PermissionSnapshot.fromMap(Map<Object?, Object?> map) {
    return PermissionSnapshot(
      recordAudio: map['recordAudio'] as bool? ?? false,
      phoneState: map['phoneState'] as bool? ?? false,
      callLog: map['callLog'] as bool? ?? false,
      overlay: map['overlay'] as bool? ?? false,
      notification: map['notification'] as bool? ?? false,
      accessibility: map['accessibility'] as bool? ?? false,
      callScreening: map['callScreening'] as bool? ?? false,
    );
  }

  bool get allGranted =>
      recordAudio &&
      phoneState &&
      callLog &&
      overlay &&
      notification &&
      accessibility &&
      callScreening;

  int get grantedCount => [
    recordAudio,
    phoneState,
    callLog,
    overlay,
    notification,
    accessibility,
    callScreening,
  ].where((p) => p).length;

  static const int totalPermissions = 7;
}

// ─── Monitoring Stop Result ───────────────────────────────────────────────────

class MonitoringStopResult {
  const MonitoringStopResult({this.durationSeconds, this.finalTranscript});
  final int? durationSeconds;
  final String? finalTranscript;
}

// ─── Bridge ───────────────────────────────────────────────────────────────────

class NativeCallShieldBridge {
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

  // ─── MethodChannel calls ────────────────────────────────────────────────

  /// Start monitoring service on Android.
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

  /// Stop monitoring service.
  Future<bool> stopMonitoring() async {
    try {
      final result = await _methodChannel.invokeMethod<bool>('stopMonitoring');
      return result ?? false;
    } on PlatformException catch (e) {
      debugPrint('NativeBridge.stopMonitoring error: $e');
      return false;
    }
  }

  /// Start creator monitoring via MediaProjection on Android.
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

  /// Stop creator monitoring service.
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

  /// Show RED alert overlay on Android.
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

  /// Show ORANGE alert overlay on Android.
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

  /// Dismiss any visible alert overlay.
  Future<bool> dismissAlert() async {
    try {
      final result = await _methodChannel.invokeMethod<bool>('dismissAlert');
      return result ?? false;
    } on PlatformException catch (e) {
      debugPrint('NativeBridge.dismissAlert error: $e');
      return false;
    }
  }

  /// Get current permission status snapshot.
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

  /// Open Android Accessibility Settings.
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

  /// Request Call Screening role (Android Q+).
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

  /// Request READ_PHONE_STATE + READ_CALL_LOG on Android.
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

  /// Check if overlay permission is granted.
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

  /// Request overlay permission.
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

  /// Check if accessibility service is enabled.
  Future<bool> isAccessibilityEnabled() async {
    try {
      final result = await _methodChannel.invokeMethod<bool>(
        'isAccessibilityEnabled',
      );
      return result ?? false;
    } on PlatformException catch (e) {
      debugPrint('NativeBridge.isAccessibilityEnabled error: $e');
      return false;
    }
  }

  /// Check if monitoring service is currently running.
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

  /// Check if creator monitoring service is currently running.
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

  // ─── EventChannel streams ──────────────────────────────────────────────

  /// Stream of transcript text from native STT.
  Stream<String> get transcriptStream => _transcriptChannel
      .receiveBroadcastStream()
      .map((event) {
        return event?.toString() ?? '';
      })
      .where((text) => text.isNotEmpty);

  /// Stream of RMS (volume) values from native STT for waveform display.
  Stream<double> get rmsStream =>
      _rmsChannel.receiveBroadcastStream().map((event) {
        if (event is double) return event;
        if (event is num) return event.toDouble();
        return 0.0;
      });

  /// Stream of monitoring state changes.
  Stream<(MonitoringState, int?, String?)> get monitoringStateStream =>
      _monitoringStateChannel.receiveBroadcastStream().map((event) {
        return MonitoringState.parse(event?.toString() ?? '');
      });

  /// Stream of call events (incoming, ended, screening, etc.)
  Stream<CallEvent> get callEventStream =>
      _callEventChannel.receiveBroadcastStream().map((event) {
        if (event is Map) {
          return CallEvent.fromMap(event);
        }
        return const CallEvent(type: 'UNKNOWN');
      });
}

// ─── Riverpod Provider ────────────────────────────────────────────────────────

final nativeBridgeProvider = Provider<NativeCallShieldBridge>((ref) {
  return NativeCallShieldBridge.instance;
});
