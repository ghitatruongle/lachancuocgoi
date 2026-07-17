import '../../../core/risk_level.dart';
import '../../analysis_result.dart';

/// Kết quả phân loại tier — value object bất biến.
class TierClassification {
  const TierClassification({
    required this.tier1Matches,
    required this.tier2Matches,
    required this.tier3Matches,
    required this.hasTier1,
    required this.hasTier2,
    required this.hasTier3,
    required this.tier1Count,
    required this.tier2Count,
    this.tier1Score = 0.0,
    this.tier2Score = 0.0,
    this.tier3Score = 0.0,
    this.hasCluster = false,
  });

  final List<KeywordMatch> tier1Matches;
  final List<KeywordMatch> tier2Matches;
  final List<KeywordMatch> tier3Matches;
  final bool hasTier1;
  final bool hasTier2;
  final bool hasTier3;
  final int tier1Count;
  final int tier2Count;

  /// Continuous tier scores (0.0–1.0) based on match count.
  final double tier1Score;
  final double tier2Score;
  final double tier3Score;

  /// Whether tier keywords appear in a tight cluster (within 5 tokens).
  final bool hasCluster;
}

/// Kết quả aggregation tier + scenario + pattern — value object bất biến.
class AggregatedRisk {
  const AggregatedRisk({
    required this.finalLevel,
    required this.finalReason,
    required this.hasGoodScenarioMatch,
  });

  final RiskLevel finalLevel;
  final String finalReason;
  final bool hasGoodScenarioMatch;
}
