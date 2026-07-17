import 'package:flutter_test/flutter_test.dart';
import 'package:lachancuocgoi_flutter/analysis/analysis_coordinator.dart';
import 'package:lachancuocgoi_flutter/analysis/analysis_level.dart';
import 'package:lachancuocgoi_flutter/analysis/analysis_result.dart';
import 'package:lachancuocgoi_flutter/core/risk_level.dart';

void main() {
  group('AnalysisCoordinator._fuseResults — Regression B2', () {
    // Using a coordinator with default (no-op) analyzers just to access
    // fuseResultsForTesting. The analyzers themselves are never called.
    late AnalysisCoordinator coordinator;

    setUp(() {
      coordinator = AnalysisCoordinator();
    });

    test('deduplicates matches shared across L1/L2/L3', () {
      const sharedMatch = KeywordMatch(
        keyword: 'chuyển tiền',
        level: RiskLevel.orange,
        category: 'Tài chính',
        startIndex: 5,
        endIndex: 7,
      );

      const l1 = AnalysisResult(
        overallRiskLevel: RiskLevel.orange,
        matches: [sharedMatch],
        reason: 'L1 orange',
        analysisLevel: AnalysisLevel.l1,
      );
      // L2 produces the same KeywordMatch (same fields → equal by ==).
      const l2 = AnalysisResult(
        overallRiskLevel: RiskLevel.orange,
        matches: [sharedMatch],
        reason: 'L2 orange',
        analysisLevel: AnalysisLevel.l2,
      );
      const l3 = AnalysisResult(
        overallRiskLevel: RiskLevel.green,
        matches: [],
        reason: 'L3 green',
        analysisLevel: AnalysisLevel.l3,
      );

      final fused = coordinator.fuseResultsForTesting(l1, l2, l3);

      // Before the fix, combinedMatches was a List concat that kept both
      // copies. Now deduped via LinkedHashSet → only one match.
      expect(fused.matches.length, equals(1));
      expect(fused.matches.single.keyword, equals('chuyển tiền'));
    });

    test('sets alertEnabled true when highest risk is not green', () {
      const l1 = AnalysisResult(
        overallRiskLevel: RiskLevel.green,
        matches: [],
        reason: 'safe',
        analysisLevel: AnalysisLevel.l1,
      );
      const l2 = AnalysisResult(
        overallRiskLevel: RiskLevel.orange,
        matches: [
          KeywordMatch(
            keyword: 'tài khoản',
            level: RiskLevel.orange,
            category: 'Tài chính',
          ),
        ],
        reason: 'L2 orange',
        analysisLevel: AnalysisLevel.l2,
      );
      const l3 = AnalysisResult(
        overallRiskLevel: RiskLevel.green,
        matches: [],
        reason: 'L3 green',
        analysisLevel: AnalysisLevel.l3,
      );

      final fused = coordinator.fuseResultsForTesting(l1, l2, l3);

      // Before the fix, alertEnabled defaulted to false — alerting was
      // silently dropped on fused parallel results.
      expect(fused.alertEnabled, isTrue);
      expect(fused.overallRiskLevel, RiskLevel.orange);
    });

    test('sets alertEnabled false when all layers are green', () {
      const green = AnalysisResult(
        overallRiskLevel: RiskLevel.green,
        matches: <KeywordMatch>[],
        reason: 'safe',
        analysisLevel: AnalysisLevel.l1,
      );

      final fused = coordinator.fuseResultsForTesting(green, green, green);
      expect(fused.alertEnabled, isFalse);
      expect(fused.overallRiskLevel, RiskLevel.green);
    });

    test('sets alertEnabled true when highest risk is red', () {
      const l1 = AnalysisResult(
        overallRiskLevel: RiskLevel.green,
        matches: [],
        reason: 'safe',
        analysisLevel: AnalysisLevel.l1,
      );
      const l2 = AnalysisResult(
        overallRiskLevel: RiskLevel.red,
        matches: [
          KeywordMatch(
            keyword: 'mã otp',
            level: RiskLevel.red,
            category: 'OTP',
          ),
        ],
        reason: 'L2 red',
        analysisLevel: AnalysisLevel.l2,
      );
      const l3 = AnalysisResult(
        overallRiskLevel: RiskLevel.green,
        matches: [],
        reason: 'L3 green',
        analysisLevel: AnalysisLevel.l3,
      );

      final fused = coordinator.fuseResultsForTesting(l1, l2, l3);
      expect(fused.alertEnabled, isTrue);
      expect(fused.overallRiskLevel, RiskLevel.red);
    });

    test('picks reason from the highest-risk layer', () {
      const l1 = AnalysisResult(
        overallRiskLevel: RiskLevel.green,
        matches: [],
        reason: 'L1 safe',
        analysisLevel: AnalysisLevel.l1,
      );
      const l2 = AnalysisResult(
        overallRiskLevel: RiskLevel.orange,
        matches: [
          KeywordMatch(
            keyword: 'khuyến mãi',
            level: RiskLevel.orange,
            category: 'Lừa đảo',
          ),
        ],
        reason: 'L2 orange reason',
        analysisLevel: AnalysisLevel.l2,
      );
      const l3 = AnalysisResult(
        overallRiskLevel: RiskLevel.red,
        matches: [
          KeywordMatch(
            keyword: 'lừa đảo',
            level: RiskLevel.red,
            category: 'Scam',
          ),
        ],
        reason: 'L3 red reason',
        analysisLevel: AnalysisLevel.l3,
      );

      final fused = coordinator.fuseResultsForTesting(l1, l2, l3);
      expect(fused.reason, equals('L3 red reason'));
      expect(fused.analysisLevel, AnalysisLevel.l3);
    });
  });
}
