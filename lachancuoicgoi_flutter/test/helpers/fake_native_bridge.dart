import 'dart:async';

import 'package:lachancuocgoi_flutter/services/native_call_shield_bridge.dart';

/// A fake implementation of [NativeBridgeInterface] for widget tests.
///
/// Provides controllable streams that don't depend on platform EventChannels.
/// Use this in tests instead of `NativeCallShieldBridge.instance` to avoid
/// EventChannel hangs.
class FakeNativeBridge implements NativeBridgeInterface {
  FakeNativeBridge();

  final _transcriptController = StreamController<TranscriptUpdate>.broadcast();
  final _rmsController = StreamController<double>.broadcast();
  final _monitoringStateController =
      StreamController<(MonitoringState, int?, String?)>.broadcast();
  final _callEventController = StreamController<CallEvent>.broadcast();
  final _logsController = StreamController<String>.broadcast();

  // Track calls for verification
  int startMonitoringCalls = 0;
  int stopMonitoringCalls = 0;
  int showRedAlertCalls = 0;
  int showOrangeAlertCalls = 0;
  int showIncomingCallOverlayCalls = 0;
  int dismissIncomingCallOverlayCalls = 0;
  String? lastRedAlertReason;
  String? lastOrangeAlertReason;
  String? lastCallerInfo;

  @override
  Stream<TranscriptUpdate> get transcriptStream => _transcriptController.stream;

  @override
  Stream<double> get rmsStream => _rmsController.stream;

  @override
  Stream<(MonitoringState, int?, String?)> get monitoringStateStream =>
      _monitoringStateController.stream;

  @override
  Stream<CallEvent> get callEventStream => _callEventController.stream;

  @override
  Stream<String> get logsStream => _logsController.stream;

  // ── Helpers to emit events in tests ──────────────────────────────────

  void emitTranscript(String text) =>
      _transcriptController.add(TranscriptUpdate(text: text, isPartial: false));
  void emitPartialTranscript(String text) =>
      _transcriptController.add(TranscriptUpdate(text: text, isPartial: true));
  void emitTranscriptUpdate(TranscriptUpdate update) =>
      _transcriptController.add(update);
  void emitRms(double value) => _rmsController.add(value);
  void emitMonitoringState(MonitoringState state) =>
      _monitoringStateController.add((state, null, null));
  void emitCallEvent(CallEvent event) => _callEventController.add(event);
  void emitLog(String logLine) => _logsController.add(logLine);

  // ── MethodChannel stubs ──────────────────────────────────────────────

  @override
  Future<bool> startMonitoring({
    String? phoneNumber,
    bool enableSpeakerphone = false,
  }) async {
    startMonitoringCalls++;
    return true;
  }

  @override
  Future<bool> stopMonitoring() async {
    stopMonitoringCalls++;
    return true;
  }

  @override
  Future<bool> startCreatorMonitoring({
    required int devModeExpiresAtMs,
  }) async => true;

  @override
  Future<bool> stopCreatorMonitoring() async => true;

  @override
  Future<bool> showRedAlert(String reason) async {
    showRedAlertCalls++;
    lastRedAlertReason = reason;
    return true;
  }

  @override
  Future<bool> showOrangeAlert(String reason) async {
    showOrangeAlertCalls++;
    lastOrangeAlertReason = reason;
    return true;
  }

  @override
  Future<bool> dismissAlert() async => true;

  @override
  Future<PermissionSnapshot> getPermissionSnapshot() async =>
      const PermissionSnapshot(
        recordAudio: true,
        phoneState: true,
        callLog: false,
        overlay: true,
        notification: true,
        accessibility: false,
        callScreening: false,
      );

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
  Future<bool> isMonitoringActive() async => false;

  @override
  Future<bool> isCreatorMonitoringActive() async => false;

  @override
  Future<void> showIncomingCallOverlay(String callerInfo) async {
    showIncomingCallOverlayCalls++;
    lastCallerInfo = callerInfo;
  }

  @override
  Future<void> dismissIncomingCallOverlay() async {
    dismissIncomingCallOverlayCalls++;
  }

  // Phase 2 (P2-4): Call screening opt-in stubs.
  @override
  Future<void> setCallScreeningBlockEnabled(bool enabled) async {}
  @override
  Future<void> setBlockedNumbers(List<String> numbers) async {}

  /// Dispose all stream controllers. Call in tearDown.
  void dispose() {
    _transcriptController.close();
    _rmsController.close();
    _monitoringStateController.close();
    _callEventController.close();
  }
}
