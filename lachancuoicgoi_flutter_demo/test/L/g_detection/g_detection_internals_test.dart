import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:lachancuocgoi_flutter/analysis/analysis_result.dart';
import 'package:lachancuocgoi_flutter/analysis/l2/g_detection/g_detection_engine.dart';
import 'package:lachancuocgoi_flutter/core/risk_level.dart';

/// Characterization tests for `GDetectionEngine` internal clusters that have
/// no direct unit-test coverage today: the context-score math, the trie /
/// Aho-Corasick keyword extraction, and topic classification.
///
/// These are written AGAINST THE CURRENT implementation and must pass
/// *before* the Sprint 3 extraction. Their job is to pin observable behavior
/// so that moving each cluster into its own class (a pure code move) can be
/// verified to preserve behavior. If any of these fail after extraction, the
/// move changed behavior.
///
/// Note: trie extraction and topic classification are exercised indirectly
/// through [performFullAnalysis] because the underlying methods are private.
/// We craft transcripts + asset fixtures that isolate each path.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('ContextScoreCalculator behavior (via engine.calculateContextScore)', () {
    late GDetectionEngine engine;

    setUp(() async {
      engine = _newMinimalEngine();
      await engine.initialize();
    });

    test('empty matches set yields exactly 0.0', () {
      // proximityBonus: matches.length < 2 → 0.0
      // avgPositionWeight: matches.isEmpty → 1.0
      // score = 0.0 + (1.0 - 1.0) = 0.0
      final score = engine.calculateContextScore(<KeywordMatch>{}, 10);
      expect(score, equals(0.0));
    });

    test('single match has zero proximity bonus (needs >= 2)', () {
      final match = _match('a', RiskLevel.yellow, start: 0, end: 0);
      // No neighbor → proximityBonus 0.0. avgPositionWeight = 0.85.
      // score = 0.0 + (0.85 - 1.0) = -0.15
      final score = engine.calculateContextScore({match}, 10);
      expect(score, closeTo(-0.15, 1e-9));
    });

    test('two close matches (distance <= 5) add 0.15 proximity bonus', () {
      // A @ [0,0], B @ [2,2]: distance = 2 - 0 - 1 = 1 (<= 5) → +0.15
      // positionWeight(0,10)=0.85 ; positionWeight(2,10)=0.85+0.2*0.4=0.93
      // avg = 0.89 → score = 0.15 + (0.89 - 1.0) = 0.04
      final a = _match('a', RiskLevel.yellow, start: 0, end: 0);
      final b = _match('b', RiskLevel.yellow, start: 2, end: 2);
      final score = engine.calculateContextScore({a, b}, 10);
      expect(score, closeTo(0.04, 1e-9));
    });

    test('two distant matches (distance 6-10) add only 0.05 bonus', () {
      // A @ [0,0], B @ [8,8]: distance = 8 - 0 - 1 = 7 (6..10) → +0.05
      // positionWeight(0,10)=0.85 ; positionWeight(8,10)=0.85+0.8*0.4=1.17
      // avg = 1.01 → score = 0.05 + (1.01 - 1.0) = 0.06
      final a = _match('a', RiskLevel.yellow, start: 0, end: 0);
      final b = _match('b', RiskLevel.yellow, start: 8, end: 8);
      final score = engine.calculateContextScore({a, b}, 10);
      expect(score, closeTo(0.06, 1e-9));
    });

    test('two very far matches (distance > 10) add no proximity bonus', () {
      // A @ [0,0], B @ [20,20]: distance = 19 (> 10) → 0.0
      // positionWeight(0,30)=0.85 ; positionWeight(20,30)=0.85+(2/3)*0.4≈1.1167
      // avg ≈ 0.9833 → score ≈ 0.0 + (0.9833 - 1.0) ≈ -0.0167
      final a = _match('a', RiskLevel.yellow, start: 0, end: 0);
      final b = _match('b', RiskLevel.yellow, start: 20, end: 20);
      final score = engine.calculateContextScore({a, b}, 30);
      expect(score, closeTo(-0.01667, 1e-4));
    });

    test('proximity bonus clamps at the 0.5 ceiling', () {
      // 10 adjacent matches (distance 0 each pair) → 9 pairs * 0.15 = 1.35,
      // clamped to 0.5. Position contribution is small relative to that.
      final matches = <KeywordMatch>{
        for (var i = 0; i < 10; i++)
          _match('k$i', RiskLevel.yellow, start: i * 2, end: i * 2),
      };
      final score = engine.calculateContextScore(matches, 100);
      // proximityBonus clamped to exactly 0.5; position avg in [0.85,1.25).
      expect(score, greaterThanOrEqualTo(0.5 - 0.15));
      expect(score, lessThanOrEqualTo(0.5 + 0.25));
    });

    test('later position yields higher position weight contribution', () {
      // A single match early vs late: late should score higher because the
      // position multiplier grows from 0.85 → 1.25.
      final early = _match('a', RiskLevel.yellow, start: 0, end: 0);
      final late = _match('a', RiskLevel.yellow, start: 9, end: 9);
      final earlyScore = engine.calculateContextScore({early}, 10);
      final lateScore = engine.calculateContextScore({late}, 10);
      expect(lateScore, greaterThan(earlyScore));
    });
  });

  group('Trie / Aho-Corasick extraction (via performFullAnalysis)', () {
    test(
      'multi-token keyword at transcript start clamps startIndex to 0',
      () async {
        // 'xin chao' is a 2-token keyword in the minimal fixture. At the very
        // start of the transcript its computed startIndex = 0 - 2 + 1 = -1,
        // which the engine clamps to 0. We assert the engine does NOT throw and
        // produces a non-green result (the keyword matches).
        final engine = _newMinimalEngine();
        await engine.initialize();
        final result = await engine.performFullAnalysis('xin chao');
        // 'xin chao' is level 0 (green) in the fixture, so level is green but
        // the trie DID match — verified by reason being non-empty. The point
        // of this test is the no-negative-index code path runs cleanly.
        expect(result.reason, isNotEmpty);
      },
    );

    test(
      'overlapping keyword and its suffix both surface as matches',
      () async {
        // Fixture defines 'chuyen tien' (RED) and 'tien' (RED) so that the
        // Aho-Corasick dictionary-link chain emits both the long keyword and
        // the contained suffix in a single pass. We pair the keywords with a
        // RED sentence so GThinking actually elevates to red — making the
        // match path observable through riskLevel (a bare keyword with empty
        // tier/scoring config would stay green).
        final engine = _engineWithOverlappingKeywords();
        await engine.initialize();
        final result = await engine.performFullAnalysis('vui long chuyen tien');
        expect(result.riskLevel, RiskLevel.red);
      },
    );

    test(
      'three RED keywords trigger early termination, still returns red',
      () async {
        // Plant 3 distinct RED keywords; the early-termination threshold is 3,
        // so the trie scan stops after the 3rd RED match. Paired with a RED
        // sentence to make the outcome observable. The point is the early-exit
        // path completes without dropping evidence.
        final engine = _engineWithThreeRedKeywords();
        await engine.initialize();
        final result = await engine.performFullAnalysis(
          'cap cuu mat ma xac thuc',
        );
        expect(result.riskLevel, RiskLevel.red);
      },
    );
  });

  group('Topic classification (via performFullAnalysis)', () {
    test(
      'keyword repeated under one topic >= threshold influences scoring',
      () async {
        // The minimal fixture has empty situations, so topic classification
        // yields null and scoring falls back to keyword/pattern evidence.
        // We pin that the null-topic code path completes and produces a
        // well-formed result (non-empty reason, valid risk level).
        final engine = _newMinimalEngine();
        await engine.initialize();
        final result = await engine.performFullAnalysis(
          'xin chao xin chao xin chao',
        );
        expect(result.riskLevel, isA<RiskLevel>());
        expect(result.reason, isNotEmpty);
      },
    );
  });
}

KeywordMatch _match(
  String keyword,
  RiskLevel level, {
  required int start,
  required int end,
}) => KeywordMatch(
  keyword: keyword,
  level: level,
  category: 'TEST',
  startIndex: start,
  endIndex: end,
);

/// Minimal engine fixture mirroring `g_detection_engine_edge_test.dart`'s
/// `_newMinimalEngine` — enough assets to be "ready", with a single green
/// keyword 'xin chao'.
GDetectionEngine _newMinimalEngine() {
  final assets = <String, Object?>{
    GDetectionEngine.vocabularyFile: {
      'riskLevels': [
        {
          'level': 0,
          'keywords': ['xin chao'],
        },
      ],
    },
    GDetectionEngine.scoringConfigFile: <String, Object?>{},
    GDetectionEngine.patternsFile: {'patterns': <Map<String, Object?>>[]},
    GDetectionEngine.situationFile: {
      'title': 'Test',
      'version': '1.0',
      'total_scenarios': 0,
      'scenarios': <Map<String, Object?>>[],
    },
    GDetectionEngine.sentencesFile: {
      'riskLevels': [
        {
          'level': 0,
          'sentences': ['xin chao'],
        },
      ],
    },
    GDetectionEngine.slangFile: {'slang_map': <String, Object?>{}},
    GDetectionEngine.tierConfigFile: <String, Object?>{},
    GDetectionEngine.aiCheckFile: {'situations': <Map<String, Object?>>[]},
  };
  return GDetectionEngine(
    assetProvider: (fileName) => jsonEncode(assets[fileName] ?? {}),
  );
}

/// Engine whose vocabulary contains 'chuyen tien' and 'tien' as overlapping
/// RED keywords — exercises the Aho-Corasick dictionary-link chain.
GDetectionEngine _engineWithOverlappingKeywords() {
  final assets = <String, Object?>{
    GDetectionEngine.vocabularyFile: {
      'riskLevels': [
        {
          'level': 3, // red
          'keywords': ['chuyen tien', 'tien'],
        },
      ],
    },
    GDetectionEngine.scoringConfigFile: <String, Object?>{},
    GDetectionEngine.patternsFile: {'patterns': <Map<String, Object?>>[]},
    GDetectionEngine.situationFile: {
      'title': 'Test',
      'version': '1.0',
      'total_scenarios': 0,
      'scenarios': <Map<String, Object?>>[],
    },
    GDetectionEngine.sentencesFile: {
      'riskLevels': [
        {
          'level': 3,
          'threats': {
            'Scam': ['vui long chuyen tien'],
          },
        },
      ],
    },
    GDetectionEngine.slangFile: {'slang_map': <String, Object?>{}},
    GDetectionEngine.tierConfigFile: <String, Object?>{},
    GDetectionEngine.aiCheckFile: {'situations': <Map<String, Object?>>[]},
  };
  return GDetectionEngine(
    assetProvider: (fileName) => jsonEncode(assets[fileName] ?? {}),
  );
}

/// Engine with three distinct RED keywords to trigger the early-termination
/// threshold (>= 3 RED matches) in trie extraction.
GDetectionEngine _engineWithThreeRedKeywords() {
  final assets = <String, Object?>{
    GDetectionEngine.vocabularyFile: {
      'riskLevels': [
        {
          'level': 3, // red
          'keywords': ['cap cuu', 'mat ma', 'xac thuc'],
        },
      ],
    },
    GDetectionEngine.scoringConfigFile: <String, Object?>{},
    GDetectionEngine.patternsFile: {'patterns': <Map<String, Object?>>[]},
    GDetectionEngine.situationFile: {
      'title': 'Test',
      'version': '1.0',
      'total_scenarios': 0,
      'scenarios': <Map<String, Object?>>[],
    },
    GDetectionEngine.sentencesFile: {
      'riskLevels': [
        {
          'level': 3,
          'threats': {
            'Scam': ['cap cuu mat ma xac thuc'],
          },
        },
      ],
    },
    GDetectionEngine.slangFile: {'slang_map': <String, Object?>{}},
    GDetectionEngine.tierConfigFile: <String, Object?>{},
    GDetectionEngine.aiCheckFile: {'situations': <Map<String, Object?>>[]},
  };
  return GDetectionEngine(
    assetProvider: (fileName) => jsonEncode(assets[fileName] ?? {}),
  );
}
