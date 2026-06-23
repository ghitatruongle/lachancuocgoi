import '../core/risk_level.dart';
import 'analysis_result.dart';

/// Fusion logic for combining analysis results from L1, L2, and L3 tiers.
///
/// Extracted from [AnalysisCoordinator] to reduce class size and isolate the
/// fusion strategy for unit testing.
class AnalysisFusion {
  /// Fuses results from all three analysis tiers into a single result.
  ///
  /// Combines matches (deduplicated), selects the highest-reason source,
  /// and merges metadata across all tiers.
  static AnalysisResult fuse(
    AnalysisResult l1,
    AnalysisResult l2,
    AnalysisResult l3,
  ) {
    final combinedMatches = <KeywordMatch>{
      ...l1.matches,
      ...l2.matches,
      ...l3.matches,
    }.toList();

    final selected = _selectSource(l1, l2, l3);
    final highestRisk = selected.overallRiskLevel;

    return AnalysisResult(
      overallRiskLevel: highestRisk,
      matches: combinedMatches,
      reason: selected.reason,
      analysisLevel: selected.analysisLevel,
      alertEnabled:
          highestRisk != RiskLevel.green ||
          l1.alertEnabled ||
          l2.alertEnabled ||
          l3.alertEnabled,
      confidence: [l1.confidence, l2.confidence, l3.confidence]
          .reduce((a, b) => a > b ? a : b),
      modelName: selected.modelName,
      isError: l1.isError || l2.isError || l3.isError,
      isFallback: l1.isFallback || l2.isFallback || l3.isFallback,
    );
  }

  /// Selects the source result whose risk level should drive the final outcome.
  ///
  /// Priority: highest risk → L3 > L2 > L1. When all are green, prefers L1.
  static AnalysisResult _selectSource(
    AnalysisResult l1,
    AnalysisResult l2,
    AnalysisResult l3,
  ) {
    final highestRisk = <AnalysisResult>[l1, l2, l3]
        .map((result) => result.overallRiskLevel)
        .reduce((a, b) => a.index > b.index ? a : b);

    if (highestRisk == RiskLevel.green) return l1;
    if (l3.overallRiskLevel == highestRisk) return l3;
    if (l2.overallRiskLevel == highestRisk) return l2;
    return l1;
  }
}
