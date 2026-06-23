import '../core/risk_level.dart';
import 'analysis_level.dart';
import 'analysis_mode.dart';
import 'analysis_result.dart';

/// Fallback chain logic for [AnalysisCoordinator].
///
/// When a higher-priority analysis tier (L3) fails or is unavailable, the
/// coordinator falls back to lower tiers (L2) with appropriate error metadata.
///
/// Extracted from [AnalysisCoordinator] to reduce class size.
class AnalysisFallback {
  /// Fallback to L2 analysis when L3 is unavailable or errors.
  ///
  /// [l2Analyzer] is called synchronously (it must already be ready). If L2 is
  /// also unavailable, returns a safe green result with [fallbackReason].
  static Future<AnalysisResult> fallbackToL2({
    required String incrementalText,
    required String fullText,
    required String fallbackReason,
    required bool Function() isL2Ready,
    required Future<void> Function() initializeL2,
    required Future<AnalysisResult> Function(String incrementalText, String fullText) runL2Analysis,
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

  /// Returns a safe default result for the given [AnalysisMode].
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
