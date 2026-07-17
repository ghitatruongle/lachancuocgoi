import 'package:flutter_test/flutter_test.dart';
import 'package:lachancuocgoi_flutter/analysis/analysis_result.dart';
import 'package:lachancuocgoi_flutter/analysis/l1/l1_analysis.dart';
import 'package:lachancuocgoi_flutter/core/risk_level.dart';

/// Regression tests for Sprint 2.1 (B1): `L1Analyzer._applyRiskDensity`.
///
/// Bug: when 3+ yellow/orange matches cluster within a 10-token window, they
/// must merge into ONE synthetic RED match, and the original cluster members
/// must be removed from the output. The old code (a) kept the originals so the
/// synthetic match was duplicated, and (b) tracked processed indices via a
/// contiguous range derived from the loop counter `j` — but cluster members are
/// NOT contiguous in the sorted list when red/green matches sit between them,
/// so some members leaked back into the result while intervening non-cluster
/// matches were wrongly suppressed.
void main() {
  // The hook is an instance method that does not touch the trie, so an
  // uninitialized analyzer is sufficient and keeps the test fast.
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

      // Exactly one match — the merged cluster. The originals must be gone.
      expect(result.length, equals(1));
      final merged = result.single;
      expect(merged.level, RiskLevel.red);
      expect(merged.category, equals('Mật độ rủi ro cao (Risk Density)'));
      // Joined keywords, span covers the whole cluster.
      expect(merged.keyword, equals('a + b + c'));
      expect(merged.startIndex, equals(0));
      expect(merged.endIndex, equals(2));
    });

    test(
      'no duplicates leak when red/green matches interleave the cluster',
      () {
        // Sorted order (by startIndex):
        //   i=0  yellow "a" @ 0     ─┐
        //   i=1  red    "r" @ 1      │  red is NOT a cluster member
        //   i=2  yellow "b" @ 2     ─┤  cluster members are non-contiguous
        //   i=3  green  "g" @ 4      │  green is NOT a cluster member
        //   i=4  yellow "c" @ 6     ─┘
        // All within 10 tokens of i=0, so denseCount == 3.
        //
        // Old contiguous-range bookkeeping marked [0,1,2] as processed and
        // left index 4 ("c") un-marked → "c" leaked back, and the red match
        // at index 1 was wrongly suppressed. The fix tracks the actual
        // indices of cluster members ([0,2,4]) so only they are consumed.
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

        // The merged density match + the non-cluster red match survive.
        // The green match is also retained (density merge never drops it).
        final density = result
            .where((m) => m.category == 'Mật độ rủi ro cao (Risk Density)')
            .toList();
        expect(density.length, equals(1));
        // Cluster keywords joined; the red "r" and green "g" are excluded.
        expect(density.single.keyword, equals('a + b + c'));
        expect(density.single.startIndex, equals(0));
        expect(density.single.endIndex, equals(6));

        // The yellow cluster members must NOT leak as separate matches.
        final leakedYellows = result
            .where((m) => m.level == RiskLevel.yellow)
            .map((m) => m.keyword)
            .toSet();
        expect(
          leakedYellows,
          isEmpty,
          reason: 'Cluster members leaked back into the result',
        );

        // The intervening red match survives (it was never a cluster member).
        expect(
          result.any((m) => m.keyword == 'r' && m.level == RiskLevel.red),
          isTrue,
        );
        // The intervening green match also survives.
        expect(
          result.any((m) => m.keyword == 'g' && m.level == RiskLevel.green),
          isTrue,
        );
      },
    );

    test('fewer than 3 dense matches leaves them unchanged', () {
      // Two yellow matches within range: denseCount == 2 < 3 → no merge.
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
      // Three yellow matches, but the third is far (>10 tokens) from the
      // first → only the first two cluster (denseCount == 2 < 3), so no merge.
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
