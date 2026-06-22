import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:permission_handler/permission_handler.dart';

// ─── Data Models ──────────────────────────────────────────────────────────────

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
      final rawTranscript = parts.length > 2 ? parts.sublist(2).join(':') : null;
      final transcript = (rawTranscript == null || rawTranscript.isEmpty) ? null : rawTranscript;
      return (MonitoringState.stopped, duration, transcript);
    }
    if (raw.startsWith('STT_FALLBACK:VOSK:')) {
      // The third field is the reason (e.g. "error12_loop",
      // "network_errors_3"). Empty string is normalised to null.
      const prefix = 'STT_FALLBACK:VOSK:';
      final reason = raw.length > prefix.length ? raw.substring(prefix.length) : null;
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

// ─── Monitoring Stop Result ───────────────────────────────────────────────────

class MonitoringStopResult {
  const MonitoringStopResult({this.durationSeconds, this.finalTranscript});
  final int? durationSeconds;
  final String? finalTranscript;
}

// ─── Transcript Update ────────────────────────────────────────────────────────

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

// ─── Bridge Interface ────────────────────────────────────────────────────────

/// Abstract interface for the native bridge.
/// Allows faking the bridge in tests without touching EventChannels.
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

// ─── Bridge ───────────────────────────────────────────────────────────────────

class NativeCallShieldBridge implements NativeBridgeInterface {
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

  // iOS simulation fields
  bool _iosMonitoringActive = false;
  bool _iosCreatorMonitoringActive = false;
  DateTime? _iosStartTime;
  Timer? _iosSimulationTimer;
  int _iosTimerTicks = 0;

  final _iosMonitoringStateController = StreamController<(MonitoringState, int?, String?)>.broadcast();
  final _iosTranscriptController = StreamController<TranscriptUpdate>.broadcast();
  final _iosRmsController = StreamController<double>.broadcast();
  final _iosCallEventController = StreamController<CallEvent>.broadcast();

  // Preset script for simulating a scam call to show risk detection in action
  static const List<String> _iosScamScript = [
    'Xin chào ông, tôi là cán bộ điều tra thuộc Cơ quan Cảnh sát điều tra Bộ Công an.',
    'Hiện tại số điện thoại và tài khoản ngân hàng của ông đang bị nghi ngờ liên quan đến một đường dây rửa tiền và buôn bán ma túy quy mô lớn xuyên quốc gia.',
    'Để phục vụ công tác điều tra, yêu cầu ông không được tiết lộ thông tin này cho bất kỳ ai khác.',
    'Bây giờ ông cần phải chuyển toàn bộ số tiền hiện có sang một tài khoản tạm giữ an toàn của Bộ Công an để chúng tôi xác minh nguồn gốc.',
    'Tôi sẽ gửi thông tin tài khoản cho ông. Hãy nhanh chóng thực hiện giao dịch này trong vòng 15 phút, nếu không chúng tôi sẽ tiến hành phong tỏa toàn bộ tài sản của ông và gửi lệnh bắt tạm giam hình sự.',
    'Hãy đọc lại cho tôi mã xác thực OTP vừa được gửi đến điện thoại của ông để chúng tôi hoàn tất thủ tục mở hồ sơ bảo lãnh tư pháp.',
  ];

  void _startSimulation() {
    _iosSimulationTimer?.cancel();
    _iosStartTime = DateTime.now();
    _iosTimerTicks = 0;
    _iosSimulationTimer = Timer.periodic(const Duration(milliseconds: 100), (timer) {
      if (!kIsWeb && defaultTargetPlatform == TargetPlatform.android) {
        timer.cancel();
        return;
      }
      _iosTimerTicks++;

      // 1. Emit simulated RMS (waveform data) every 100ms.
      // Thang giả lập khớp rmsDb của Android (~ -2..10 dB) để pipeline
      // chuẩn hóa waveform hoạt động giống nhau trên mọi nền tảng.
      final double mockRms = 2.0 + 6.0 * ((_iosTimerTicks % 30) / 30.0);
      _iosRmsController.add(mockRms);

      // 2. Emit simulated scam script sentences.
      //
      // Within each 10-second window (100 ticks):
      //   • tick % 100 == 0           → commit the current sentence
      //     as a *final* transcript update.
      //   • tick % 100 in [31..79]    → at every 20-tick boundary,
      //     emit a *partial* transcript update that progressively reveals
      //     the next sentence in 5-word chunks (one chunk per 5 ticks).
      //   • everything else           → no transcript event.
      const sentenceCommitInterval = 100;
      const partialWindowStart = 30;
      const partialWindowEnd = 80;
      const partialStride = 20;
      const partialChunkWords = 5;
      final phaseTick = _iosTimerTicks % sentenceCommitInterval;
      if (phaseTick == 0) {
        final sentenceIndex = (_iosTimerTicks ~/ sentenceCommitInterval - 1) %
            _iosScamScript.length;
        final transcript =
            _iosScamScript.sublist(0, sentenceIndex + 1).join(' ');
        _iosTranscriptController.add(
          TranscriptUpdate(text: transcript, isPartial: false),
        );
      } else if (phaseTick > partialWindowStart &&
          phaseTick < partialWindowEnd &&
          phaseTick % partialStride == 0) {
        final sentenceIndex =
            (_iosTimerTicks ~/ sentenceCommitInterval) % _iosScamScript.length;
        final nextSentence = _iosScamScript[sentenceIndex];
        final words = nextSentence.split(' ');
        // Chunks grow: at phaseTick=40, (40-30)/5 = 2 words; at 60, 6 words…
        final wordCount = (phaseTick - partialWindowStart) ~/ partialChunkWords;
        if (wordCount > 0 && wordCount <= words.length) {
          final partialText = words.sublist(0, wordCount).join(' ');
          final previousTranscript = sentenceIndex > 0
              ? '${_iosScamScript.sublist(0, sentenceIndex).join(' ')} '
              : '';
          _iosTranscriptController.add(TranscriptUpdate(
            text: '$previousTranscript$partialText',
            isPartial: true,
          ));
        }
      }
    });
  }

  void _stopSimulation() {
    _iosSimulationTimer?.cancel();
    _iosSimulationTimer = null;
  }

  /// Tears down the iOS/desktop simulation state (timer + broadcast stream
  /// controllers). The bridge is normally a singleton kept alive for the whole
  /// app, so this is mainly for tests and explicit teardown — it makes the
  /// previously-uncancellable simulation timer / controllers collectible and
  /// prevents a 100 ms periodic timer from firing into a controller nobody
  /// listens to if monitoring was started but never stopped (e.g. app killed
  /// during a desktop/test run).
  @visibleForTesting
  void dispose() {
    _stopSimulation();
    _iosMonitoringActive = false;
    _iosCreatorMonitoringActive = false;
    _iosStartTime = null;
    _iosTimerTicks = 0;
    if (!_iosMonitoringStateController.isClosed) {
      _iosMonitoringStateController.close();
    }
    if (!_iosTranscriptController.isClosed) {
      _iosTranscriptController.close();
    }
    if (!_iosRmsController.isClosed) {
      _iosRmsController.close();
    }
    if (!_iosCallEventController.isClosed) {
      _iosCallEventController.close();
    }
  }

  // ─── MethodChannel calls ────────────────────────────────────────────────

  @override
  Future<bool> startMonitoring({
    String? phoneNumber,
    bool enableSpeakerphone = false,
  }) async {
    if (kIsWeb || defaultTargetPlatform != TargetPlatform.android) {
      _iosMonitoringActive = true;
      _iosMonitoringStateController.add((MonitoringState.started, null, null));
      _startSimulation();
      return true;
    }
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
    if (kIsWeb || defaultTargetPlatform != TargetPlatform.android) {
      _iosMonitoringActive = false;
      _stopSimulation();
      final duration = _iosStartTime != null 
          ? DateTime.now().difference(_iosStartTime!).inSeconds 
          : 0;
      final fullTranscript = _iosScamScript.take((_iosTimerTicks ~/ 100)).join(' ');
      _iosMonitoringStateController.add((MonitoringState.stopped, duration, fullTranscript));
      return true;
    }
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
    if (kIsWeb || defaultTargetPlatform != TargetPlatform.android) {
      _iosCreatorMonitoringActive = true;
      _iosMonitoringStateController.add((MonitoringState.started, null, null));
      _startSimulation();
      return true;
    }
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
    if (kIsWeb || defaultTargetPlatform != TargetPlatform.android) {
      _iosCreatorMonitoringActive = false;
      _stopSimulation();
      final duration = _iosStartTime != null 
          ? DateTime.now().difference(_iosStartTime!).inSeconds 
          : 0;
      final fullTranscript = _iosScamScript.take((_iosTimerTicks ~/ 100)).join(' ');
      _iosMonitoringStateController.add((MonitoringState.stopped, duration, fullTranscript));
      return true;
    }
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
    if (kIsWeb || defaultTargetPlatform != TargetPlatform.android) {
      debugPrint('iOS Simulation: RED ALERT displayed - $reason');
      return true;
    }
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
    if (kIsWeb || defaultTargetPlatform != TargetPlatform.android) {
      debugPrint('iOS Simulation: ORANGE ALERT displayed - $reason');
      return true;
    }
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
    if (kIsWeb || defaultTargetPlatform != TargetPlatform.android) {
      debugPrint('iOS Simulation: Alert dismissed');
      return true;
    }
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
    if (kIsWeb || defaultTargetPlatform != TargetPlatform.android) {
      final micGranted = await Permission.microphone.isGranted;
      final notifGranted = await Permission.notification.isGranted;
      return PermissionSnapshot(
        recordAudio: micGranted,
        phoneState: true,
        callLog: true,
        overlay: true,
        notification: notifGranted,
        accessibility: true,
        callScreening: true,
      );
    }
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
    if (kIsWeb || defaultTargetPlatform != TargetPlatform.android) {
      return true;
    }
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
    if (kIsWeb || defaultTargetPlatform != TargetPlatform.android) {
      return true;
    }
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
    if (kIsWeb || defaultTargetPlatform != TargetPlatform.android) {
      return true;
    }
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
    if (kIsWeb || defaultTargetPlatform != TargetPlatform.android) {
      return true;
    }
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
    if (kIsWeb || defaultTargetPlatform != TargetPlatform.android) {
      return true;
    }
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

  Future<bool> isAccessibilityEnabled() async {
    if (kIsWeb || defaultTargetPlatform != TargetPlatform.android) {
      return true;
    }
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

  @override
  Future<bool> isMonitoringActive() async {
    if (kIsWeb || defaultTargetPlatform != TargetPlatform.android) {
      return _iosMonitoringActive;
    }
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
    if (kIsWeb || defaultTargetPlatform != TargetPlatform.android) {
      return _iosCreatorMonitoringActive;
    }
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
    if (kIsWeb || defaultTargetPlatform != TargetPlatform.android) {
      debugPrint('iOS Simulation: Incoming Call Overlay shown - $callerInfo');
      return;
    }
    try {
      await _methodChannel.invokeMethod<void>(
        'showIncomingCallOverlay',
        {'callerInfo': callerInfo},
      );
    } on PlatformException catch (e) {
      debugPrint('NativeBridge.showIncomingCallOverlay error: $e');
    }
  }

  @override
  Future<void> dismissIncomingCallOverlay() async {
    if (kIsWeb || defaultTargetPlatform != TargetPlatform.android) {
      debugPrint('iOS Simulation: Incoming Call Overlay dismissed');
      return;
    }
    try {
      await _methodChannel.invokeMethod<void>('dismissIncomingCallOverlay');
    } on PlatformException catch (e) {
      debugPrint('NativeBridge.dismissIncomingCallOverlay error: $e');
    }
  }

  // ─── EventChannel streams (cached to prevent memory leaks) ─────────────

  late final Stream<TranscriptUpdate> _cachedTranscriptStream = _transcriptChannel
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
  Stream<TranscriptUpdate> get transcriptStream {
    if (kIsWeb || defaultTargetPlatform != TargetPlatform.android) {
      return _iosTranscriptController.stream;
    }
    return _cachedTranscriptStream;
  }

  @override
  Stream<double> get rmsStream {
    if (kIsWeb || defaultTargetPlatform != TargetPlatform.android) {
      return _iosRmsController.stream;
    }
    return _cachedRmsStream;
  }

  @override
  Stream<(MonitoringState, int?, String?)> get monitoringStateStream {
    if (kIsWeb || defaultTargetPlatform != TargetPlatform.android) {
      return _iosMonitoringStateController.stream;
    }
    return _cachedMonitoringStateStream;
  }

  @override
  Stream<CallEvent> get callEventStream {
    if (kIsWeb || defaultTargetPlatform != TargetPlatform.android) {
      return _iosCallEventController.stream;
    }
    return _cachedCallEventStream;
  }
}

// ─── Riverpod Provider ────────────────────────────────────────────────────────

final nativeBridgeProvider = Provider<NativeBridgeInterface>((ref) {
  return NativeCallShieldBridge.instance;
});
