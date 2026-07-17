// ─── Data Models for the native call shield bridge ──────────────────────────
//
// Shared between [NativeBridgeInterface], [NativeCallShieldBridge], and all
// bridge implementations. Extracted so the models, interface, and Android
// implementation each live in a focused file.

/// Monitoring lifecycle states emitted by the native side.
enum MonitoringState {
  idle,
  started,
  stopped,
  networkAvailable,
  networkLost,

  /// Sprint 2 (C1): native STT switched to the Vosk offline fallback.
  /// The `transcript` slot of the parsed tuple carries the reason
  /// (e.g. "error12_loop" or "network_errors_3") which the UI can
  /// surface in its banner.
  sttFallbackVosk;

  /// Duration and final transcript when state is [stopped]. Reason string
  /// when state is [sttFallbackVosk]. Otherwise null.
  static (MonitoringState, int?, String?) parse(String raw) {
    if (raw.startsWith('STOPPED:')) {
      final parts = raw.split(':');
      final duration = parts.length > 1 ? int.tryParse(parts[1]) : null;
      // Extract transcript — normalize empty string to null for consistency
      final rawTranscript = parts.length > 2
          ? parts.sublist(2).join(':')
          : null;
      final transcript = (rawTranscript == null || rawTranscript.isEmpty)
          ? null
          : rawTranscript;
      return (MonitoringState.stopped, duration, transcript);
    }
    if (raw.startsWith('STT_FALLBACK:VOSK:')) {
      // The third field is the reason (e.g. "error12_loop",
      // "network_errors_3"). Empty string is normalised to null.
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

/// A telephony call event from the native side.
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

/// Snapshot of all call-shield permissions at a point in time.
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

/// Result of stopping a monitoring session.
class MonitoringStopResult {
  const MonitoringStopResult({this.durationSeconds, this.finalTranscript});
  final int? durationSeconds;
  final String? finalTranscript;
}

/// A single transcript event from the native side.
///
/// `text` is either the latest cumulative final transcript (when [isPartial]
/// is false) or the most recent partial / current-utterance text (when true).
/// Flutter typically replaces its display transcript with [text]; the [isPartial]
/// flag is informational and can be used to debounce analysis or to render a
/// "đang nghe…" hint.
class TranscriptUpdate {
  const TranscriptUpdate({required this.text, required this.isPartial});
  final String text;
  final bool isPartial;
}
