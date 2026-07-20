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
  sttFallbackVosk,

  /// Both Google and Vosk STT failed to start — monitoring is blind.
  sttUnavailable,

  /// Android 13+: missing POST_NOTIFICATIONS — FGS runs degraded.
  degradedNoNotification,

  /// Watchdog failed to restart BackgroundMonitoringService.
  watchdogRestartFailed;

  /// Duration and final transcript when state is [stopped]. Reason string
  /// when state is [sttFallbackVosk] / [sttUnavailable]. Otherwise null.
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
    if (raw.startsWith('STT_UNAVAILABLE:')) {
      const prefix = 'STT_UNAVAILABLE:';
      final reason = raw.length > prefix.length
          ? raw.substring(prefix.length)
          : null;
      return (MonitoringState.sttUnavailable, null, reason);
    }
    return switch (raw) {
      'STARTED' => (MonitoringState.started, null, null),
      'NETWORK_AVAILABLE' => (MonitoringState.networkAvailable, null, null),
      'NETWORK_LOST' => (MonitoringState.networkLost, null, null),
      'DEGRADED_NO_NOTIFICATION' => (
        MonitoringState.degradedNoNotification,
        null,
        null,
      ),
      'WATCHDOG_RESTART_FAILED' => (
        MonitoringState.watchdogRestartFailed,
        null,
        null,
      ),
      'STT_UNAVAILABLE' => (MonitoringState.sttUnavailable, null, null),
      _ => (MonitoringState.idle, null, null),
    };
  }
}

/// Stable status values returned by the native `startMonitoring` method.
enum MonitoringStartStatus {
  started,
  alreadyRunning,
  permissionDenied,
  backgroundStartDenied,
  nativeFailure,
}

/// Typed result for starting the platform monitoring service.
///
/// Android v1.6 returns a map with `status` and `message`. During a rolling
/// upgrade (and in older test doubles), a legacy boolean is still accepted so
/// Flutter never mistakes a channel type mismatch for a successful start.
class MonitoringStartResult {
  const MonitoringStartResult(this.status, {this.message});

  final MonitoringStartStatus status;
  final String? message;

  bool get isSuccess =>
      status == MonitoringStartStatus.started ||
      status == MonitoringStartStatus.alreadyRunning;

  factory MonitoringStartResult.fromNative(Object? value) {
    if (value is bool) {
      return value
          ? const MonitoringStartResult(MonitoringStartStatus.started)
          : const MonitoringStartResult(
              MonitoringStartStatus.nativeFailure,
              message: 'Dịch vụ giám sát không thể khởi động.',
            );
    }

    if (value is Map) {
      final statusValue = value['status']?.toString();
      final messageValue = value['message']?.toString().trim();
      final status = switch (statusValue) {
        'started' => MonitoringStartStatus.started,
        'alreadyRunning' => MonitoringStartStatus.alreadyRunning,
        'permissionDenied' => MonitoringStartStatus.permissionDenied,
        'backgroundStartDenied' => MonitoringStartStatus.backgroundStartDenied,
        'nativeFailure' => MonitoringStartStatus.nativeFailure,
        _ => MonitoringStartStatus.nativeFailure,
      };
      return MonitoringStartResult(
        status,
        message: messageValue == null || messageValue.isEmpty
            ? _defaultMessage(status)
            : messageValue,
      );
    }

    return const MonitoringStartResult(
      MonitoringStartStatus.nativeFailure,
      message: 'Phản hồi khởi động giám sát không hợp lệ.',
    );
  }

  static String? _defaultMessage(MonitoringStartStatus status) =>
      switch (status) {
        MonitoringStartStatus.started ||
        MonitoringStartStatus.alreadyRunning => null,
        MonitoringStartStatus.permissionDenied =>
          'Chưa cấp đủ quyền để bắt đầu giám sát.',
        MonitoringStartStatus.backgroundStartDenied =>
          'Android không cho phép khởi động giám sát từ nền.',
        MonitoringStartStatus.nativeFailure =>
          'Dịch vụ giám sát không thể khởi động.',
      };

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is MonitoringStartResult &&
          status == other.status &&
          message == other.message;

  @override
  int get hashCode => Object.hash(status, message);
}

/// A privacy-safe telephony event emitted by the Android native layer.
///
/// The wire schema intentionally has no raw phone-number field. Consumers may
/// display or persist [maskedNumber], but must never try to recover a number
/// from legacy/unknown payload fields.
class NativeCallEvent {
  const NativeCallEvent({
    required this.type,
    this.timestampMs = 0,
    this.reason,
    this.numberAvailable = false,
    this.maskedNumber,
  });

  final String type;
  final int timestampMs;
  final String? reason;
  final bool numberAvailable;
  final String? maskedNumber;

  factory NativeCallEvent.fromMap(Map<Object?, Object?> map) {
    final rawType = map['type'];
    final rawTimestamp = map['timestampMs'];
    final rawReason = map['reason'];
    final rawMaskedNumber = map['maskedNumber'];
    final numberAvailable = map['numberAvailable'] == true;

    return NativeCallEvent(
      type: rawType is String && rawType.isNotEmpty ? rawType : 'UNKNOWN',
      timestampMs: rawTimestamp is num ? rawTimestamp.toInt() : 0,
      reason: rawReason is String && rawReason.isNotEmpty ? rawReason : null,
      numberAvailable: numberAvailable,
      maskedNumber:
          numberAvailable &&
              rawMaskedNumber is String &&
              rawMaskedNumber.isNotEmpty
          ? rawMaskedNumber
          : null,
    );
  }
}

/// Source-compatible name for older embedders. It resolves to the new,
/// privacy-safe schema and therefore does not expose `phoneNumber` or `source`.
typedef CallEvent = NativeCallEvent;

/// Snapshot of all call-shield permissions at a point in time.
class PermissionSnapshot {
  const PermissionSnapshot({
    this.recordAudio = false,
    this.phoneState = false,
    this.callLog = false,
    this.answerPhoneCalls = false,
    this.overlay = false,
    this.notification = false,
    this.accessibility = false,
    this.callScreening = false,
  });

  final bool recordAudio;
  final bool phoneState;
  final bool callLog;
  final bool answerPhoneCalls;
  final bool overlay;
  final bool notification;
  final bool accessibility;
  final bool callScreening;

  factory PermissionSnapshot.fromMap(Map<Object?, Object?> map) {
    return PermissionSnapshot(
      recordAudio: map['recordAudio'] as bool? ?? false,
      phoneState: map['phoneState'] as bool? ?? false,
      callLog: map['callLog'] as bool? ?? false,
      answerPhoneCalls: map['answerPhoneCalls'] as bool? ?? false,
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
      answerPhoneCalls &&
      overlay &&
      notification &&
      accessibility &&
      callScreening;

  int get grantedCount => [
    recordAudio,
    phoneState,
    callLog,
    answerPhoneCalls,
    overlay,
    notification,
    accessibility,
    callScreening,
  ].where((p) => p).length;

  static const int totalPermissions = 8;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is PermissionSnapshot &&
          recordAudio == other.recordAudio &&
          phoneState == other.phoneState &&
          callLog == other.callLog &&
          answerPhoneCalls == other.answerPhoneCalls &&
          overlay == other.overlay &&
          notification == other.notification &&
          accessibility == other.accessibility &&
          callScreening == other.callScreening;

  @override
  int get hashCode => Object.hash(
    recordAudio,
    phoneState,
    callLog,
    answerPhoneCalls,
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
class TranscriptUpdate {
  const TranscriptUpdate({required this.text, required this.isPartial});
  final String text;
  final bool isPartial;
}
