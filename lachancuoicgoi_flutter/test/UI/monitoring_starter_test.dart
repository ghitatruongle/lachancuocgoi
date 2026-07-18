import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:lachancuocgoi_flutter/analysis/analysis_mode.dart';
import 'package:lachancuocgoi_flutter/app/settings_controller.dart';
import 'package:lachancuocgoi_flutter/services/developer_mode_manager.dart';
import 'package:lachancuocgoi_flutter/services/native_bridge_interface.dart';
import 'package:lachancuocgoi_flutter/ui/monitoring_page/monitoring_starter.dart';
import 'package:lachancuocgoi_flutter/ui/monitoring_page/monitoring_state.dart';

import '../helpers/fake_native_bridge.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late _TypedStartBridge bridge;
  late MonitoringPageState state;
  late MonitoringStarter starter;

  setUp(() {
    bridge = _TypedStartBridge();
    state = const MonitoringPageState();
    starter = MonitoringStarter(
      getBridge: () => bridge,
      getSettings: () => const SettingsState(
        isDarkTheme: false,
        followSystemTheme: true,
        analysisMode: AnalysisMode.normal,
        audioBoost: false,
        autoEnableSpeakerphone: false,
        creatorAudioCapture: false,
      ),
      getDevMode: () => const DeveloperModeState(),
      isSimulationSession: () => false,
      hasTestAnalyzerOverride: () => false,
      getState: () => state,
      updateState: (update) => state = update(state),
    );
  });

  tearDown(() => bridge.dispose());

  test('native failure never transitions the session to active', () async {
    bridge.result = const MonitoringStartResult(
      MonitoringStartStatus.nativeFailure,
      message: 'Native failed',
    );

    expect(
      await starter.startLiveMonitoringIfNeeded(isDisposed: false),
      isFalse,
    );
    expect(state.phase, MonitoringPhase.failed);
    expect(state.monitoringErrorMessage, 'Native failed');

    bridge.result = const MonitoringStartResult(MonitoringStartStatus.started);
    expect(
      await starter.startLiveMonitoringIfNeeded(isDisposed: false),
      isTrue,
    );
    expect(state.phase, MonitoringPhase.active);
    expect(bridge.typedStartCalls, 2);
  });

  test('concurrent starts share one native operation', () async {
    final completer = Completer<MonitoringStartResult>();
    bridge.pendingResult = completer;

    final first = starter.startLiveMonitoringIfNeeded(isDisposed: false);
    final second = starter.startLiveMonitoringIfNeeded(isDisposed: false);
    await Future<void>.delayed(Duration.zero);
    expect(state.phase, MonitoringPhase.starting);
    expect(bridge.typedStartCalls, 1);

    completer.complete(
      const MonitoringStartResult(MonitoringStartStatus.started),
    );
    expect(await first, isTrue);
    expect(await second, isTrue);
    expect(state.phase, MonitoringPhase.active);
    expect(bridge.typedStartCalls, 1);
  });

  test('already-running native service is idempotent', () async {
    bridge.alreadyActive = true;

    expect(
      await starter.startLiveMonitoringIfNeeded(isDisposed: false),
      isTrue,
    );
    expect(state.phase, MonitoringPhase.active);
    expect(bridge.typedStartCalls, 0);
  });
}

class _TypedStartBridge extends FakeNativeBridge
    implements TypedMonitoringStartBridge {
  MonitoringStartResult result = const MonitoringStartResult(
    MonitoringStartStatus.started,
  );
  Completer<MonitoringStartResult>? pendingResult;
  bool alreadyActive = false;
  int typedStartCalls = 0;

  @override
  Future<PermissionSnapshot> getPermissionSnapshot() async =>
      const PermissionSnapshot(
        recordAudio: true,
        phoneState: true,
        callLog: true,
      );

  @override
  Future<bool> isMonitoringActive() async => alreadyActive;

  @override
  Future<MonitoringStartResult> startMonitoringTyped({
    String? phoneNumber,
    bool enableSpeakerphone = false,
  }) {
    typedStartCalls++;
    return pendingResult?.future ?? Future.value(result);
  }
}
