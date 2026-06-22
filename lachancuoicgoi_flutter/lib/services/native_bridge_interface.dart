import 'dart:async';

// ─── Data Models ──────────────────────────────────────────────────────────────

enum MonitoringState {
  idle,
  started,
  stopped,
  networkAvailable,
  networkLost,

  /// Sprint 2 (C1): native STT switched to the Vosk offline fallback.
  sttFallbackVosk;

  static (MonitoringState, int?, String?) parse(String raw) {
    if (raw.startsWith('STOPPED:')) {
      final parts = raw.split(':');
      final duration = parts.length > 1 ? int.tryParse(parts[1]) : null;
      final rawTranscript = parts.length > 2
          ? parts.sublist(2).join(':')
          : null;
      final transcript = (rawTranscript == null || rawTranscript.isEmpty)
          ? null
          : rawTranscript;
      return (MonitoringState.stopped, duration, transcript);
    }
    if (raw.startsWith('STT_FALLBACK:VOSK:')) {
      const prefix = 'STT_FALLBACK:VOSK:';
      final reason = raw.length > prefix.length
          ? raw.substring(prefix.length)
          : null;
      return (MonitoringState.sttFallbackVosk, null, reason);
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

  final String type;
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

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is PermissionSnapshot &&
          recordAudio == other.recordAudio &&
          phoneState == other.phoneState &&
          callLog == other.callLog &&
          overlay == other.overlay &&
          notification == other.notification &&
          accessibility == other.accessibility &&
          callScreening == other.callScreening;

  @override
  int get hashCode => Object.hash(
    recordAudio,
    phoneState,
    callLog,
    overlay,
    notification,
    accessibility,
    callScreening,
  );
}

class MonitoringStopResult {
  const MonitoringStopResult({this.durationSeconds, this.finalTranscript});
  final int? durationSeconds;
  final String? finalTranscript;
}

class TranscriptUpdate {
  const TranscriptUpdate({required this.text, required this.isPartial});
  final String text;
  final bool isPartial;
}

abstract class NativeBridgeInterface {
  Future<bool> startMonitoring({
    String? phoneNumber,
    bool enableSpeakerphone = false,
  });
  Future<bool> stopMonitoring();
  Future<bool> startCreatorMonitoring({required int devModeExpiresAtMs});
  Future<bool> stopCreatorMonitoring();
  Future<bool> showRedAlert(String reason);
  Future<bool> showOrangeAlert(String reason);
  Future<bool> dismissAlert();
  Future<PermissionSnapshot> getPermissionSnapshot();
  Future<bool> openAccessibilitySettings();
  Future<bool> requestCallScreeningRole();
  Future<bool> requestPhoneAndCallLogPermissions();
  Future<bool> checkOverlayPermission();
  Future<bool> requestOverlayPermission();
  Future<bool> isMonitoringActive();
  Future<bool> isCreatorMonitoringActive();
  Future<void> showIncomingCallOverlay(String callerInfo);
  Future<void> dismissIncomingCallOverlay();

  Stream<TranscriptUpdate> get transcriptStream;
  Stream<double> get rmsStream;
  Stream<(MonitoringState, int?, String?)> get monitoringStateStream;
  Stream<CallEvent> get callEventStream;
}
