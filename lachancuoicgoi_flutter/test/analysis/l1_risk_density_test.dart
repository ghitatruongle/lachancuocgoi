import 'package:flutter_test/flutter_test.dart';
import 'package:lachancuocgoi_flutter/analysis/analysis_result.dart';
import 'package:lachancuocgoi_flutter/analysis/l1/l1_analysis.dart';
import 'package:lachancuocgoi_flutter/core/risk_level.dart';

void main() {
  final analyzer = L1Analyzer();

  group('L1Analyzer._applyRiskDensity — Regression B1', () {
    test('merges a dense yellow cluster into a single synthetic RED match', () {
      final matches = <KeywordMatch>{
        const KeywordMatch(
          keyword: 'a',
          level: RiskLevel.yellow,
          category: 'MONEY',
          startIndex: 0,
          endIndex: 0,
        ),
        const KeywordMatch(
          keyword: 'b',
          level: RiskLevel.yellow,
          category: 'MONEY',
          startIndex: 1,
          endIndex: 1,
        ),
        const KeywordMatch(
          keyword: 'c',
          level: RiskLevel.yellow,
          category: 'MONEY',
          startIndex: 2,
          endIndex: 2,
        ),
      };

      final result = analyzer.applyRiskDensityForTesting(matches, 10);

      expect(result.length, equals(1));
      final merged = result.single;
      expect(merged.level, RiskLevel.red);
      expect(merged.category, equals('Mật độ rủi ro cao (Risk Density)'));

      expect(merged.keyword, equals('a + b + c'));
      expect(merged.startIndex, equals(0));
      expect(merged.endIndex, equals(2));
    });

    test(
      'no duplicates leak when red/green matches interleave the cluster',
      () {
        final matches = <KeywordMatch>{
          const KeywordMatch(
            keyword: 'a',
            level: RiskLevel.yellow,
            category: 'MONEY',
            startIndex: 0,
            endIndex: 0,
          ),
          const KeywordMatch(
            keyword: 'r',
            level: RiskLevel.red,
            category: 'THREAT',
            startIndex: 1,
            endIndex: 1,
          ),
          const KeywordMatch(
            keyword: 'b',
            level: RiskLevel.yellow,
            category: 'MONEY',
            startIndex: 2,
            endIndex: 2,
          ),
          const KeywordMatch(
            keyword: 'g',
            level: RiskLevel.green,
            category: 'GREETING',
            startIndex: 4,
            endIndex: 4,
          ),
          const KeywordMatch(
            keyword: 'c',
            level: RiskLevel.yellow,
            category: 'MONEY',
            startIndex: 6,
            endIndex: 6,
          ),
        };

        final result = analyzer.applyRiskDensityForTesting(matches, 20);

        final density = result
            .where((m) => m.category == 'Mật độ rủi ro cao (Risk Density)')
            .toList();
        expect(density.length, equals(1));

        expect(density.single.keyword, equals('a + b + c'));
        expect(density.single.startIndex, equals(0));
        expect(density.single.endIndex, equals(6));

        final leakedYellows = result
            .where((m) => m.level == RiskLevel.yellow)
            .map((m) => m.keyword)
            .toSet();
        expect(
          leakedYellows,
          isEmpty,
          reason: 'Cluster members leaked back into the result',
        );

        expect(
          result.any((m) => m.keyword == 'r' && m.level == RiskLevel.red),
          isTrue,
        );

        expect(
          result.any((m) => m.keyword == 'g' && m.level == RiskLevel.green),
          isTrue,
        );
      },
    );

    test('fewer than 3 dense matches leaves them unchanged', () {
      final matches = <KeywordMatch>{
        const KeywordMatch(
          keyword: 'a',
          level: RiskLevel.yellow,
          category: 'MONEY',
          startIndex: 0,
          endIndex: 0,
        ),
        const KeywordMatch(
          keyword: 'b',
          level: RiskLevel.yellow,
          category: 'MONEY',
          startIndex: 2,
          endIndex: 2,
        ),
      };

      final result = analyzer.applyRiskDensityForTesting(matches, 10);

      expect(result.length, equals(2));
      expect(result.every((m) => m.level == RiskLevel.yellow), isTrue);
      expect(result.any((m) => m.category.contains('Risk Density')), isFalse);
    });

    test('matches beyond the 10-token window are not clustered', () {
      final matches = <KeywordMatch>{
        const KeywordMatch(
          keyword: 'a',
          level: RiskLevel.yellow,
          category: 'MONEY',
          startIndex: 0,
          endIndex: 0,
        ),
        const KeywordMatch(
          keyword: 'b',
          level: RiskLevel.yellow,
          category: 'MONEY',
          startIndex: 5,
          endIndex: 5,
        ),
        const KeywordMatch(
          keyword: 'c',
          level: RiskLevel.yellow,
          category: 'MONEY',
          startIndex: 20,
          endIndex: 20,
        ),
      };

      final result = analyzer.applyRiskDensityForTesting(matches, 30);

      expect(result.length, equals(3));
      expect(result.any((m) => m.level == RiskLevel.red), isFalse);
    });

    test('returns input unchanged when fewer than 2 matches', () {
      final single = <KeywordMatch>{
        const KeywordMatch(
          keyword: 'solo',
          level: RiskLevel.orange,
          category: 'MONEY',
          startIndex: 0,
          endIndex: 0,
        ),
      };

      final result = analyzer.applyRiskDensityForTesting(single, 5);
      expect(result, equals(single));
    });

    test('orange cluster members are merged the same as yellow', () {
      final matches = <KeywordMatch>{
        const KeywordMatch(
          keyword: 'x',
          level: RiskLevel.orange,
          category: 'URGENCY',
          startIndex: 0,
          endIndex: 0,
        ),
        const KeywordMatch(
          keyword: 'y',
          level: RiskLevel.orange,
          category: 'URGENCY',
          startIndex: 1,
          endIndex: 1,
        ),
        const KeywordMatch(
          keyword: 'z',
          level: RiskLevel.orange,
          category: 'URGENCY',
          startIndex: 3,
          endIndex: 3,
        ),
      };

      final result = analyzer.applyRiskDensityForTesting(matches, 10);

      expect(result.length, equals(1));
      expect(result.single.level, RiskLevel.red);
      expect(result.single.keyword, equals('x + y + z'));
    });
  });
}
