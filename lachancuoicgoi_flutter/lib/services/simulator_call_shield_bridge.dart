import 'dart:async';
import 'package:flutter/foundation.dart' show visibleForTesting;
import 'package:permission_handler/permission_handler.dart';
import '../core/system_logger.dart';
import 'native_bridge_interface.dart';
import 'simulator/simulator_scripts.dart';

class SimulatorCallShieldBridge
    implements NativeBridgeInterface, TypedMonitoringStartBridge {
  SimulatorCallShieldBridge({SimulatorScript? script})
    : _script = script ?? SimulatorScriptCatalog.bankFraud;

  final SimulatorScript _script;

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
  final _iosCallEventController = StreamController<NativeCallEvent>.broadcast();
  final _iosLogsController = StreamController<String>.broadcast();

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
            _script.lines.length;
        final transcript = _script.lines
            .sublist(0, sentenceIndex + 1)
            .join(' ');
        _iosTranscriptController.add(
          TranscriptUpdate(text: transcript, isPartial: false),
        );
      } else if (phaseTick > partialWindowStart &&
          phaseTick < partialWindowEnd &&
          phaseTick % partialStride == 0) {
        final sentenceIndex =
            (_iosTimerTicks ~/ sentenceCommitInterval) % _script.lines.length;
        final nextSentence = _script.lines[sentenceIndex];
        final words = nextSentence.split(' ');
        final wordCount = (phaseTick - partialWindowStart) ~/ partialChunkWords;
        if (wordCount > 0 && wordCount <= words.length) {
          final partialText = words.sublist(0, wordCount).join(' ');
          final previousTranscript = sentenceIndex > 0
              ? '${_script.lines.sublist(0, sentenceIndex).join(' ')} '
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
    if (!_iosLogsController.isClosed) _iosLogsController.close();
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
    if (_iosMonitoringActive) {
      return const MonitoringStartResult(MonitoringStartStatus.alreadyRunning);
    }
    _iosMonitoringActive = true;
    _iosMonitoringStateController.add((MonitoringState.started, null, null));
    _startSimulation();
    return const MonitoringStartResult(MonitoringStartStatus.started);
  }

  @override
  Future<bool> stopMonitoring() async {
    if (!_iosMonitoringActive) return true;
    _iosMonitoringActive = false;
    _stopSimulation();
    final duration = _iosStartTime != null
        ? DateTime.now().difference(_iosStartTime!).inSeconds
        : 0;
    final fullTranscript = _script.lines
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
    if (_iosCreatorMonitoringActive) return true;
    _iosCreatorMonitoringActive = true;
    _iosMonitoringStateController.add((MonitoringState.started, null, null));
    _startSimulation();
    return true;
  }

  @override
  Future<bool> stopCreatorMonitoring() async {
    if (!_iosCreatorMonitoringActive) return true;
    _iosCreatorMonitoringActive = false;
    _stopSimulation();
    final duration = _iosStartTime != null
        ? DateTime.now().difference(_iosStartTime!).inSeconds
        : 0;
    final fullTranscript = _script.lines
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
    SystemLogger.instance.log(
      LogCategory.bridge,
      'iOS Simulation: RED ALERT displayed - $reason',
    );
    return true;
  }

  @override
  Future<bool> showOrangeAlert(String reason) async {
    SystemLogger.instance.log(
      LogCategory.bridge,
      'iOS Simulation: ORANGE ALERT displayed - $reason',
    );
    return true;
  }

  @override
  Future<bool> dismissAlert() async {
    SystemLogger.instance.log(
      LogCategory.bridge,
      'iOS Simulation: Alert dismissed',
    );
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
      answerPhoneCalls: true,
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
    SystemLogger.instance.log(
      LogCategory.bridge,
      'iOS Simulation: Incoming Call Overlay shown - $callerInfo',
    );
  }

  @override
  Future<void> dismissIncomingCallOverlay() async {
    SystemLogger.instance.log(
      LogCategory.bridge,
      'iOS Simulation: Incoming Call Overlay dismissed',
    );
  }

  // Phase 2 (P2-4): Call screening opt-in — no-op on simulator platforms.
  @override
  Future<void> setCallScreeningBlockEnabled(bool enabled) async {}

  @override
  Future<void> setBlockedNumbers(List<String> numbers) async {}

  @override
  Stream<TranscriptUpdate> get transcriptStream =>
      _iosTranscriptController.stream;

  @override
  Stream<double> get rmsStream => _iosRmsController.stream;

  @override
  Stream<(MonitoringState, int?, String?)> get monitoringStateStream =>
      _iosMonitoringStateController.stream;

  @override
  Stream<NativeCallEvent> get callEventStream => _iosCallEventController.stream;

  @override
  Stream<String> get logsStream => _iosLogsController.stream;
}
