import 'package:flutter_test/flutter_test.dart';
import 'package:lachancuocgoi_flutter/analysis/analysis_mode.dart';
import 'package:lachancuocgoi_flutter/analysis/analysis_result.dart';
import 'package:lachancuocgoi_flutter/analysis/analysis_level.dart';
import 'package:lachancuocgoi_flutter/core/risk_level.dart';
import 'package:lachancuocgoi_flutter/ui/monitoring_page/monitoring_controller.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  // ─── MonitoringState ─────────────────────────────────────────────────
  group('MonitoringState', () {
    test('default state has expected values', () {
      const state = MonitoringPageState();

      expect(state.riskLevel, RiskLevel.green);
      expect(state.transcript, '');
      expect(state.elapsedSeconds, 0);
      expect(state.networkAvailable, true);
      expect(state.isFallbackActive, false);
      expect(state.analysisResult, isNull);
      expect(state.isAnalyzing, false);
      expect(state.isEndingSession, false);
      expect(state.isSimulationMode, false);
      expect(state.selectedMode, AnalysisMode.normal);
      expect(state.effectiveMode, AnalysisMode.normal);
      expect(state.isCreatorMode, false);
      expect(state.amplitudes, isEmpty);
      expect(state.navigationIntent, isNull);
    });

    test('copyWith returns new instance with updated fields', () {
      const original = MonitoringPageState();
      final updated = original.copyWith(
        riskLevel: RiskLevel.red,
        transcript: 'Hello',
        elapsedSeconds: 42,
        isAnalyzing: true,
      );

      expect(updated.riskLevel, RiskLevel.red);
      expect(updated.transcript, 'Hello');
      expect(updated.elapsedSeconds, 42);
      expect(updated.isAnalyzing, true);
      // Original unchanged
      expect(original.riskLevel, RiskLevel.green);
      expect(original.transcript, '');
    });

    test('copyWith with clearAnalysisResult sets it to null', () {
      const state = MonitoringPageState(
        analysisResult: AnalysisResult(
          overallRiskLevel: RiskLevel.red,
          matches: [],
          analysisLevel: AnalysisLevel.l1,
        ),
      );
      final cleared = state.copyWith(clearAnalysisResult: true);
      expect(cleared.analysisResult, isNull);
    });

    test('copyWith with clearNavigationIntent sets it to null', () {
      const state = MonitoringPageState(
        navigationIntent: NavigateToResult(42),
      );
      final cleared = state.copyWith(clearNavigationIntent: true);
      expect(cleared.navigationIntent, isNull);
    });

    test('equality works correctly', () {
      const a = MonitoringPageState(transcript: 'hello');
      const b = MonitoringPageState(transcript: 'hello');
      const c = MonitoringPageState(transcript: 'world');

      expect(a, equals(b));
      expect(a, isNot(equals(c)));
    });

    test('hashCode consistent with equality', () {
      const a = MonitoringPageState(transcript: 'hello');
      const b = MonitoringPageState(transcript: 'hello');
      expect(a.hashCode, equals(b.hashCode));
    });
  });

  // ─── NavigationIntent ────────────────────────────────────────────────
  group('NavigationIntent', () {
    test('NavigateToResult holds historyId', () {
      const intent = NavigateToResult(42);
      expect(intent.historyId, 42);
    });

    test('NavigateToHome is const', () {
      const intent = NavigateToHome();
      expect(intent, isA<NavigationIntent>());
    });

    test('different types are not equal', () {
      const a = NavigateToResult(1);
      const b = NavigateToHome();
      expect(a, isNot(equals(b)));
    });
  });

  // ─── modeLabel ───────────────────────────────────────────────────────
  group('MonitoringController.modeLabel', () {
    test('returns L1 for normal mode', () {
      expect(MonitoringController.modeLabel(AnalysisMode.normal), 'L1');
    });

    test('returns L2 for gDetection mode', () {
      expect(MonitoringController.modeLabel(AnalysisMode.gDetection), 'L2');
    });

    test('returns L3 for geminiApi mode', () {
      expect(MonitoringController.modeLabel(AnalysisMode.geminiApi), 'L3');
    });
  });

  // ─── formatElapsedTime ───────────────────────────────────────────────
  group('MonitoringController.formatElapsedTime', () {
    test('formats zero seconds', () {
      expect(MonitoringController.formatElapsedTime(0), '00:00');
    });

    test('formats seconds only', () {
      expect(MonitoringController.formatElapsedTime(45), '00:45');
    });

    test('formats minutes and seconds', () {
      expect(MonitoringController.formatElapsedTime(125), '02:05');
    });

    test('formats exact minutes', () {
      expect(MonitoringController.formatElapsedTime(60), '01:00');
    });

    test('formats large values', () {
      expect(MonitoringController.formatElapsedTime(3661), '61:01');
    });
  });

  // ─── formatSessionDateTime ───────────────────────────────────────────
  group('MonitoringController.formatSessionDateTime', () {
    test('returns non-empty string with expected format', () {
      final result = MonitoringController().formatSessionDateTime();
      // Should match pattern HH:MM:SS DD/MM/YYYY
      expect(result, matches(RegExp(r'\d{2}:\d{2}:\d{2} \d{2}/\d{2}/\d{4}')));
    });
  });
}
