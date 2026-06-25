import 'package:flutter_test/flutter_test.dart';
import 'package:lachancuocgoi_flutter/analysis/l2/g_detection/g_models.dart';
import 'package:lachancuocgoi_flutter/analysis/l2/g_detection/g_pattern_matcher.dart';
import 'package:lachancuocgoi_flutter/analysis/analysis_result.dart';
import 'package:lachancuocgoi_flutter/core/risk_level.dart';

void main() {
  group('GPatternMatcher', () {
    test('matches keyword pattern with gap', () {
      final tokens = ['anh', 'phai', 'chuyen', 'tien', 'gap', 'ngay'];
      final patterns = [
        const ScamPattern(
          id: 'transfer_now',
          description: 'Chuyen tien gap',
          riskBonus: 0.8,
          maxGap: 5,
          template: [
            PatternKeyword('chuyen'),
            PatternKeyword('tien'),
            PatternKeyword('gap'),
          ],
        ),
      ];
      final results = GPatternMatcher.matchPatterns(tokens, patterns, {});
      expect(results, hasLength(1));
      expect(results[0].patternId, 'transfer_now');
      expect(results[0].score, 0.8);
      expect(results[0].matchedElements, contains('chuyen'));
      expect(results[0].matchedElements, contains('gap'));
    });

    test('does not match when gap exceeds maxGap', () {
      final tokens = [
        'chuyen',
        'xxx',
        'yyy',
        'zzz',
        'aaa',
        'bbb',
        'tien',
        'gap',
      ];
      final patterns = [
        const ScamPattern(
          id: 'test',
          description: 'Test',
          riskBonus: 0.5,
          maxGap: 2,
          template: [PatternKeyword('chuyen'), PatternKeyword('tien')],
        ),
      ];
      final results = GPatternMatcher.matchPatterns(tokens, patterns, {});
      expect(results, isEmpty);
    });

    test('wildcard matches any token', () {
      final tokens = ['doc', 'ma', 'otp', 'ngay'];
      final patterns = [
        const ScamPattern(
          id: 'otp_pattern',
          description: 'OTP',
          riskBonus: 0.9,
          maxGap: 5,
          template: [
            PatternKeyword('doc'),
            PatternWildcard(),
            PatternKeyword('otp'),
          ],
        ),
      ];
      final results = GPatternMatcher.matchPatterns(tokens, patterns, {});
      expect(results, hasLength(1));
      expect(results[0].patternId, 'otp_pattern');
    });

    test('category element matches keyword with same category', () {
      final tokens = ['cong', 'an', 'yeu', 'cau', 'chuyen', 'tien'];
      final keywordMatches = {
        const KeywordMatch(
          keyword: 'cong an',
          level: RiskLevel.red,
          category: 'AUTHORITY',
          startIndex: 0,
        ),
      };
      final patterns = [
        const ScamPattern(
          id: 'auth_pattern',
          description: 'Authority',
          riskBonus: 0.7,
          maxGap: 5,
          template: [PatternCategory('AUTHORITY'), PatternKeyword('chuyen')],
        ),
      ];
      final results = GPatternMatcher.matchPatterns(
        tokens,
        patterns,
        keywordMatches,
      );
      expect(results, hasLength(1));
      expect(results[0].patternId, 'auth_pattern');
    });

    test('returns empty for no matching patterns', () {
      final tokens = ['xin', 'chao', 'hom', 'nay'];
      final patterns = [
        const ScamPattern(
          id: 'test',
          description: 'Test',
          riskBonus: 0.5,
          maxGap: 5,
          template: [PatternKeyword('chuyen')],
        ),
      ];
      final results = GPatternMatcher.matchPatterns(tokens, patterns, {});
      expect(results, isEmpty);
    });

    test('returns empty for empty patterns list', () {
      final results = GPatternMatcher.matchPatterns(['test'], [], {});
      expect(results, isEmpty);
    });

    test('returns empty for empty tokens', () {
      final patterns = [
        const ScamPattern(
          id: 'test',
          description: 'Test',
          riskBonus: 0.5,
          maxGap: 5,
          template: [PatternKeyword('test')],
        ),
      ];
      final results = GPatternMatcher.matchPatterns([], patterns, {});
      expect(results, isEmpty);
    });

    test('multiple patterns can match simultaneously', () {
      final tokens = ['chuyen', 'tien', 'gap', 'ngay', 'ma', 'otp'];
      final patterns = [
        const ScamPattern(
          id: 'transfer',
          description: 'Transfer',
          riskBonus: 0.7,
          maxGap: 5,
          template: [PatternKeyword('chuyen'), PatternKeyword('tien')],
        ),
        const ScamPattern(
          id: 'otp',
          description: 'OTP',
          riskBonus: 0.9,
          maxGap: 5,
          template: [PatternKeyword('ma'), PatternKeyword('otp')],
        ),
      ];
      final results = GPatternMatcher.matchPatterns(tokens, patterns, {});
      expect(results, hasLength(2));
      expect(results.map((r) => r.patternId), containsAll(['transfer', 'otp']));
    });

    test('empty template returns no match', () {
      final patterns = [
        const ScamPattern(
          id: 'empty',
          description: 'Empty',
          riskBonus: 0.5,
          template: [],
        ),
      ];
      final results = GPatternMatcher.matchPatterns(['test'], patterns, {});
      expect(results, isEmpty);
    });
  });
}
