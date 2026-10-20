import '../core/risk_level.dart';
import 'analysis_result.dart';

class AnalysisFusion {
  static const double highConfidenceThreshold = 0.75;

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
    final fusedRisk = _resolveFusedRisk(l1, l2, l3);
    final confidence = [
      l1.confidence,
      l2.confidence,
      l3.confidence,
    ].reduce((a, b) => a > b ? a : b);

    return AnalysisResult(
      overallRiskLevel: fusedRisk,
      matches: combinedMatches,
      reason: selected.reason,
      analysisLevel: selected.analysisLevel,

      alertEnabled: fusedRisk.shouldAlert,
      confidence: confidence,
      modelName: selected.modelName,
      isError: l1.isError || l2.isError || l3.isError,
      isFallback: l1.isFallback || l2.isFallback || l3.isFallback,
    );
  }

  static RiskLevel _resolveFusedRisk(
    AnalysisResult l1,
    AnalysisResult l2,
    AnalysisResult l3,
  ) {
    final tiers = [l1, l2, l3];
    final highest = tiers
        .map((t) => t.overallRiskLevel)
        .reduce((a, b) => a.index > b.index ? a : b);

    if (highest == RiskLevel.green) return RiskLevel.green;

    if (l1.overallRiskLevel == RiskLevel.red) {
      return RiskLevel.red;
    }

    final orangePlusCount = tiers
        .where((t) => t.overallRiskLevel.index >= RiskLevel.orange.index)
        .length;

    if (orangePlusCount >= 2) return highest;

    if (l2.overallRiskLevel == highest || l3.overallRiskLevel == highest) {
      final driver = l3.overallRiskLevel == highest ? l3 : l2;
      if (driver.confidence >= highConfidenceThreshold ||
          driver.overallRiskLevel.index >= RiskLevel.orange.index) {
        return highest;
      }
    }

    if (l1.overallRiskLevel.index >= RiskLevel.orange.index &&
        l2.overallRiskLevel.index < RiskLevel.orange.index &&
        l3.overallRiskLevel.index < RiskLevel.orange.index) {
      return RiskLevel.yellow;
    }

    return highest.index >= RiskLevel.yellow.index
        ? (highest.index > RiskLevel.yellow.index ? RiskLevel.yellow : highest)
        : highest;
  }

  static AnalysisResult _selectSource(
    AnalysisResult l1,
    AnalysisResult l2,
    AnalysisResult l3,
  ) {
    final fusedRisk = _resolveFusedRisk(l1, l2, l3);

    if (fusedRisk == RiskLevel.green) return l1;

    if (l1.overallRiskLevel == RiskLevel.red) return l1;
    if (l3.overallRiskLevel.index >= fusedRisk.index &&
        l3.overallRiskLevel.index >= RiskLevel.orange.index) {
      return l3;
    }
    if (l2.overallRiskLevel.index >= fusedRisk.index &&
        l2.overallRiskLevel.index >= RiskLevel.orange.index) {
      return l2;
    }
    if (fusedRisk == RiskLevel.yellow &&
        l1.overallRiskLevel.index >= RiskLevel.orange.index) {
      return l1.copyWith(
        overallRiskLevel: RiskLevel.yellow,
        alertEnabled: false,
        reason: l1.reason == null
            ? 'L1 cảnh báo nhẹ — chờ xác nhận L2/L3.'
            : '${l1.reason} (chờ xác nhận L2/L3)',
      );
    }
    if (l3.overallRiskLevel == fusedRisk) return l3;
    if (l2.overallRiskLevel == fusedRisk) return l2;
    return l1;
  }
}
