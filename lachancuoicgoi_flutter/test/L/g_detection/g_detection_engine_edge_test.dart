import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:lachancuocgoi_flutter/analysis/analysis_result.dart';
import 'package:lachancuocgoi_flutter/analysis/l2/g_detection/g_detection_engine.dart';
import 'package:lachancuocgoi_flutter/core/risk_level.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('GDetectionEngine - edge cases and error paths', () {
    test('initialize with empty JSON object does not crash', () async {
      final engine = GDetectionEngine(assetProvider: (fileName) => '{}');
      await engine.initialize();

      expect(engine.isReady, isFalse);
    });

    test('initialize with malformed JSON does not crash', () async {
      final engine = GDetectionEngine(
        assetProvider: (fileName) => '{not valid json',
      );
      await engine.initialize();

      expect(engine.isReady, isFalse);
    });

    test('initialize with missing required fields uses defaults', () async {
      final engine = GDetectionEngine(
        assetProvider: (fileName) => jsonEncode(<String, Object?>{
          'riskLevels': [],
          'slang_map': <String, Object?>{},
          'patterns': <Object?>[],
          'riskLevelThresholds': {},
          'weights': {},
        }),
      );
      await engine.initialize();

      expect(engine.isReady, isFalse);
    });

    test('initialize with null/missing lists uses empty defaults', () async {
      final engine = GDetectionEngine(
        assetProvider: (fileName) =>
            jsonEncode(<String, Object?>{'someUnknownKey': 'someValue'}),
      );
      await engine.initialize();

      expect(engine.isReady, isFalse);
    });

    test('performFullAnalysis on empty text returns green', () async {
      final engine = _newMinimalEngine();
      await engine.initialize();

      final result = await engine.performFullAnalysis('');
      expect(result.riskLevel, RiskLevel.green);
      expect(result.alertEnabled, isFalse);
    });

    test('performFullAnalysis on whitespace-only text returns green', () async {
      final engine = _newMinimalEngine();
      await engine.initialize();

      final result = await engine.performFullAnalysis('   \n\t  ');
      expect(result.riskLevel, RiskLevel.green);
      expect(result.alertEnabled, isFalse);
    });

    test('performFullAnalysis on very long text does not crash', () async {
      final engine = _newMinimalEngine();
      await engine.initialize();

      final longText = 'xin chao ' * 1200;
      expect(longText.length, greaterThan(10000));

      final result = await engine.performFullAnalysis(longText);
      expect(result.riskLevel, isA<RiskLevel>());
      expect(result.reason, isNotEmpty);
    });

    test(
      'performFullAnalysis with special characters does not crash',
      () async {
        final engine = _newMinimalEngine();
        await engine.initialize();

        final result = await engine.performFullAnalysis(
          '!@#\$%^&*()_+-={}[]|\\:;"<>,.?/~`',
        );
        expect(result.riskLevel, RiskLevel.green);
        expect(result.reason, isNotEmpty);
      },
    );

    test('performFullAnalysis with pure numbers returns green', () async {
      final engine = _newMinimalEngine();
      await engine.initialize();

      final result = await engine.performFullAnalysis('1234567890 9876543210');
      expect(result.riskLevel, RiskLevel.green);
      expect(result.reason, isNotEmpty);
    });

    test(
      'performFullAnalysis with mixed Vietnamese/English handles gracefully',
      () async {
        final engine = _newMinimalEngine();
        await engine.initialize();

        final result = await engine.performFullAnalysis(
          'Hello xin chao, I need ban chuyen tien gap please',
        );
        expect(result.riskLevel, isA<RiskLevel>());
        expect(result.reason, isNotEmpty);
      },
    );

    test('performFullAnalysis with unicode emoji does not crash', () async {
      final engine = _newMinimalEngine();
      await engine.initialize();

      final result = await engine.performFullAnalysis(
        'xin chao \u{1F600} \u{1F4B0} chuyen tien',
      );
      expect(result.riskLevel, isA<RiskLevel>());
      expect(result.reason, isNotEmpty);
    });

    test(
      'initialize returns immediately on second call (idempotent)',
      () async {
        final engine = _newMinimalEngine();
        await engine.initialize();
        expect(engine.isReady, isTrue);

        await engine.initialize();
        expect(engine.isReady, isTrue);
      },
    );

    test('performFullAnalysis when not initialized auto-initializes', () async {
      final engine = _newMinimalEngine();

      expect(engine.isReady, isFalse);

      final result = await engine.performFullAnalysis('xin chao');

      expect(result.riskLevel, isA<RiskLevel>());
      expect(engine.isReady, isTrue);
    });

    test(
      'calculateContextScore with zero totalTokens returns valid score',
      () async {
        final engine = _newMinimalEngine();
        await engine.initialize();

        final score = engine.calculateContextScore(<KeywordMatch>{}, 0);
        expect(score, isA<double>());
        expect(score, greaterThanOrEqualTo(0));
      },
    );

    test(
      'calculateContextScore with empty matches returns valid score',
      () async {
        final engine = _newMinimalEngine();
        await engine.initialize();

        final score = engine.calculateContextScore(<KeywordMatch>{}, 10);
        expect(score, isA<double>());
      },
    );

    test('setAssetProvider resets readiness', () async {
      final engine = _newMinimalEngine();
      await engine.initialize();
      expect(engine.isReady, isTrue);

      engine.setAssetProvider((fileName) => '{}');
      expect(engine.isReady, isFalse);
    });

    test(
      'engine returns green result when not ready after failed init',
      () async {
        final engine = GDetectionEngine(assetProvider: (fileName) => '{}');
        await engine.initialize();
        expect(engine.isReady, isFalse);

        final result = await engine.performFullAnalysis('some text');
        expect(result.riskLevel, RiskLevel.green);
        expect(result.reason, contains('khởi tạo'));
      },
    );
  });
}

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
    GDetectionEngine.patternsFile: {'patterns': <Object?>[]},
    GDetectionEngine.situationFile: {
      'title': 'Test',
      'version': '1.0',
      'total_scenarios': 0,
      'scenarios': <Object?>[],
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
    GDetectionEngine.aiCheckFile: {'situations': <Object?>[]},
  };

  return GDetectionEngine(
    assetProvider: (fileName) => jsonEncode(assets[fileName] ?? {}),
  );
}
