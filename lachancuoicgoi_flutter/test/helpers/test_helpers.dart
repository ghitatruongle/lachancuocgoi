import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lachancuocgoi_flutter/analysis/analysis_level.dart';
import 'package:lachancuocgoi_flutter/analysis/analysis_result.dart';
import 'package:lachancuocgoi_flutter/analysis/l1/l1_analysis.dart';
import 'package:lachancuocgoi_flutter/core/risk_level.dart';
import 'package:lachancuocgoi_flutter/services/native_call_shield_bridge.dart';

/// Create an L1Analyzer with empty assets for tests that don't need full vocabulary.
L1Analyzer createEmptyL1Analyzer() {
  return L1Analyzer(
    vocabularyProvider: () => '{"riskLevels": []}',
    bigramCorrectionsProvider: () => '{"corrections": []}',
  );
}

/// Common ProviderScope overrides for MonitoringPage widget tests.
List<Override> createCommonOverrides({
  L1Analyzer? l1AnalyzerOverride,
}) {
  return [
    nativeBridgeProvider.overrideWithValue(
      NativeCallShieldBridge.instance,
    ),
  ];
}

/// Pump frames and settle, with a shorter timeout than the default 10 min
/// `pumpAndSettle` uses. Useful for tests that involve Riverpod futures,
/// shared_preferences async reads, or shared platform channels where the
/// default 10-min timeout causes slow test execution when a 5-second
/// grace period is sufficient.
///
/// The function delegates to [WidgetTester.pumpAndSettle] using its
/// positional [duration] / [phase] / [timeout] parameters.
Future<int> pumpAndSettleWithTimeout(
  WidgetTester tester, {
  Duration timeout = const Duration(seconds: 5),
  Duration interval = const Duration(milliseconds: 100),
  EnginePhase phase = EnginePhase.sendSemanticsUpdate,
}) async {
  // pumpAndSettle signature: (duration, phase, timeout) all positional.
  return tester.pumpAndSettle(interval, phase, timeout);
}

/// Wrap a widget with ProviderScope + MaterialApp for testing.
Widget createTestApp({
  required Widget child,
  List<Override> overrides = const [],
  String? initialRoute,
}) {
  return ProviderScope(
    overrides: overrides,
    child: MaterialApp(home: child),
  );
}

/// Factory for a green AnalysisResult (no risk detected).
AnalysisResult createGreenResult() {
  return const AnalysisResult(
    overallRiskLevel: RiskLevel.green,
    matches: <KeywordMatch>[],
    reason: 'Không phát hiện rủi ro.',
    analysisLevel: AnalysisLevel.l1,
    alertEnabled: false,
  );
}

/// Factory for a red AnalysisResult (high risk).
AnalysisResult createRedResult({
  String reason = 'Phát hiện lừa đảo OTP',
  List<KeywordMatch>? matches,
}) {
  return AnalysisResult(
    overallRiskLevel: RiskLevel.red,
    matches: matches ??
        const <KeywordMatch>[
          KeywordMatch(
            keyword: 'OTP',
            level: RiskLevel.red,
            category: 'Lừa đảo',
          ),
        ],
    reason: reason,
    analysisLevel: AnalysisLevel.l1,
    alertEnabled: true,
  );
}

/// Factory for an orange AnalysisResult (medium risk).
AnalysisResult createOrangeResult({
  String reason = 'Nội dung đáng ngờ',
}) {
  return AnalysisResult(
    overallRiskLevel: RiskLevel.orange,
    matches: const <KeywordMatch>[
      KeywordMatch(
        keyword: 'chuyển khoản',
        level: RiskLevel.orange,
        category: 'Tài chính',
      ),
    ],
    reason: reason,
    analysisLevel: AnalysisLevel.l1,
    alertEnabled: true,
  );
}
