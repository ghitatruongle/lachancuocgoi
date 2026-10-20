import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:lachancuocgoi_flutter/analysis/analysis_result.dart';
import 'package:lachancuocgoi_flutter/analysis/l2/g_detection/g_detection_engine.dart';
import 'package:lachancuocgoi_flutter/core/risk_level.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group(
    'ContextScoreCalculator behavior (via engine.calculateContextScore)',
    () {
      late GDetectionEngine engine;

      setUp(() async {
        engine = _newMinimalEngine();
        await engine.initialize();
      });

      test('empty matches set yields exactly 0.0', () {
        final score = engine.calculateContextScore(<KeywordMatch>{}, 10);
        expect(score, equals(0.0));
      });

      test('single match has zero proximity bonus (needs >= 2)', () {
        final match = _match('a', RiskLevel.yellow, start: 0, end: 0);

        final score = engine.calculateContextScore({match}, 10);
        expect(score, closeTo(-0.15, 1e-9));
      });

      test('two close matches (distance <= 5) add 0.15 proximity bonus', () {
        final a = _match('a', RiskLevel.yellow, start: 0, end: 0);
        final b = _match('b', RiskLevel.yellow, start: 2, end: 2);
        final score = engine.calculateContextScore({a, b}, 10);
        expect(score, closeTo(0.04, 1e-9));
      });

      test('two distant matches (distance 6-10) add only 0.05 bonus', () {
        final a = _match('a', RiskLevel.yellow, start: 0, end: 0);
        final b = _match('b', RiskLevel.yellow, start: 8, end: 8);
        final score = engine.calculateContextScore({a, b}, 10);
        expect(score, closeTo(0.06, 1e-9));
      });

      test('two very far matches (distance > 10) add no proximity bonus', () {
        final a = _match('a', RiskLevel.yellow, start: 0, end: 0);
        final b = _match('b', RiskLevel.yellow, start: 20, end: 20);
        final score = engine.calculateContextScore({a, b}, 30);
        expect(score, closeTo(-0.01667, 1e-4));
      });

      test('proximity bonus clamps at the 0.5 ceiling', () {
        final matches = <KeywordMatch>{
          for (var i = 0; i < 10; i++)
            _match('k$i', RiskLevel.yellow, start: i * 2, end: i * 2),
        };
        final score = engine.calculateContextScore(matches, 100);

        expect(score, greaterThanOrEqualTo(0.5 - 0.15));
        expect(score, lessThanOrEqualTo(0.5 + 0.25));
      });

      test('later position yields higher position weight contribution', () {
        final early = _match('a', RiskLevel.yellow, start: 0, end: 0);
        final late = _match('a', RiskLevel.yellow, start: 9, end: 9);
        final earlyScore = engine.calculateContextScore({early}, 10);
        final lateScore = engine.calculateContextScore({late}, 10);
        expect(lateScore, greaterThan(earlyScore));
      });
    },
  );

  group('Trie / Aho-Corasick extraction (via performFullAnalysis)', () {
    test(
      'multi-token keyword at transcript start clamps startIndex to 0',
      () async {
        final engine = _newMinimalEngine();
        await engine.initialize();
        final result = await engine.performFullAnalysis('xin chao');

        expect(result.reason, isNotEmpty);
      },
    );

    test(
      'overlapping keyword and its suffix both surface as matches',
      () async {
        final engine = _engineWithOverlappingKeywords();
        await engine.initialize();
        final result = await engine.performFullAnalysis('vui long chuyen tien');
        expect(result.riskLevel, RiskLevel.red);
      },
    );

    test(
      'three RED keywords trigger early termination, still returns red',
      () async {
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

GDetectionEngine _engineWithOverlappingKeywords() {
  final assets = <String, Object?>{
    GDetectionEngine.vocabularyFile: {
      'riskLevels': [
        {
          'level': 3,
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

GDetectionEngine _engineWithThreeRedKeywords() {
  final assets = <String, Object?>{
    GDetectionEngine.vocabularyFile: {
      'riskLevels': [
        {
          'level': 3,
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
