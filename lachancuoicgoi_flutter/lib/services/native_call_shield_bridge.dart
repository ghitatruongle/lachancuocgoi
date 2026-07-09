import 'dart:async';
import 'package:flutter/foundation.dart' show kIsWeb, defaultTargetPlatform, visibleForTesting, TargetPlatform;
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:permission_handler/permission_handler.dart';

import '../core/system_logger.dart';
import 'native_bridge_interface.dart';

// Re-export the interface + models so existing imports of this file keep
// working. Consumers that only need types should import native_bridge_interface
// directly; this export is for backward compatibility.
export 'native_bridge_interface.dart';

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
  static const _logsChannel = EventChannel(
    'com.lachancuocgoi/logs',
  );

  // iOS simulation fields
  bool _iosMonitoringActive = false;
  bool _iosCreatorMonitoringActive = false;
  DateTime? _iosStartTime;
  Timer? _iosSimulationTimer;
  int _iosTimerTicks = 0;

  final _iosMonitoringStateController =
      StreamController<(MonitoringState, int?, String?)>.broadcast();
  final _iosTranscriptController =
      StreamController<TranscriptUpdate>.broadcast();
  final _iosRmsController = StreamController<double>.broadcast();
  final _iosCallEventController = StreamController<CallEvent>.broadcast();
  final _iosLogsController = StreamController<String>.broadcast();

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
    _iosLogsController.add('INFO|System|Giả lập: Khởi động phiên giám sát cuộc gọi...');
    _iosLogsController.add('INFO|Recording|Giả lập: Thiết lập luồng ghi âm...');
    _iosLogsController.add('INFO|Model|Giả lập: Vosk model preloading...');
    _iosLogsController.add('INFO|Model|Giả lập: Vosk model initialized successfully');
    _iosLogsController.add('INFO|STT|Giả lập: Sẵn sàng nhận diện giọng nói (vi-VN)...');
    _iosSimulationTimer = Timer.periodic(const Duration(milliseconds: 100), (
      timer,
    ) {
      if (!kIsWeb && defaultTargetPlatform == TargetPlatform.android) {
        timer.cancel();
        return;
      }
      _iosTimerTicks++;

      if (_iosTimerTicks == 5) {
        _iosLogsController.add('INFO|Recording|Giả lập: Đã nhận dữ liệu âm thanh (RMS > 0)');
      }
      if (_iosTimerTicks == 30) {
        _iosLogsController.add('INFO|STT|Giả lập: Bắt đầu nhận diện giọng nói Google STT');
      }

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
        final sentenceIndex =
            (_iosTimerTicks ~/ sentenceCommitInterval - 1) %
            _iosScamScript.length;
        final transcript = _iosScamScript
            .sublist(0, sentenceIndex + 1)
            .join(' ');
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
          _iosTranscriptController.add(
            TranscriptUpdate(
              text: '$previousTranscript$partialText',
              isPartial: true,
            ),
          );
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
    if (!_iosLogsController.isClosed) {
      _iosLogsController.close();
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
      SystemLogger.instance.log(LogCategory.bridge, 'NativeBridge.startMonitoring error: $e', level: LogLevel.error);
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
      final fullTranscript = _iosScamScript
          .take((_iosTimerTicks ~/ 100))
          .join(' ');
      _iosMonitoringStateController.add((
        MonitoringState.stopped,
        duration,
        fullTranscript,
      ));
      return true;
    }
    try {
      final result = await _methodChannel.invokeMethod<bool>('stopMonitoring');
      return result ?? false;
    } on PlatformException catch (e) {
      SystemLogger.instance.log(LogCategory.bridge, 'NativeBridge.stopMonitoring error: $e', level: LogLevel.error);
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
      SystemLogger.instance.log(LogCategory.bridge, 'NativeBridge.startCreatorMonitoring error: $e', level: LogLevel.error);
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
      final fullTranscript = _iosScamScript
          .take((_iosTimerTicks ~/ 100))
          .join(' ');
      _iosMonitoringStateController.add((
        MonitoringState.stopped,
        duration,
        fullTranscript,
      ));
      return true;
    }
    try {
      final result = await _methodChannel.invokeMethod<bool>(
        'stopCreatorMonitoring',
      );
      return result ?? false;
    } on PlatformException catch (e) {
      SystemLogger.instance.log(LogCategory.bridge, 'NativeBridge.stopCreatorMonitoring error: $e', level: LogLevel.error);
      return false;
    }
  }

  @override
  Future<bool> showRedAlert(String reason) async {
    if (kIsWeb || defaultTargetPlatform != TargetPlatform.android) {
      SystemLogger.instance.log(LogCategory.bridge, 'iOS Simulation: RED ALERT displayed - $reason');
      return true;
    }
    try {
      final result = await _methodChannel.invokeMethod<bool>('showRedAlert', {
        'reason': reason,
      });
      return result ?? false;
    } on PlatformException catch (e) {
      SystemLogger.instance.log(LogCategory.bridge, 'NativeBridge.showRedAlert error: $e', level: LogLevel.error);
      return false;
    }
  }

  @override
  Future<bool> showOrangeAlert(String reason) async {
    if (kIsWeb || defaultTargetPlatform != TargetPlatform.android) {
      SystemLogger.instance.log(LogCategory.bridge, 'iOS Simulation: ORANGE ALERT displayed - $reason');
      return true;
    }
    try {
      final result = await _methodChannel.invokeMethod<bool>(
        'showOrangeAlert',
        {'reason': reason},
      );
      return result ?? false;
    } on PlatformException catch (e) {
      SystemLogger.instance.log(LogCategory.bridge, 'NativeBridge.showOrangeAlert error: $e', level: LogLevel.error);
      return false;
    }
  }

  @override
  Future<bool> dismissAlert() async {
    if (kIsWeb || defaultTargetPlatform != TargetPlatform.android) {
      SystemLogger.instance.log(LogCategory.bridge, 'iOS Simulation: Alert dismissed');
      return true;
    }
    try {
      final result = await _methodChannel.invokeMethod<bool>('dismissAlert');
      return result ?? false;
    } on PlatformException catch (e) {
      SystemLogger.instance.log(LogCategory.bridge, 'NativeBridge.dismissAlert error: $e', level: LogLevel.error);
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
      SystemLogger.instance.log(LogCategory.bridge, 'NativeBridge.getPermissionSnapshot error: $e', level: LogLevel.error);
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
      SystemLogger.instance.log(LogCategory.bridge, 'NativeBridge.openAccessibilitySettings error: $e', level: LogLevel.error);
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
      SystemLogger.instance.log(LogCategory.bridge, 'NativeBridge.requestCallScreeningRole error: $e', level: LogLevel.error);
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
      SystemLogger.instance.log(LogCategory.bridge, 'NativeBridge.requestPhoneAndCallLogPermissions error: $e', level: LogLevel.error);
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
      SystemLogger.instance.log(LogCategory.bridge, 'NativeBridge.checkOverlayPermission error: $e', level: LogLevel.error);
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
      SystemLogger.instance.log(LogCategory.bridge, 'NativeBridge.requestOverlayPermission error: $e', level: LogLevel.error);
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
      SystemLogger.instance.log(LogCategory.bridge, 'NativeBridge.isAccessibilityEnabled error: $e', level: LogLevel.error);
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
      SystemLogger.instance.log(LogCategory.bridge, 'NativeBridge.isMonitoringActive error: $e', level: LogLevel.error);
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
      SystemLogger.instance.log(LogCategory.bridge, 'NativeBridge.isCreatorMonitoringActive error: $e', level: LogLevel.error);
      return false;
    }
  }

  @override
  Future<void> showIncomingCallOverlay(String callerInfo) async {
    if (kIsWeb || defaultTargetPlatform != TargetPlatform.android) {
      SystemLogger.instance.log(LogCategory.bridge, 'iOS Simulation: Incoming Call Overlay shown - $callerInfo');
      return;
    }
    try {
      await _methodChannel.invokeMethod<void>('showIncomingCallOverlay', {
        'callerInfo': callerInfo,
      });
    } on PlatformException catch (e) {
      SystemLogger.instance.log(LogCategory.bridge, 'NativeBridge.showIncomingCallOverlay error: $e', level: LogLevel.error);
    }
  }

  @override
  Future<void> dismissIncomingCallOverlay() async {
    if (kIsWeb || defaultTargetPlatform != TargetPlatform.android) {
      SystemLogger.instance.log(LogCategory.bridge, 'iOS Simulation: Incoming Call Overlay dismissed');
      return;
    }
    try {
      await _methodChannel.invokeMethod<void>('dismissIncomingCallOverlay');
    } on PlatformException catch (e) {
      SystemLogger.instance.log(LogCategory.bridge, 'NativeBridge.dismissIncomingCallOverlay error: $e', level: LogLevel.error);
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

  late final Stream<CallEvent> _cachedCallEventStream = _callEventChannel
      .receiveBroadcastStream()
      .map((event) {
        if (event is Map) return CallEvent.fromMap(event);
        return const CallEvent(type: 'UNKNOWN');
      })
      .asBroadcastStream();

  late final Stream<String> _cachedLogsStream = _logsChannel
      .receiveBroadcastStream()
      .map((event) => event?.toString() ?? '')
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

  @override
  Stream<String> get logsStream {
    if (kIsWeb || defaultTargetPlatform != TargetPlatform.android) {
      return _iosLogsController.stream;
    }
    return _cachedLogsStream;
  }
}

// ─── Riverpod Provider ────────────────────────────────────────────────────────

final nativeBridgeProvider = Provider<NativeBridgeInterface>((ref) {
  return NativeCallShieldBridge.instance;
});
