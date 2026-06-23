// ignore_for_file: prefer_final_fields
import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lachancuocgoi_flutter/analysis/analysis_mode.dart';
import 'package:lachancuocgoi_flutter/app/lachancuocgoi_app.dart';
import 'package:lachancuocgoi_flutter/app/router.dart';
import 'package:lachancuocgoi_flutter/app/settings_controller.dart';
import 'package:lachancuocgoi_flutter/data/app_database.dart';
import 'package:lachancuocgoi_flutter/data/call_history.dart';
import 'package:lachancuocgoi_flutter/services/developer_mode_manager.dart';
import 'package:lachancuocgoi_flutter/services/native_call_shield_bridge.dart';
import 'package:lachancuocgoi_flutter/services/permission_controller.dart';
import 'package:lachancuocgoi_flutter/ui/history_page/history_page.dart';
import 'package:lachancuocgoi_flutter/ui/home_page/home_page.dart';
import 'package:lachancuocgoi_flutter/ui/monitoring_page/monitoring_page.dart';
import 'package:lachancuocgoi_flutter/ui/result_page/result_page.dart';

import 'package:flutter/foundation.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

/// In-memory database helper for integration tests.
class TestDb {
  TestDb._(this.database);

  final AppDatabase database;

  static Future<TestDb> openInMemory() async {
    if (!kIsWeb &&
        (defaultTargetPlatform == TargetPlatform.windows ||
            defaultTargetPlatform == TargetPlatform.macOS ||
            defaultTargetPlatform == TargetPlatform.linux)) {
      sqfliteFfiInit();
      databaseFactory = databaseFactoryFfi;
    }
    final db = await AppDatabase.open(inMemory: true);
    return TestDb._(db);
  }

  Future<List<CallHistory>> all() => database.getAll();
  Future<int> rowCount() => database.count();
  Future<CallHistory?> byId(int id) => database.getById(id);

  Future<int> insert(CallHistory row) => database.insert(row);

  Future<void> close() => database.close();
}

/// Fake [NativeBridgeInterface] used by integration tests.
class FakeIntegrationBridge implements NativeBridgeInterface {
  FakeIntegrationBridge();

  final StreamController<TranscriptUpdate> _transcript =
      StreamController<TranscriptUpdate>.broadcast();
  final StreamController<double> _rms =
      StreamController<double>.broadcast();
  final StreamController<(MonitoringState, int?, String?)> _monitoringState =
      StreamController<(MonitoringState, int?, String?)>.broadcast();
  final StreamController<CallEvent> _callEvents =
      StreamController<CallEvent>.broadcast();

  final List<String> methodCallList = <String>[];
  final List<({String method, Map<String, Object?> args})>
      methodCallsWithArgs = <({String method, Map<String, Object?> args})>[];

  PermissionSnapshot _permissionSnapshot = const PermissionSnapshot();
  void setPermissionSnapshot(PermissionSnapshot s) => _permissionSnapshot = s;

  bool _monitoringActive = false;
  void setMonitoringActive({required bool active}) =>
      _monitoringActive = active;

  @override
  Future<PermissionSnapshot> getPermissionSnapshot() async {
    methodCallList.add('getPermissionSnapshot');
    return _permissionSnapshot;
  }

  void emitTranscript(String text, {bool isPartial = false}) {
    _transcript.add(TranscriptUpdate(text: text, isPartial: isPartial));
  }

  void emitRms(double value) => _rms.add(value);

  void emitMonitoringStateTuple((MonitoringState, int?, String?) tuple) {
    _monitoringState.add(tuple);
  }

  void emitMonitoringState(
    MonitoringState s, {
    int? duration,
    String? transcript,
  }) {
    _monitoringState.add((s, duration, transcript));
  }

  void sendMonitoringState(String raw) {
    _monitoringState.add(MonitoringState.parse(raw));
  }

  void emitCallEvent(CallEvent event) => _callEvents.add(event);

  @override
  Stream<TranscriptUpdate> get transcriptStream => _transcript.stream;

  @override
  Stream<double> get rmsStream => _rms.stream;

  @override
  Stream<(MonitoringState, int?, String?)> get monitoringStateStream =>
      _monitoringState.stream;

  @override
  Stream<CallEvent> get callEventStream => _callEvents.stream;

  int startMonitoringCalls = 0;
  int stopMonitoringCalls = 0;
  int startCreatorMonitoringCalls = 0;
  int stopCreatorMonitoringCalls = 0;
  int showRedAlertCalls = 0;
  int showOrangeAlertCalls = 0;
  int isMonitoringActiveCalls = 0;
  int isCreatorMonitoringActiveCalls = 0;

  @override
  Future<bool> startMonitoring({
    String? phoneNumber,
    bool enableSpeakerphone = false,
  }) async {
    startMonitoringCalls++;
    methodCallList.add('startMonitoring');
    methodCallsWithArgs.add((
      method: 'startMonitoring',
      args: {
        'phoneNumber': phoneNumber,
        'enableSpeakerphone': enableSpeakerphone,
      },
    ));
    _monitoringActive = true;
    return true;
  }

  @override
  Future<bool> stopMonitoring() async {
    stopMonitoringCalls++;
    methodCallList.add('stopMonitoring');
    _monitoringActive = false;
    return true;
  }

  @override
  Future<bool> startCreatorMonitoring({required int devModeExpiresAtMs}) async {
    startCreatorMonitoringCalls++;
    methodCallList.add('startCreatorMonitoring');
    return true;
  }

  @override
  Future<bool> stopCreatorMonitoring() async {
    stopCreatorMonitoringCalls++;
    methodCallList.add('stopCreatorMonitoring');
    return true;
  }

  @override
  Future<bool> showRedAlert(String reason) async {
    showRedAlertCalls++;
    methodCallList.add('showRedAlert');
    return true;
  }

  @override
  Future<bool> showOrangeAlert(String reason) async {
    showOrangeAlertCalls++;
    methodCallList.add('showOrangeAlert');
    return true;
  }

  @override
  Future<bool> dismissAlert() async {
    methodCallList.add('dismissAlert');
    return true;
  }

  @override
  Future<bool> openAccessibilitySettings() async {
    methodCallList.add('openAccessibilitySettings');
    return true;
  }

  @override
  Future<bool> requestCallScreeningRole() async {
    methodCallList.add('requestCallScreeningRole');
    return true;
  }

  @override
  Future<bool> requestPhoneAndCallLogPermissions() async {
    methodCallList.add('requestPhoneAndCallLogPermissions');
    return true;
  }

  @override
  Future<bool> checkOverlayPermission() async {
    methodCallList.add('checkOverlayPermission');
    return true;
  }

  @override
  Future<bool> requestOverlayPermission() async {
    methodCallList.add('requestOverlayPermission');
    return true;
  }

  @override
  Future<bool> isMonitoringActive() async {
    isMonitoringActiveCalls++;
    methodCallList.add('isMonitoringActive');
    return _monitoringActive;
  }

  @override
  Future<bool> isCreatorMonitoringActive() async {
    isCreatorMonitoringActiveCalls++;
    methodCallList.add('isCreatorMonitoringActive');
    return false;
  }

  @override
  Future<void> showIncomingCallOverlay(String callerInfo) async {
    methodCallList.add('showIncomingCallOverlay');
  }

  @override
  Future<void> dismissIncomingCallOverlay() async {
    methodCallList.add('dismissIncomingCallOverlay');
  }

  Future<void> dispose() async {
    await _transcript.close();
    await _rms.close();
    await _monitoringState.close();
    await _callEvents.close();
  }
}

class _TestSettingsController extends Notifier<SettingsState>
    implements SettingsController {
  _TestSettingsController(this._analysisMode);
  final AnalysisMode _analysisMode;

  @override
  SettingsState build() => SettingsState(
        isDarkTheme: false,
        analysisMode: _analysisMode,
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

class _TestDevModeController extends Notifier<DeveloperModeState>
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

Override _settingsOverride(AnalysisMode mode) =>
    settingsControllerProvider.overrideWith(
      () => _TestSettingsController(mode),
    );

Override _devModeOverride() => developerModeProvider.overrideWith(
      _TestDevModeController.new,
    );

/// State-only permission override — sidesteps the async
/// `_refresh()` race in [PermissionController] by pre-seeding the state
/// before [HomePage] reads it. We extend [PermissionController] so the
/// provider's `PermissionController` type is preserved; the notifier
/// methods are no-ops.
class _TestPermissionController extends PermissionController {
  _TestPermissionController(super.bridge, PermissionState initial) {
    state = initial;
  }
}

Override _permissionOverride(PermissionState initial, NativeBridgeInterface bridge) {
  return permissionControllerProvider.overrideWith(
    () => _TestPermissionController(
      bridge,
      initial,
    ),
  );
}

/// (Type alias removed — see [IntegrationTestHarness.build].)

class HarnessWidget extends StatelessWidget {
  const HarnessWidget({super.key, required this.overrides});
  final List<Override> overrides;

  @override
  Widget build(BuildContext context) {
    return ProviderScope(
      overrides: overrides,
      child: const LachancuocgoiApp(),
    );
  }
}

/// Where to drop the test user when the harness boots. Defaults to
/// `/` (the production home page). For tests that target a deeper
/// route, pass [IntegrationTestHarness.build]'s `initialRoute`.
class IntegrationTestHarness {
  IntegrationTestHarness._({
    required this.widget,
    required this.db,
    required this.bridge,
  });

  final Widget widget;
  final TestDb db;
  final FakeIntegrationBridge bridge;

  static Future<IntegrationTestHarness> build({
    FakeIntegrationBridge? bridge,
    AnalysisMode analysisMode = AnalysisMode.normal,
    PermissionSnapshot initialPermissions = const PermissionSnapshot(
      recordAudio: true,
      phoneState: true,
      callLog: true,
      overlay: true,
      notification: true,
      accessibility: true,
      callScreening: true,
    ),
    String? initialRoute,
  }) async {
    final fake = bridge ?? FakeIntegrationBridge();
    fake.setPermissionSnapshot(initialPermissions);
    final db = await TestDb.openInMemory();

    final permissionState = PermissionState(
      snapshot: initialPermissions,
      isLoading: false,
      lastUpdated: DateTime.now(),
    );

    final overrides = <Override>[
      nativeBridgeProvider.overrideWithValue(fake),
      appDatabaseFutureProvider.overrideWith((ref) async => db.database),
      _settingsOverride(analysisMode),
      _devModeOverride(),
      _permissionOverride(permissionState, fake),
      if (initialRoute != null) _customRouterOverride(initialRoute),
    ];

    return IntegrationTestHarness._(
      widget: HarnessWidget(overrides: overrides),
      db: db,
      bridge: fake,
    );
  }

  Future<void> dispose() async {
    await bridge.dispose();
    await db.close();
  }
}

Override _customRouterOverride(String initialRoute) {
  return appRouterProvider.overrideWith((ref) {
    return GoRouter(
      initialLocation: initialRoute,
      routes: <RouteBase>[
        GoRoute(
          path: '/',
          builder: (_, __) => const HomePage(),
        ),
        GoRoute(
          path: '/monitoring',
          builder: (_, __) => const MonitoringPage(),
        ),
        GoRoute(
          path: '/history',
          builder: (_, __) => const HistoryPage(),
        ),
        GoRoute(
          path: '/result/:historyId',
          builder: (context, state) {
            final id =
                int.tryParse(state.pathParameters['historyId'] ?? '') ?? 0;
            return ResultPage(historyId: id);
          },
        ),
      ],
    );
  });
}
