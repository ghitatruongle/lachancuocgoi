import 'dart:convert';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:lachancuocgoi_flutter/analysis/analysis_coordinator.dart';
import 'package:lachancuocgoi_flutter/analysis/analysis_mode.dart';
import 'package:lachancuocgoi_flutter/analysis/analysis_providers.dart';
import 'package:lachancuocgoi_flutter/analysis/analysis_result.dart';
import 'package:lachancuocgoi_flutter/analysis/analysis_level.dart';
import 'package:lachancuocgoi_flutter/analysis/health_check.dart';
import 'package:lachancuocgoi_flutter/core/risk_level.dart';
import 'package:lachancuocgoi_flutter/data/alert_history_entry.dart';
import 'package:lachancuocgoi_flutter/data/app_database.dart';
import 'package:lachancuocgoi_flutter/data/call_history.dart';
import 'package:lachancuocgoi_flutter/services/native_call_shield_bridge.dart';
import 'package:lachancuocgoi_flutter/ui/monitoring_page/monitoring_controller.dart';

class ManualMockAnalysisCoordinator implements AnalysisCoordinator {
  @override
  Future<AnalysisResult> analyze(String text, AnalysisMode mode) async =>
      const AnalysisResult(
        overallRiskLevel: RiskLevel.green,
        matches: [],
        analysisLevel: AnalysisLevel.l1,
      );
  @override
  Future<AnalysisResult> analyzeIncremental(
    String fullText,
    AnalysisMode mode, {
    double? speechRate,
  }) async => const AnalysisResult(
    overallRiskLevel: RiskLevel.green,
    matches: [],
    analysisLevel: AnalysisLevel.l1,
  );
  @override
  Future<AnalysisResult?> analyzeIncrementalL3(String fullText) async => null;
  @override
  Future<AnalysisResult> analyzeWithTranscript(
    String incrementalText,
    String fullText,
    AnalysisMode mode,
  ) async => const AnalysisResult(
    overallRiskLevel: RiskLevel.green,
    matches: [],
    analysisLevel: AnalysisLevel.l1,
  );
  @override
  void closeL3Session({bool resetProgress = false}) {}
  @override
  void createL3Session({int initialProcessedTextLength = 0}) {}
  @override
  AnalysisResult fuseResultsForTesting(
    AnalysisResult l1,
    AnalysisResult l2,
    AnalysisResult l3,
  ) => l1;
  @override
  AnalysisResult getLastResult([AnalysisMode? mode]) => const AnalysisResult(
    overallRiskLevel: RiskLevel.green,
    matches: [],
    analysisLevel: AnalysisLevel.l1,
  );
  @override
  int getProcessedTextLength([AnalysisMode? mode]) => 0;
  @override
  void reset() {}
  @override
  void resetMode(AnalysisMode mode) {}
  @override
  Map<String, HealthReport> runAllHealthChecks() => {};
  @override
  void setNetworkAvailable(bool available) {}
  @override
  void setSpeechRate(double charsPerSecond) {}
  @override
  void recordL3Rtt(Duration rtt) {}
  @override
  Map<String, String> healthSummary() => const {};
  @override
  void syncProcessedTextLength(int length, [AnalysisMode? mode]) {}
}

class ManualMockAppDatabase implements AppDatabase {
  CallHistory? lastInserted;
  @override
  Future<int> insert(CallHistory callHistory) async {
    lastInserted = callHistory;
    return 1;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class ManualMockNativeBridge implements NativeBridgeInterface {
  @override
  Stream<TranscriptUpdate> get transcriptStream => const Stream.empty();
  @override
  Stream<double> get rmsStream => const Stream.empty();
  @override
  Stream<(MonitoringState, int?, String?)> get monitoringStateStream =>
      const Stream.empty();
  @override
  Stream<CallEvent> get callEventStream => const Stream.empty();
  @override
  Stream<String> get logsStream => const Stream.empty();
  @override
  Future<bool> isMonitoringActive() async => false;
  @override
  Future<bool> stopMonitoring() async => true;
  // Phase 2 (P2-4): Call screening opt-in stubs.
  @override
  Future<void> setCallScreeningBlockEnabled(bool enabled) async {}
  @override
  Future<void> setBlockedNumbers(List<String> numbers) async {}
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test(
    'MonitoringController Persistence - saves analysisResult and alertHistory',
    () async {
      SharedPreferences.setMockInitialValues({});
      final mockCoordinator = ManualMockAnalysisCoordinator();
      final mockDatabase = ManualMockAppDatabase();
      final mockBridge = ManualMockNativeBridge();

      final container = ProviderContainer(
        overrides: [
          analysisCoordinatorProvider.overrideWithValue(mockCoordinator),
          appDatabaseFutureProvider.overrideWith((ref) async => mockDatabase),
          nativeBridgeProvider.overrideWithValue(mockBridge),
        ],
      );

      final notifier = container.read(monitoringControllerProvider.notifier);

      const result = AnalysisResult(
        overallRiskLevel: RiskLevel.red,
        matches: [
          KeywordMatch(keyword: 'OTP', level: RiskLevel.red, category: 'Test'),
        ],
        reason: 'Dangerous call',
        analysisLevel: AnalysisLevel.l1,
        alertEnabled: true,
      );

      notifier.init();

      // Manually set state to simulate analysis results and alert history
      notifier.state = notifier.state.copyWith(
        analysisResult: result,
        riskLevel: RiskLevel.red,
        alertHistory: [
          AlertHistoryEntry(
            timestamp: DateTime.now().millisecondsSinceEpoch,
            analysisLevel: 'L1',
            riskLevel: 'RED',
            alertCount: 1,
            displayedReason: 'Dangerous call',
            allReasons: ['Dangerous call'],
          ),
        ],
      );

      await notifier.endSession();

      final captured = mockDatabase.lastInserted;
      expect(captured, isNotNull);
      expect(captured!.riskLevel, 'RED');
      expect(captured.analysisResult, isNotNull);

      final savedResult = AnalysisResult.fromJson(
        jsonDecode(captured.analysisResult!) as Map<String, dynamic>,
      );
      expect(savedResult.overallRiskLevel, RiskLevel.red);
      expect(savedResult.reason, 'Dangerous call');

      expect(captured.alertHistory, isNotNull);
      final savedAlerts = jsonDecode(captured.alertHistory!) as List;
      expect(savedAlerts, isNotEmpty);
      expect(savedAlerts.first['riskLevel'], 'RED');
    },
  );
}
