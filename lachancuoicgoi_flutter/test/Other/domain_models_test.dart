import 'package:flutter_test/flutter_test.dart';
import 'package:lachancuocgoi_flutter/analysis/analysis_level.dart';
import 'package:lachancuocgoi_flutter/analysis/analysis_mode.dart';
import 'package:lachancuocgoi_flutter/analysis/analysis_result.dart';
import 'package:lachancuocgoi_flutter/core/risk_level.dart';

void main() {
  group('AnalysisLevel — fromId', () {
    test('parses standard ids', () {
      expect(AnalysisLevel.fromId('L1'), AnalysisLevel.l1);
      expect(AnalysisLevel.fromId('L2'), AnalysisLevel.l2);
      expect(AnalysisLevel.fromId('L2-AI'), AnalysisLevel.l2Ai);
      expect(AnalysisLevel.fromId('L2-FUSED'), AnalysisLevel.l2Fused);
      expect(AnalysisLevel.fromId('L3'), AnalysisLevel.l3);
    });

    test('parses case-insensitive ids', () {
      expect(AnalysisLevel.fromId('l1'), AnalysisLevel.l1);
      expect(AnalysisLevel.fromId('l2'), AnalysisLevel.l2);
      expect(AnalysisLevel.fromId('l2ai'), AnalysisLevel.l2Ai);
      expect(AnalysisLevel.fromId('l2fused'), AnalysisLevel.l2Fused);
      expect(AnalysisLevel.fromId('l3'), AnalysisLevel.l3);
    });

    test('handles null and unknown values', () {
      expect(AnalysisLevel.fromId(null), AnalysisLevel.l1);
      expect(AnalysisLevel.fromId(''), AnalysisLevel.l1);
      expect(AnalysisLevel.fromId('UNKNOWN'), AnalysisLevel.l1);
    });

    test('handles whitespace', () {
      expect(AnalysisLevel.fromId('  L3  '), AnalysisLevel.l3);
    });
  });

  group('AnalysisLevel — displayName', () {
    test('has correct Vietnamese display names', () {
      expect(AnalysisLevel.l1.displayName, 'Cấp 1');
      expect(AnalysisLevel.l2.displayName, 'Cấp 2');
      expect(AnalysisLevel.l2Ai.displayName, 'Cấp 2 AI');
      expect(AnalysisLevel.l2Fused.displayName, 'Cấp 2 hợp nhất');
      expect(AnalysisLevel.l3.displayName, 'Cấp 3 Gemini');
    });
  });

  group('AnalysisMode — storageName', () {
    test('returns correct storage names', () {
      expect(AnalysisMode.normal.storageName, 'NORMAL');
      expect(AnalysisMode.gDetection.storageName, 'GDetection');
      expect(AnalysisMode.geminiApi.storageName, 'GEMINI_API');
    });
  });

  group('AnalysisMode — title and description', () {
    test('has correct Vietnamese titles', () {
      expect(AnalysisMode.normal.title, 'Cấp 1: Cơ bản');
      expect(AnalysisMode.gDetection.title, 'Cấp 2: Nâng cao');
      expect(AnalysisMode.geminiApi.title, 'Cấp 3: AI');
    });

    test('has non-empty descriptions', () {
      for (final mode in AnalysisMode.values) {
        expect(mode.description.isNotEmpty, isTrue);
      }
    });
  });

  group('AnalysisModeX — fromName', () {
    test('parses all storage names', () {
      expect(AnalysisModeX.fromName('NORMAL'), AnalysisMode.normal);
      expect(AnalysisModeX.fromName('GDetection'), AnalysisMode.gDetection);
      expect(AnalysisModeX.fromName('GEMINI_API'), AnalysisMode.geminiApi);
    });

    test('parses dart enum names', () {
      expect(AnalysisModeX.fromName('normal'), AnalysisMode.normal);
      expect(AnalysisModeX.fromName('gDetection'), AnalysisMode.gDetection);
      expect(AnalysisModeX.fromName('geminiApi'), AnalysisMode.geminiApi);
    });

    test('returns fallback for null and unknown values', () {
      expect(AnalysisModeX.fromName(null), AnalysisMode.gDetection);
      expect(AnalysisModeX.fromName(''), AnalysisMode.gDetection);
      expect(AnalysisModeX.fromName('UNKNOWN'), AnalysisMode.gDetection);
    });

    test('uses custom fallback', () {
      expect(
        AnalysisModeX.fromName(null, fallback: AnalysisMode.normal),
        AnalysisMode.normal,
      );
    });

    test('handles whitespace', () {
      expect(AnalysisModeX.fromName('  NORMAL  '), AnalysisMode.normal);
    });
  });

  group('RiskLevel — fromInt', () {
    test('maps Kotlin ordinals correctly', () {
      expect(RiskLevel.fromInt(0), RiskLevel.green);
      expect(RiskLevel.fromInt(1), RiskLevel.yellow);
      expect(RiskLevel.fromInt(2), RiskLevel.orange);
      expect(RiskLevel.fromInt(3), RiskLevel.red);
    });

    test('defaults negative values to green', () {
      expect(RiskLevel.fromInt(-1), RiskLevel.green);
    });

    test('defaults out-of-range values to green', () {
      expect(RiskLevel.fromInt(99), RiskLevel.green);
    });
  });

  group('RiskLevel — fromString', () {
    test('parses English names', () {
      expect(RiskLevel.fromString('RED'), RiskLevel.red);
      expect(RiskLevel.fromString('ORANGE'), RiskLevel.orange);
      expect(RiskLevel.fromString('YELLOW'), RiskLevel.yellow);
      expect(RiskLevel.fromString('GREEN'), RiskLevel.green);
    });

    test('parses Vietnamese names with diacritics', () {
      expect(RiskLevel.fromString('Nguy hiểm'), RiskLevel.red);
      expect(RiskLevel.fromString('Có nguy cơ'), RiskLevel.orange);
      expect(RiskLevel.fromString('Chú ý'), RiskLevel.yellow);
      expect(RiskLevel.fromString('An toàn'), RiskLevel.green);
    });

    test('parses Vietnamese names without diacritics', () {
      expect(RiskLevel.fromString('NGUY HIEM'), RiskLevel.red);
      expect(RiskLevel.fromString('CO NGUY CO'), RiskLevel.orange);
      expect(RiskLevel.fromString('CHU Y'), RiskLevel.yellow);
      expect(RiskLevel.fromString('AN TOAN'), RiskLevel.green);
    });

    test('handles null, empty and unknown values', () {
      // null/empty = no data yet → green (safe default)
      expect(RiskLevel.fromString(null), RiskLevel.green);
      expect(RiskLevel.fromString(''), RiskLevel.green);
      // Unknown non-empty string = corrupted data → orange (conservative)
      expect(RiskLevel.fromString('UNKNOWN'), RiskLevel.orange);
      expect(RiskLevel.fromString('GARBAGE'), RiskLevel.orange);
    });

    test('case insensitive', () {
      expect(RiskLevel.fromString('red'), RiskLevel.red);
      expect(RiskLevel.fromString('Red'), RiskLevel.red);
    });
  });

  group('RiskLevel — properties', () {
    test('storageName returns uppercase', () {
      expect(RiskLevel.green.storageName, 'GREEN');
      expect(RiskLevel.yellow.storageName, 'YELLOW');
      expect(RiskLevel.orange.storageName, 'ORANGE');
      expect(RiskLevel.red.storageName, 'RED');
    });

    test('shouldAlert thresholds correct', () {
      expect(RiskLevel.green.shouldAlert, isFalse);
      expect(RiskLevel.yellow.shouldAlert, isFalse);
      expect(RiskLevel.orange.shouldAlert, isTrue);
      expect(RiskLevel.red.shouldAlert, isTrue);
    });

    test('level returns correct index', () {
      expect(RiskLevel.green.level, 0);
      expect(RiskLevel.yellow.level, 1);
      expect(RiskLevel.orange.level, 2);
      expect(RiskLevel.red.level, 3);
    });
  });

  group('RiskLevel — deescalate', () {
    test('deescalates one step down', () {
      expect(RiskLevel.red.deescalate(), RiskLevel.orange);
      expect(RiskLevel.orange.deescalate(), RiskLevel.yellow);
      expect(RiskLevel.yellow.deescalate(), RiskLevel.green);
      expect(RiskLevel.green.deescalate(), RiskLevel.green);
    });
  });

  group('AnalysisResult — JSON serialization', () {
    test('round-trips through toJson and fromJson', () {
      const original = AnalysisResult(
        overallRiskLevel: RiskLevel.red,
        matches: [
          KeywordMatch(
            keyword: 'otp',
            level: RiskLevel.red,
            category: 'PII',
            startIndex: 5,
            endIndex: 8,
            isFuzzy: true,
          ),
        ],
        reason: 'Phát hiện yêu cầu OTP',
        analysisLevel: AnalysisLevel.l2Ai,
        alertEnabled: true,
        confidence: 0.95,
        modelName: 'gemini-2.5-flash-lite',
        isError: false,
      );

      final json = original.toJson();
      final restored = AnalysisResult.fromJson(json);

      expect(restored.overallRiskLevel, RiskLevel.red);
      expect(restored.matches.single.keyword, 'otp');
      expect(restored.matches.single.level, RiskLevel.red);
      expect(restored.matches.single.category, 'PII');
      expect(restored.matches.single.startIndex, 5);
      expect(restored.matches.single.endIndex, 8);
      expect(restored.matches.single.isFuzzy, isTrue);
      expect(restored.reason, 'Phát hiện yêu cầu OTP');
      expect(restored.analysisLevel, AnalysisLevel.l2Ai);
      expect(restored.alertEnabled, isTrue);
      expect(restored.confidence, 0.95);
      expect(restored.modelName, 'gemini-2.5-flash-lite');
      expect(restored.isError, isFalse);
    });

    test('fromJson handles missing fields', () {
      final result = AnalysisResult.fromJson(<String, Object?>{});

      expect(result.overallRiskLevel, RiskLevel.green);
      expect(result.matches, isEmpty);
      expect(result.reason, isNull);
      expect(result.analysisLevel, AnalysisLevel.l1);
      expect(result.alertEnabled, isFalse);
      expect(result.confidence, -1);
      expect(result.modelName, isNull);
      expect(result.isError, isFalse);
    });

    test('fromJson handles invalid matches gracefully', () {
      final result = AnalysisResult.fromJson(<String, Object?>{
        'matches': 'not a list',
      });

      expect(result.matches, isEmpty);
    });
  });

  group('AnalysisResult — copyWith', () {
    test('produces modified copy correctly', () {
      const original = AnalysisResult(
        overallRiskLevel: RiskLevel.green,
        matches: <KeywordMatch>[],
      );

      final modified = original.copyWith(
        overallRiskLevel: RiskLevel.red,
        alertEnabled: true,
        reason: 'Updated reason',
        isError: true,
      );

      expect(modified.overallRiskLevel, RiskLevel.red);
      expect(modified.alertEnabled, isTrue);
      expect(modified.reason, 'Updated reason');
      expect(modified.isError, isTrue);
      // Unchanged fields
      expect(modified.matches, isEmpty);
      expect(modified.confidence, -1);
    });
  });

  group('KeywordMatch — copyWith', () {
    test('produces modified copy correctly', () {
      const original = KeywordMatch(
        keyword: 'test',
        level: RiskLevel.green,
        category: 'Safe',
      );

      final modified = original.copyWith(
        keyword: 'modified',
        level: RiskLevel.red,
        isFuzzy: true,
      );

      expect(modified.keyword, 'modified');
      expect(modified.level, RiskLevel.red);
      expect(modified.isFuzzy, isTrue);
      expect(modified.category, 'Safe'); // unchanged
    });
  });

  group('KeywordMatch — equality', () {
    test('equal matches are equal', () {
      const a = KeywordMatch(
        keyword: 'otp',
        level: RiskLevel.red,
        category: 'PII',
        startIndex: 0,
        endIndex: 3,
      );
      const b = KeywordMatch(
        keyword: 'otp',
        level: RiskLevel.red,
        category: 'PII',
        startIndex: 0,
        endIndex: 3,
      );

      expect(a, equals(b));
      expect(a.hashCode, equals(b.hashCode));
    });

    test('different matches are not equal', () {
      const a = KeywordMatch(
        keyword: 'otp',
        level: RiskLevel.red,
        category: 'PII',
      );
      const b = KeywordMatch(
        keyword: 'chuyển tiền',
        level: RiskLevel.orange,
        category: 'Finance',
      );

      expect(a, isNot(equals(b)));
    });
  });
}
