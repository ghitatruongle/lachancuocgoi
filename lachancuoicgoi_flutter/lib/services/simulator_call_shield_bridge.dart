import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:permission_handler/permission_handler.dart';
import 'native_bridge_interface.dart';

class SimulatorCallShieldBridge implements NativeBridgeInterface {
  SimulatorCallShieldBridge();

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
    _iosSimulationTimer = Timer.periodic(const Duration(milliseconds: 100), (
      timer,
    ) {
      _iosTimerTicks++;

      final double mockRms = 2.0 + 6.0 * ((_iosTimerTicks % 30) / 30.0);
      _iosRmsController.add(mockRms);

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
    if (!_iosTranscriptController.isClosed) _iosTranscriptController.close();
    if (!_iosRmsController.isClosed) _iosRmsController.close();
    if (!_iosCallEventController.isClosed) _iosCallEventController.close();
  }

  @override
  Future<bool> startMonitoring({
    String? phoneNumber,
    bool enableSpeakerphone = false,
  }) async {
    _iosMonitoringActive = true;
    _iosMonitoringStateController.add((MonitoringState.started, null, null));
    _startSimulation();
    return true;
  }

  @override
  Future<bool> stopMonitoring() async {
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

  @override
  Future<bool> startCreatorMonitoring({required int devModeExpiresAtMs}) async {
    _iosCreatorMonitoringActive = true;
    _iosMonitoringStateController.add((MonitoringState.started, null, null));
    _startSimulation();
    return true;
  }

  @override
  Future<bool> stopCreatorMonitoring() async {
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

  @override
  Future<bool> showRedAlert(String reason) async {
    debugPrint('iOS Simulation: RED ALERT displayed - \$reason');
    return true;
  }

  @override
  Future<bool> showOrangeAlert(String reason) async {
    debugPrint('iOS Simulation: ORANGE ALERT displayed - \$reason');
    return true;
  }

  @override
  Future<bool> dismissAlert() async {
    debugPrint('iOS Simulation: Alert dismissed');
    return true;
  }

  @override
  Future<PermissionSnapshot> getPermissionSnapshot() async {
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

  @override
  Future<bool> openAccessibilitySettings() async => true;

  @override
  Future<bool> requestCallScreeningRole() async => true;

  @override
  Future<bool> requestPhoneAndCallLogPermissions() async => true;

  @override
  Future<bool> checkOverlayPermission() async => true;

  @override
  Future<bool> requestOverlayPermission() async => true;

  @override
  Future<bool> isMonitoringActive() async => _iosMonitoringActive;

  @override
  Future<bool> isCreatorMonitoringActive() async => _iosCreatorMonitoringActive;

  @override
  Future<void> showIncomingCallOverlay(String callerInfo) async {
    debugPrint('iOS Simulation: Incoming Call Overlay shown - \$callerInfo');
  }

  @override
  Future<void> dismissIncomingCallOverlay() async {
    debugPrint('iOS Simulation: Incoming Call Overlay dismissed');
  }

  @override
  Stream<TranscriptUpdate> get transcriptStream =>
      _iosTranscriptController.stream;

  @override
  Stream<double> get rmsStream => _iosRmsController.stream;

  @override
  Stream<(MonitoringState, int?, String?)> get monitoringStateStream =>
      _iosMonitoringStateController.stream;

  @override
  Stream<CallEvent> get callEventStream => _iosCallEventController.stream;
}
