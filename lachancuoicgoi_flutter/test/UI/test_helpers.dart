import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart';
import 'package:lachancuocgoi_flutter/analysis/analysis_mode.dart';
import 'package:lachancuocgoi_flutter/app/settings_controller.dart';
import 'package:lachancuocgoi_flutter/services/developer_mode_manager.dart';
import 'package:lachancuocgoi_flutter/services/native_call_shield_bridge.dart';

/// Wraps a widget in MaterialApp + ProviderScope for testing.
Widget testWrap(Widget child, {List<Override> overrides = const []}) {
  return ProviderScope(
    overrides: overrides,
    child: MaterialApp(home: child),
  );
}

/// Wraps a dialog widget for testing (shows it via a button tap).
Widget dialogWrap(Widget dialog) {
  return MaterialApp(
    home: Scaffold(
      body: Builder(
        builder: (context) {
          return ElevatedButton(
            onPressed: () {
              showDialog<void>(context: context, builder: (_) => dialog);
            },
            child: const Text('Open'),
          );
        },
      ),
    ),
  );
}

/// Minimal NativeBridgeInterface mock for permission tests.
class FakeNativeBridge implements NativeBridgeInterface {
  PermissionSnapshot _snapshot;

  FakeNativeBridge({PermissionSnapshot? snapshot})
    : _snapshot = snapshot ?? const PermissionSnapshot();

  @override
  Future<PermissionSnapshot> getPermissionSnapshot() async => _snapshot;

  void setSnapshot(PermissionSnapshot snapshot) => _snapshot = snapshot;

  @override
  Future<bool> startMonitoring({
    String? phoneNumber,
    bool enableSpeakerphone = false,
  }) async => true;
  @override
  Future<bool> stopMonitoring() async => true;
  @override
  Future<bool> startCreatorMonitoring({
    required int devModeExpiresAtMs,
  }) async => true;
  @override
  Future<bool> stopCreatorMonitoring() async => true;
  @override
  Future<bool> showRedAlert(String reason) async => true;
  @override
  Future<bool> showOrangeAlert(String reason) async => true;
  @override
  Future<bool> dismissAlert() async => true;
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
  Future<void> showIncomingCallOverlay(String callerInfo) async {}
  @override
  Future<void> dismissIncomingCallOverlay() async {}

  @override
  Stream<TranscriptUpdate> get transcriptStream => const Stream.empty();
  @override
  Stream<double> get rmsStream => const Stream.empty();
  @override
  Stream<(MonitoringState, int?, String?)> get monitoringStateStream =>
      const Stream.empty();
  @override
  Stream<CallEvent> get callEventStream => const Stream.empty();
}

/// Override for nativeBridgeProvider.
Override bridgeOverride([FakeNativeBridge? bridge]) {
  return nativeBridgeProvider.overrideWithValue(bridge ?? FakeNativeBridge());
}

/// Override for settingsControllerProvider with default test state.
Override settingsOverride() {
  return settingsControllerProvider.overrideWith(
    () => _FakeSettingsController(),
  );
}

class _FakeSettingsController extends Notifier<SettingsState>
    implements SettingsController {
  @override
  SettingsState build() => const SettingsState(
    isDarkTheme: false,
    analysisMode: AnalysisMode.gDetection,
    audioBoost: false,
    autoEnableSpeakerphone: false,
    creatorAudioCapture: false,
    isLoaded: true,
  );

  @override
  Future<void> update(SettingsState next) async {
    state = next;
  }

  @override
  bool get loaded => true;

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

/// Override for developerModeProvider with inactive state.
Override devModeOverride() {
  return developerModeProvider.overrideWith(() => _FakeDevModeController());
}

class _FakeDevModeController extends Notifier<DeveloperModeState>
    implements DeveloperModeController {
  @override
  DeveloperModeState build() => const DeveloperModeState();

  @override
  DeveloperTapResult onTitleTap() => DeveloperTapResult.nothing;

  @override
  bool verifyPassword(String input) => false;

  @override
  Future<void> activate() async {}

  @override
  Future<void> deactivate() async {}

  @override
  bool get isActive => false;

  @override
  int get remainingSeconds => -1;

  @override
  int get expiresAtEpochMs => 0;

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
