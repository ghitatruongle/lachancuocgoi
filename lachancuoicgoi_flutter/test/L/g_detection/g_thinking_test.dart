import 'package:flutter_test/flutter_test.dart';
import 'package:lachancuocgoi_flutter/analysis/l2/g_detection/g_models.dart';
import 'package:lachancuocgoi_flutter/analysis/l2/g_detection/g_thinking.dart';
import 'package:lachancuocgoi_flutter/analysis/analysis_result.dart';
import 'package:lachancuocgoi_flutter/core/risk_level.dart';

void main() {
  group('GThinking', () {
    setUp(() {
      GThinking.loadTierConfig(
        tier1: {'cong an', 'ngan hang'},
        tier2: {'gap', 'ngay lap tuc', 'lenh bat'},
        tier3: {'ma otp', 'so tai khoan'},
      );
    });

    test('isTierConfigLoaded returns true after loading', () {
      expect(GThinking.isTierConfigLoaded, isTrue);
    });

    test('safe sentence match returns green with alert disabled', () {
      final result = GThinking.analyze(
        allMatchedKeywords: {},
        topTopic: null,
        sentenceMatch: const SentenceMatch(
          sentence: 'xin chao',
          level: 0,
          isSafe: true,
        ),
      );
      expect(result.riskLevel, RiskLevel.green);
      expect(result.alertEnabled, isFalse);
      expect(result.reason, contains('an toàn'));
    });

    test('dangerous sentence match returns red with alert enabled', () {
      final result = GThinking.analyze(
        allMatchedKeywords: {},
        topTopic: null,
        sentenceMatch: const SentenceMatch(
          sentence: 'doc ma otp',
          level: 3,
          isSafe: false,
        ),
      );
      expect(result.riskLevel, RiskLevel.red);
      expect(result.alertEnabled, isTrue);
      expect(result.reason, contains('nguy hiểm'));
    });

    test('tier3 PII keyword forces red', () {
      final keywords = {
        const KeywordMatch(
          keyword: 'ma otp',
          level: RiskLevel.yellow,
          category: 'PII',
        ),
      };
      final result = GThinking.analyze(
        allMatchedKeywords: keywords,
        topTopic: 'test',
      );
      expect(result.riskLevel, RiskLevel.red);
      expect(result.alertEnabled, isTrue);
      expect(result.reason, contains('nhạy cảm'));
    });

    test('tier1 + tier2 keywords produce orange', () {
      final keywords = {
        const KeywordMatch(
          keyword: 'cong an',
          level: RiskLevel.yellow,
          category: 'AUTH',
        ),
        const KeywordMatch(
          keyword: 'gap',
          level: RiskLevel.yellow,
          category: 'URGENCY',
        ),
      };
      final result = GThinking.analyze(
        allMatchedKeywords: keywords,
        topTopic: 'test',
      );
      expect(
        result.riskLevel.index,
        greaterThanOrEqualTo(RiskLevel.orange.index),
      );
      expect(result.alertEnabled, isTrue);
    });

    test('tier1 only with low context score produces yellow', () {
      final keywords = {
        const KeywordMatch(
          keyword: 'ngan hang',
          level: RiskLevel.yellow,
          category: 'MONEY',
        ),
      };
      final result = GThinking.analyze(
        allMatchedKeywords: keywords,
        topTopic: 'test',
        contextScore: 0.1,
      );
      expect(result.riskLevel, RiskLevel.yellow);
    });

    test('tier1 only with high context score produces orange', () {
      final keywords = {
        const KeywordMatch(
          keyword: 'ngan hang',
          level: RiskLevel.yellow,
          category: 'MONEY',
        ),
      };
      final result = GThinking.analyze(
        allMatchedKeywords: keywords,
        topTopic: 'test',
        contextScore: 0.5,
      );
      expect(result.riskLevel, RiskLevel.orange);
    });

    test('no keywords and no matches returns green', () {
      final result = GThinking.analyze(allMatchedKeywords: {}, topTopic: null);
      expect(result.riskLevel, RiskLevel.green);
      expect(result.alertEnabled, isFalse);
      expect(result.reason, contains('Không phát hiện'));
    });

    test('pattern match escalates risk level', () {
      final keywords = {
        const KeywordMatch(
          keyword: 'cong an',
          level: RiskLevel.yellow,
          category: 'AUTH',
        ),
      };
      final result = GThinking.analyze(
        allMatchedKeywords: keywords,
        topTopic: 'test',
        matchedPatterns: [
          const MatchedPattern(
            patternId: 'transfer_now',
            matchedElements: ['chuyen', 'tien'],
            score: 0.8,
          ),
        ],
      );
      expect(result.riskLevel, RiskLevel.red);
    });

    test('scenario match with high score escalates risk', () {
      final keywords = {
        const KeywordMatch(
          keyword: 'cong an',
          level: RiskLevel.yellow,
          category: 'AUTH',
        ),
      };
      final result = GThinking.analyze(
        allMatchedKeywords: keywords,
        topTopic: 'test',
        scenarioMatch: const ScenarioMatch(
          scenarioId: 1,
          situationName: 'Gia danh cong an',
          similarityScore: 0.9,
          level: 3,
        ),
        config: const ScoringConfig(scenarioAlertThreshold: 0.6),
      );
      expect(result.riskLevel.index, greaterThanOrEqualTo(RiskLevel.red.index));
    });

    test('charity scenario with tier1 still escalates due to safety net', () {
      // When tier1 is present + good scenario match with level >= 3,
      // the safety net overrides the charity cap to RED.
      final result = GThinking.analyze(
        allMatchedKeywords: {
          const KeywordMatch(
            keyword: 'cong an',
            level: RiskLevel.yellow,
            category: 'AUTH',
          ),
        },
        topTopic: 'test',
        scenarioMatch: const ScenarioMatch(
          scenarioId: 1,
          situationName: 'Quyen gop chu thap do',
          similarityScore: 0.9,
          level: 3,
          group: 'CHARITY_DONATION',
        ),
        config: const ScoringConfig(scenarioAlertThreshold: 0.6),
      );
      // Safety net: tier1 + scenario level >= 3 → RED
      expect(result.riskLevel, RiskLevel.red);
      expect(result.alertEnabled, isTrue);
    });

    test('charity scenario without tier1 caps at yellow', () {
      // Without any tier1 keywords, charity should cap at yellow
      final result = GThinking.analyze(
        allMatchedKeywords: {},
        topTopic: null,
        scenarioMatch: const ScenarioMatch(
          scenarioId: 1,
          situationName: 'Quyen gop chu thap do',
          similarityScore: 0.9,
          level: 3,
          group: 'CHARITY_DONATION',
        ),
        config: const ScoringConfig(scenarioAlertThreshold: 0.6),
      );
      expect(result.riskLevel, RiskLevel.yellow);
      expect(result.reason, contains('từ thiện'));
    });

    test('risk score calculation reflects keyword/topic/pattern weights', () {
      final result = GThinking.analyze(
        allMatchedKeywords: {
          const KeywordMatch(
            keyword: 'ma otp',
            level: RiskLevel.red,
            category: 'PII',
          ),
        },
        topTopic: 'test',
        matchedPatterns: [
          const MatchedPattern(
            patternId: 'p1',
            matchedElements: ['test'],
            score: 0.5,
          ),
        ],
        contextScore: 0.3,
      );
      expect(result.riskScore, isNotNull);
      expect(result.riskScore!.finalScore, greaterThan(0));
      expect(result.riskScore!.keywordScore, 1.0); // red -> 1.0
      expect(result.riskScore!.topicScore, 1.0); // topTopic not null -> 1.0
    });
  });
}
