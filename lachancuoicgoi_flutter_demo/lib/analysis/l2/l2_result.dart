import '../../core/risk_level.dart';
import '../analysis_level.dart';
import '../analysis_result.dart';
import 'g_detection/g_models.dart';

class L2ResultParser {
  L2ResultParser._();

  static AnalysisResult parse(GResult gResult) {
    final allEvidence = <KeywordMatch>[...gResult.allMatchedKeywords];

    final topic = gResult.confirmedSituation;
    if (topic != null) {
      allEvidence.insert(
        0,
        KeywordMatch(
          keyword: topic,
          level: RiskLevel.red,
          category: 'Chủ đề Lừa đảo',
        ),
      );
    }

    final distinct = <KeywordMatch>{...allEvidence}.toList()
      ..sort((a, b) => b.level.index.compareTo(a.level.index));

    return AnalysisResult(
      overallRiskLevel: gResult.riskLevel,
      matches: distinct,
      reason: gResult.reason,
      analysisLevel: AnalysisLevel.l2,
      alertEnabled: gResult.alertEnabled,
      confidence: gResult.riskScore?.finalScore ?? -1,
    );
  }
}
