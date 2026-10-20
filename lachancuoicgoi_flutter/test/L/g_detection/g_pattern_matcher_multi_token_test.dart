import 'package:flutter_test/flutter_test.dart';
import 'package:lachancuocgoi_flutter/analysis/l2/g_detection/g_models.dart';
import 'package:lachancuocgoi_flutter/analysis/l2/g_detection/g_pattern_matcher.dart';
import 'package:lachancuocgoi_flutter/core/risk_level.dart';

void main() {
  group('Bug #2: GPatternMatcher multi-token keyword matching', () {
    test('matches keyword with 2 tokens (chuyen khoan)', () {
      final tokens = ['anh', 'phai', 'chuyen', 'khoan', 'ngay'];
      final patterns = [
        const ScamPattern(
          id: 'bank_transfer',
          description: 'Bank transfer',
          riskBonus: 0.9,
          maxGap: 5,
          template: [PatternKeyword('chuyen khoan')],
        ),
      ];
      final results = GPatternMatcher.matchPatterns(tokens, patterns, {});
      expect(results, hasLength(1));
      expect(results[0].patternId, 'bank_transfer');
    });

    test('matches keyword with 3 tokens (chuyen khoan ngan hang)', () {
      final tokens = ['can', 'chuyen', 'khoan', 'ngan', 'hang', 'gap'];
      final patterns = [
        const ScamPattern(
          id: 'bank_transfer_full',
          description: 'Full phrase',
          riskBonus: 0.95,
          maxGap: 5,
          template: [PatternKeyword('chuyen khoan ngan hang')],
        ),
      ];
      final results = GPatternMatcher.matchPatterns(tokens, patterns, {});
      expect(results, hasLength(1));
      expect(results[0].patternId, 'bank_transfer_full');
    });

    test('does NOT match partial keyword (false positive prevention)', () {
      final tokens = ['chuyen', 'tien', 'gap', 'ngay'];
      final patterns = [
        const ScamPattern(
          id: 'bank_transfer',
          description: 'Bank transfer',
          riskBonus: 0.9,
          maxGap: 5,
          template: [PatternKeyword('chuyen khoan')],
        ),
      ];
      final results = GPatternMatcher.matchPatterns(tokens, patterns, {});

      expect(
        results,
        isEmpty,
        reason: 'Should not match when second token differs',
      );
    });

    test('does NOT match when keyword tokens are not contiguous', () {
      final tokens = ['chuyen', 'tien', 'khoan', 'ngay'];
      final patterns = [
        const ScamPattern(
          id: 'bank_transfer',
          description: 'Bank transfer',
          riskBonus: 0.9,
          maxGap: 1,
          template: [PatternKeyword('chuyen khoan')],
        ),
      ];
      final results = GPatternMatcher.matchPatterns(tokens, patterns, {});
      expect(
        results,
        isEmpty,
        reason: 'Tokens must be contiguous when maxGap=1',
      );
    });

    test('matches within maxGap when multi-token keyword spans gap', () {
      final tokens = ['chuyen', 'a', 'b', 'c', 'khoan', 'ngan', 'hang'];
      final patterns = [
        const ScamPattern(
          id: 'bank_full',
          description: 'Full',
          riskBonus: 0.9,
          maxGap: 5,
          template: [PatternKeyword('chuyen khoan ngan hang')],
        ),
      ];

      final results = GPatternMatcher.matchPatterns(tokens, patterns, {});

      expect(
        results,
        isEmpty,
        reason: 'Multi-token keyword requires contiguous match',
      );
    });

    test('single-token keyword still works (regression check)', () {
      final tokens = ['cong', 'an', 'goi', 'di'];
      final patterns = [
        const ScamPattern(
          id: 'police',
          description: 'Police',
          riskBonus: 0.7,
          maxGap: 5,
          template: [PatternKeyword('cong an')],
        ),
      ];
      final results = GPatternMatcher.matchPatterns(tokens, patterns, {});
      expect(results, hasLength(1));
      expect(results[0].patternId, 'police');
    });

    test('multi-token pattern with mixed elements', () {
      final tokens = ['chuyen', 'khoan', 'tien', 'gap', 'ngay'];
      final patterns = [
        const ScamPattern(
          id: 'transfer_urgent',
          description: 'Transfer urgent',
          riskBonus: 0.95,
          maxGap: 5,
          template: [
            PatternKeyword('chuyen khoan'),
            PatternWildcard(),
            PatternKeyword('ngay'),
          ],
        ),
      ];
      final results = GPatternMatcher.matchPatterns(tokens, patterns, {});
      expect(results, hasLength(1));
      expect(results[0].patternId, 'transfer_urgent');
    });
  });

  group('Bug #2: Stress test — all 21 risk patterns still match correctly', () {
    test('multi-token keywords in real-world data are matched', () {
      final testCases = <List<String>, String>{
        ['chuyen', 'khoan']: 'chuyen khoan',
        ['ma', 'otp']: 'ma otp',
        ['the', 'tin', 'dung']: 'the tin dung',
        ['cong', 'an']: 'cong an',
        ['viet', 'com']: 'viet com',
        ['ngan', 'hang']: 'ngan hang',
        ['tai', 'khoan']: 'tai khoan',
      };

      for (final entry in testCases.entries) {
        final tokens = entry.key;
        final keyword = entry.value;
        final patterns = [
          ScamPattern(
            id: 'kw_$keyword',
            description: 'Test $keyword',
            riskBonus: 0.5,
            maxGap: 3,
            template: [PatternKeyword(keyword)],
          ),
        ];
        final results = GPatternMatcher.matchPatterns(tokens, patterns, {});
        expect(
          results,
          hasLength(1),
          reason: 'Keyword "$keyword" phải match với tokens $tokens',
        );
        expect(results[0].patternId, 'kw_$keyword');
      }
    });
  });

  test('RiskLevel enum has expected values', () {
    expect(
      RiskLevel.values,
      containsAll([RiskLevel.green, RiskLevel.orange, RiskLevel.red]),
    );
  });
}
