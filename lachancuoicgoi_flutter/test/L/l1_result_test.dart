import 'package:flutter_test/flutter_test.dart';
import 'package:lachancuocgoi_flutter/analysis/analysis_level.dart';
import 'package:lachancuocgoi_flutter/analysis/analysis_result.dart';
import 'package:lachancuocgoi_flutter/analysis/l1/l1_result.dart';
import 'package:lachancuocgoi_flutter/core/risk_level.dart';

void main() {
  group('L1ResultParser.parse - empty / GREEN', () {
    test('empty matches returns GREEN with low alert', () {
      final result = L1ResultParser.parse(<KeywordMatch>{});

      expect(result.overallRiskLevel, RiskLevel.green);
      expect(result.matches, isEmpty);
      expect(result.alertEnabled, isFalse);
      expect(result.analysisLevel, AnalysisLevel.l1);
    });

    test('empty matches returns confidence 0.9', () {
      final result = L1ResultParser.parse(<KeywordMatch>{});
      expect(result.confidence, 0.9);
    });

    test('empty matches reason mentions no risk keywords found', () {
      final result = L1ResultParser.parse(<KeywordMatch>{});
      expect(result.reason, contains('Không tìm thấy'));
    });

    test('matches with only GREEN level return GREEN', () {
      final matches = <KeywordMatch>{
        const KeywordMatch(
          keyword: 'xin chào',
          level: RiskLevel.green,
          category: 'GREETING',
        ),
      };
      final result = L1ResultParser.parse(matches);
      expect(result.overallRiskLevel, RiskLevel.green);
      expect(result.matches, isEmpty);
    });
  });

  group('L1ResultParser.parse - single keyword match', () {
    test('single YELLOW keyword returns YELLOW', () {
      final matches = <KeywordMatch>{
        const KeywordMatch(
          keyword: 'chuyển khoản',
          level: RiskLevel.yellow,
          category: 'MONEY',
        ),
      };
      final result = L1ResultParser.parse(matches);

      expect(result.overallRiskLevel, RiskLevel.yellow);
      expect(result.matches.length, 1);
      expect(result.alertEnabled, isTrue);
    });

    test('single ORANGE keyword returns YELLOW (score=0.60 < 1.0)', () {
      // score = maxLevel(2) * weight(0.30 for 1 keyword) = 0.60 < 1.0 => YELLOW
      final matches = <KeywordMatch>{
        const KeywordMatch(
          keyword: 'chuyển tiền gấp',
          level: RiskLevel.orange,
          category: 'URGENCY',
        ),
      };
      final result = L1ResultParser.parse(matches);

      expect(result.overallRiskLevel, RiskLevel.yellow);
      expect(result.alertEnabled, isTrue);
    });

    test('single RED keyword returns YELLOW (score=0.90 < 1.0)', () {
      // score = maxLevel(3) * weight(0.30 for 1 keyword) = 0.90 < 1.0 => YELLOW
      final matches = <KeywordMatch>{
        const KeywordMatch(
          keyword: 'đe dọa',
          level: RiskLevel.red,
          category: 'THREAT',
        ),
      };
      final result = L1ResultParser.parse(matches);

      expect(result.overallRiskLevel, RiskLevel.yellow);
      expect(result.alertEnabled, isTrue);
    });

    test('three RED keywords in same category reach RED (score=2.55)', () {
      // score = maxLevel(3) * weight(0.85 for 3 keywords) = 2.55 >= 2.0 => RED
      final matches = <KeywordMatch>{
        const KeywordMatch(
          keyword: 'đe dọa',
          level: RiskLevel.red,
          category: 'THREAT',
        ),
        const KeywordMatch(
          keyword: 'khủng bố',
          level: RiskLevel.red,
          category: 'THREAT',
        ),
        const KeywordMatch(
          keyword: 'bắt cóc',
          level: RiskLevel.red,
          category: 'THREAT',
        ),
      };
      final result = L1ResultParser.parse(matches);

      expect(result.overallRiskLevel, RiskLevel.red);
    });

    test('two ORANGE keywords in same category reach ORANGE (score=1.30)', () {
      // score = maxLevel(2) * weight(0.65 for 2 keywords) = 1.30 >= 1.0 => ORANGE
      final matches = <KeywordMatch>{
        const KeywordMatch(
          keyword: 'chuyển tiền',
          level: RiskLevel.orange,
          category: 'MONEY',
        ),
        const KeywordMatch(
          keyword: 'tài khoản',
          level: RiskLevel.orange,
          category: 'MONEY',
        ),
      };
      final result = L1ResultParser.parse(matches);

      expect(result.overallRiskLevel, RiskLevel.orange);
    });
  });

  group('L1ResultParser.parse - critical keywords force RED', () {
    test('OTP keyword forces RED regardless of level', () {
      final matches = <KeywordMatch>{
        const KeywordMatch(
          keyword: 'mã otp',
          level: RiskLevel.yellow,
          category: 'PII',
        ),
      };
      final result = L1ResultParser.parse(matches);

      expect(result.overallRiskLevel, RiskLevel.red);
      expect(result.reason, contains('OTP'));
    });

    test('PIN keyword forces RED', () {
      final matches = <KeywordMatch>{
        const KeywordMatch(
          keyword: 'pin ngân hàng',
          level: RiskLevel.orange,
          category: 'PII',
        ),
      };
      final result = L1ResultParser.parse(matches);

      expect(result.overallRiskLevel, RiskLevel.red);
      expect(result.reason, contains('OTP'));
    });

    test('CVV keyword forces RED', () {
      final matches = <KeywordMatch>{
        const KeywordMatch(
          keyword: 'cvv',
          level: RiskLevel.yellow,
          category: 'PII',
        ),
      };
      final result = L1ResultParser.parse(matches);

      expect(result.overallRiskLevel, RiskLevel.red);
    });

    test('số tài khoản keyword forces RED', () {
      final matches = <KeywordMatch>{
        const KeywordMatch(
          keyword: 'số tài khoản ngân hàng',
          level: RiskLevel.orange,
          category: 'ACCOUNT',
        ),
      };
      final result = L1ResultParser.parse(matches);

      expect(result.overallRiskLevel, RiskLevel.red);
    });

    test('gửi mã keyword forces RED', () {
      final matches = <KeywordMatch>{
        const KeywordMatch(
          keyword: 'gửi mã xác nhận',
          level: RiskLevel.yellow,
          category: 'PII',
        ),
      };
      final result = L1ResultParser.parse(matches);

      expect(result.overallRiskLevel, RiskLevel.red);
    });

    test('critical keyword reason includes security warning tag', () {
      final matches = <KeywordMatch>{
        const KeywordMatch(
          keyword: 'otp',
          level: RiskLevel.yellow,
          category: 'PII',
        ),
      };
      final result = L1ResultParser.parse(matches);

      expect(result.reason, contains('[CẢNH BÁO OTP/BẢO MẬT]'));
    });
  });

  group('L1ResultParser.parse - multiple keywords same category', () {
    test('two keywords from same category escalate score', () {
      final matches = <KeywordMatch>{
        const KeywordMatch(
          keyword: 'chuyển tiền',
          level: RiskLevel.yellow,
          category: 'MONEY',
        ),
        const KeywordMatch(
          keyword: 'gấp rút',
          level: RiskLevel.yellow,
          category: 'MONEY',
        ),
      };
      final result = L1ResultParser.parse(matches);

      expect(result.overallRiskLevel, RiskLevel.yellow);
      expect(result.matches.length, 2);
    });

    test('two RED keywords in same category reach ORANGE (score=1.95)', () {
      // score = maxLevel(3) * weight(0.65 for 2 keywords) = 1.95 < 2.0 => ORANGE
      final matches = <KeywordMatch>{
        const KeywordMatch(
          keyword: 'đe dọa',
          level: RiskLevel.red,
          category: 'THREAT',
        ),
        const KeywordMatch(
          keyword: 'khủng bố',
          level: RiskLevel.red,
          category: 'THREAT',
        ),
      };
      final result = L1ResultParser.parse(matches);

      expect(result.overallRiskLevel, RiskLevel.orange);
    });

    test('significant categories (>=2 matches) appear in reason', () {
      final matches = <KeywordMatch>{
        const KeywordMatch(
          keyword: 'chuyển tiền',
          level: RiskLevel.yellow,
          category: 'MONEY',
        ),
        const KeywordMatch(
          keyword: 'tài khoản',
          level: RiskLevel.yellow,
          category: 'MONEY',
        ),
      };
      final result = L1ResultParser.parse(matches);

      expect(result.reason, contains('MONEY'));
    });
  });

  group('L1ResultParser.parse - multiple categories', () {
    test('keywords from different categories are all included', () {
      final matches = <KeywordMatch>{
        const KeywordMatch(
          keyword: 'công an',
          level: RiskLevel.red,
          category: 'AUTHORITY',
        ),
        const KeywordMatch(
          keyword: 'chuyển tiền',
          level: RiskLevel.orange,
          category: 'MONEY',
        ),
        const KeywordMatch(
          keyword: 'gấp',
          level: RiskLevel.yellow,
          category: 'URGENCY',
        ),
      };
      final result = L1ResultParser.parse(matches);

      expect(result.matches.length, 3);
      expect(result.alertEnabled, isTrue);
    });

    test('diverse categories increase confidence', () {
      final singleCatMatches = <KeywordMatch>{
        const KeywordMatch(
          keyword: 'chuyển tiền',
          level: RiskLevel.yellow,
          category: 'MONEY',
        ),
      };

      final multiCatMatches = <KeywordMatch>{
        const KeywordMatch(
          keyword: 'chuyển tiền',
          level: RiskLevel.yellow,
          category: 'MONEY',
        ),
        const KeywordMatch(
          keyword: 'công an',
          level: RiskLevel.yellow,
          category: 'AUTHORITY',
        ),
        const KeywordMatch(
          keyword: 'gấp',
          level: RiskLevel.yellow,
          category: 'URGENCY',
        ),
      };

      final singleResult = L1ResultParser.parse(singleCatMatches);
      final multiResult = L1ResultParser.parse(multiCatMatches);

      expect(multiResult.confidence, greaterThan(singleResult.confidence));
    });
  });

  group('L1ResultParser.parse - confidence calculation', () {
    test('confidence with zero matches (GREEN path) is 0.9', () {
      final result = L1ResultParser.parse(<KeywordMatch>{});
      expect(result.confidence, 0.9);
    });

    test('confidence increases with more matches', () {
      final oneMatch = <KeywordMatch>{
        const KeywordMatch(
          keyword: 'test1',
          level: RiskLevel.yellow,
          category: 'CAT1',
        ),
      };

      final fiveMatches = <KeywordMatch>{
        const KeywordMatch(
          keyword: 'test1',
          level: RiskLevel.yellow,
          category: 'CAT1',
        ),
        const KeywordMatch(
          keyword: 'test2',
          level: RiskLevel.yellow,
          category: 'CAT2',
        ),
        const KeywordMatch(
          keyword: 'test3',
          level: RiskLevel.orange,
          category: 'CAT3',
        ),
        const KeywordMatch(
          keyword: 'test4',
          level: RiskLevel.orange,
          category: 'CAT4',
        ),
        const KeywordMatch(
          keyword: 'test5',
          level: RiskLevel.red,
          category: 'CAT5',
        ),
      };

      final oneResult = L1ResultParser.parse(oneMatch);
      final fiveResult = L1ResultParser.parse(fiveMatches);

      expect(fiveResult.confidence, greaterThan(oneResult.confidence));
    });

    test('confidence is clamped to max 1.0', () {
      final manyMatches = <KeywordMatch>{
        for (var i = 0; i < 20; i++)
          KeywordMatch(
            keyword: 'keyword$i',
            level: RiskLevel.red,
            category: 'CAT$i',
          ),
      };

      final result = L1ResultParser.parse(manyMatches);
      expect(result.confidence, lessThanOrEqualTo(1.0));
    });

    test('confidence with totalTokens considers proportion', () {
      final matches = <KeywordMatch>{
        const KeywordMatch(
          keyword: 'test',
          level: RiskLevel.yellow,
          category: 'CAT',
        ),
      };

      final withFewTokens = L1ResultParser.parse(matches, 5);
      final withManyTokens = L1ResultParser.parse(matches, 1000);

      expect(withFewTokens.confidence, greaterThanOrEqualTo(withManyTokens.confidence));
    });
  });

  group('L1ResultParser.parse - reason text', () {
    test('RED level reason uses dangerous warning text (via critical keyword)', () {
      // Critical keyword forces RED regardless of score
      final matches = <KeywordMatch>{
        const KeywordMatch(
          keyword: 'mã otp',
          level: RiskLevel.yellow,
          category: 'PII',
        ),
      };
      final result = L1ResultParser.parse(matches);
      expect(result.reason, contains('NGUY HIỂM'));
    });

    test('ORANGE level reason uses risk warning text', () {
      // 2 ORANGE keywords: score = 2 * 0.65 = 1.30 => ORANGE
      final matches = <KeywordMatch>{
        const KeywordMatch(
          keyword: 'chuyển tiền',
          level: RiskLevel.orange,
          category: 'MONEY',
        ),
        const KeywordMatch(
          keyword: 'tài khoản',
          level: RiskLevel.orange,
          category: 'MONEY',
        ),
      };
      final result = L1ResultParser.parse(matches);
      expect(result.reason, contains('NGUY CƠ'));
    });

    test('YELLOW level reason uses attention text', () {
      final matches = <KeywordMatch>{
        const KeywordMatch(
          keyword: 'chuyển khoản',
          level: RiskLevel.yellow,
          category: 'MONEY',
        ),
      };
      final result = L1ResultParser.parse(matches);
      expect(result.reason, contains('lưu ý'));
    });
  });

  group('L1ResultParser.parse - edge cases', () {
    test('duplicate keywords from same category are deduplicated via Set', () {
      // Build from list to avoid equal_elements_in_set lint warning
      final matches = <KeywordMatch>{
        for (final m in [
          const KeywordMatch(
            keyword: 'chuyển tiền',
            level: RiskLevel.yellow,
            category: 'MONEY',
          ),
          const KeywordMatch(
            keyword: 'chuyển tiền',
            level: RiskLevel.yellow,
            category: 'MONEY',
          ),
        ])
          m,
      };
      final result = L1ResultParser.parse(matches);
      expect(result.matches.length, 1);
    });

    test('mixed GREEN and non-GREEN matches filter out GREEN', () {
      final matches = <KeywordMatch>{
        const KeywordMatch(
          keyword: 'xin chào',
          level: RiskLevel.green,
          category: 'GREETING',
        ),
        const KeywordMatch(
          keyword: 'chuyển tiền',
          level: RiskLevel.orange,
          category: 'MONEY',
        ),
      };
      final result = L1ResultParser.parse(matches);
      expect(result.matches.length, 1);
      expect(result.matches.first.keyword, 'chuyển tiền');
    });
  });
}
