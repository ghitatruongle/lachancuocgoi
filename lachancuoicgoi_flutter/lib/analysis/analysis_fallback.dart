import '../core/risk_level.dart';
import 'analysis_level.dart';
import 'analysis_mode.dart';
import 'analysis_result.dart';

class AnalysisFallback {
  static Future<AnalysisResult> fallbackToL2({
    required String incrementalText,
    required String fullText,
    required String fallbackReason,
    required bool Function() isL2Ready,
    required Future<void> Function() initializeL2,
    required Future<AnalysisResult> Function(
      String incrementalText,
      String fullText,
    )
    runL2Analysis,
  }) async {
    if (!isL2Ready()) {
      await initializeL2();
    }
    if (!isL2Ready()) {
      return AnalysisResult(
        overallRiskLevel: RiskLevel.green,
        matches: const <KeywordMatch>[],
        reason: fallbackReason,
        analysisLevel: AnalysisLevel.l2,
        isError: true,
        isFallback: true,
      );
    }
    final l2Result = await runL2Analysis(incrementalText, fullText);
    return l2Result.copyWith(
      reason: '$fallbackReason ${l2Result.reason ?? ''}'.trim(),
      isFallback: true,
    );
  }

  static AnalysisResult defaultForMode(AnalysisMode mode) {
    final level = switch (mode) {
      AnalysisMode.normal => AnalysisLevel.l1,
      AnalysisMode.gDetection => AnalysisLevel.l2,
      AnalysisMode.geminiApi => AnalysisLevel.l3,
      AnalysisMode.parallel => AnalysisLevel.l3,
    };
    return AnalysisResult(
      overallRiskLevel: RiskLevel.green,
      matches: const <KeywordMatch>[],
      analysisLevel: level,
    );
  }
}
