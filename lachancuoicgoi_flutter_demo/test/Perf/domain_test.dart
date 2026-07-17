import 'package:flutter_test/flutter_test.dart';
import 'package:lachancuocgoi_flutter/analysis/analysis_level.dart';
import 'package:lachancuocgoi_flutter/analysis/analysis_mode.dart';
import 'package:lachancuocgoi_flutter/analysis/analysis_result.dart';
import 'package:lachancuocgoi_flutter/analysis/common/fuzzy_matcher.dart';
import 'package:lachancuocgoi_flutter/analysis/common/text_normalizer.dart';
import 'package:lachancuocgoi_flutter/core/risk_level.dart';

void main() {
  group('RiskLevel parity', () {
    test('keeps Kotlin ordinal mapping', () {
      expect(RiskLevel.fromInt(0), RiskLevel.green);
      expect(RiskLevel.fromInt(1), RiskLevel.yellow);
      expect(RiskLevel.fromInt(2), RiskLevel.orange);
      expect(RiskLevel.fromInt(3), RiskLevel.red);
      expect(RiskLevel.red.deescalate(), RiskLevel.orange);
      expect(RiskLevel.green.deescalate(), RiskLevel.green);
    });

    test('parses storage names and Vietnamese labels', () {
      expect(RiskLevel.fromString('RED'), RiskLevel.red);
      expect(RiskLevel.fromString('Nguy cơ'), RiskLevel.orange);
      expect(RiskLevel.fromString('Chú ý'), RiskLevel.yellow);
      expect(RiskLevel.fromString('An toàn'), RiskLevel.green);
    });
  });

  group('Analysis domain models', () {
    test('keeps AnalysisMode storage names', () {
      expect(AnalysisMode.normal.storageName, 'NORMAL');
      expect(AnalysisMode.gDetection.storageName, 'GDetection');
      expect(AnalysisMode.geminiApi.storageName, 'GEMINI_API');
      expect(AnalysisModeX.fromName('GDetection'), AnalysisMode.gDetection);
    });

    test('serializes AnalysisResult evidence', () {
      const result = AnalysisResult(
        overallRiskLevel: RiskLevel.red,
        matches: [
          KeywordMatch(
            keyword: 'otp',
            level: RiskLevel.red,
            category: 'Sensitive',
            startIndex: 1,
            endIndex: 1,
          ),
        ],
        reason: 'Canh bao',
        analysisLevel: AnalysisLevel.l2,
        alertEnabled: true,
        confidence: 0.9,
      );

      final restored = AnalysisResult.fromJson(result.toJson());
      expect(restored.overallRiskLevel, RiskLevel.red);
      expect(restored.analysisLevel, AnalysisLevel.l2);
      expect(restored.alertEnabled, isTrue);
      expect(restored.matches.single.keyword, 'otp');
      expect(restored.matches.single.startIndex, 1);
    });
  });

  group('TextNormalizer and FuzzyMatcher', () {
    test('normalizes Vietnamese text in remove and space modes', () {
      expect(
        TextNormalizer.normalize('C.ông an yêu cầu mã OTP'),
        'cong an yeu cau ma otp',
      );
      expect(
        TextNormalizer.normalize('C.ông an', noiseMode: NoiseMode.space),
        'c ong an',
      );
    });

    test('applies slang by longest entry first', () {
      TextNormalizer.loadSlangConfig({
        'ck': 'chuyen khoan',
        'stk': 'so tai khoan',
      });

      expect(
        TextNormalizer.normalize('gui ck vao stk'),
        'gui chuyen khoan vao so tai khoan',
      );
      TextNormalizer.loadSlangConfig({});
    });

    test('finds close STT typo within threshold', () {
      expect(
        FuzzyMatcher.findClosest('cong', ['cong', 'ngan'], maxDistance: 1),
        'cong',
      );
      expect(
        FuzzyMatcher.findClosest('otp', ['otq', 'ngan'], maxDistance: 1),
        'otq',
      );
      expect(
        FuzzyMatcher.findClosest('abc', ['nganhang'], maxDistance: 1),
        isNull,
      );
    });
  });
}
