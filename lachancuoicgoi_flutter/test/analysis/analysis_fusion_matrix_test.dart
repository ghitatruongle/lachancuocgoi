import 'package:flutter_test/flutter_test.dart';
import 'package:lachancuocgoi_flutter/analysis/analysis_fusion.dart';
import 'package:lachancuocgoi_flutter/analysis/analysis_level.dart';
import 'package:lachancuocgoi_flutter/analysis/analysis_result.dart';
import 'package:lachancuocgoi_flutter/core/risk_level.dart';

AnalysisResult _r(
  RiskLevel level, {
  AnalysisLevel analysisLevel = AnalysisLevel.l1,
  double confidence = 0.5,
  bool isError = false,
  bool isFallback = false,
  String? reason,
}) {
  return AnalysisResult(
    overallRiskLevel: level,
    matches: const <KeywordMatch>[],
    analysisLevel: analysisLevel,
    alertEnabled: level.shouldAlert,
    confidence: confidence,
    isError: isError,
    isFallback: isFallback,
    reason: reason ?? level.name,
  );
}

void main() {
  group('AnalysisFusion matrix', () {
    test('all green → green', () {
      final fused = AnalysisFusion.fuse(
        _r(RiskLevel.green, analysisLevel: AnalysisLevel.l1),
        _r(RiskLevel.green, analysisLevel: AnalysisLevel.l2),
        _r(RiskLevel.green, analysisLevel: AnalysisLevel.l3),
      );
      expect(fused.overallRiskLevel, RiskLevel.green);
      expect(fused.alertEnabled, isFalse);
    });

    test('L1 red alone always wins', () {
      final fused = AnalysisFusion.fuse(
        _r(RiskLevel.red, analysisLevel: AnalysisLevel.l1),
        _r(RiskLevel.green, analysisLevel: AnalysisLevel.l2),
        _r(RiskLevel.green, analysisLevel: AnalysisLevel.l3),
      );
      expect(fused.overallRiskLevel, RiskLevel.red);
      expect(fused.alertEnabled, isTrue);
    });

    test('L1-only orange softens to yellow when L2/L3 green', () {
      final fused = AnalysisFusion.fuse(
        _r(RiskLevel.orange, analysisLevel: AnalysisLevel.l1),
        _r(RiskLevel.green, analysisLevel: AnalysisLevel.l2),
        _r(RiskLevel.green, analysisLevel: AnalysisLevel.l3),
      );
      expect(fused.overallRiskLevel, RiskLevel.yellow);
      expect(fused.alertEnabled, isFalse);
    });

    test('L2 orange alone alerts', () {
      final fused = AnalysisFusion.fuse(
        _r(RiskLevel.green, analysisLevel: AnalysisLevel.l1),
        _r(RiskLevel.orange, analysisLevel: AnalysisLevel.l2, confidence: 0.6),
        _r(RiskLevel.green, analysisLevel: AnalysisLevel.l3),
      );
      expect(fused.overallRiskLevel, RiskLevel.orange);
      expect(fused.alertEnabled, isTrue);
    });

    test('L3 orange high confidence alone drives orange', () {
      final fused = AnalysisFusion.fuse(
        _r(RiskLevel.green, analysisLevel: AnalysisLevel.l1),
        _r(RiskLevel.green, analysisLevel: AnalysisLevel.l2),
        _r(RiskLevel.orange, analysisLevel: AnalysisLevel.l3, confidence: 0.9),
      );
      expect(fused.overallRiskLevel, RiskLevel.orange);
    });

    test('two-tier orange agreement keeps highest', () {
      final fused = AnalysisFusion.fuse(
        _r(RiskLevel.orange, analysisLevel: AnalysisLevel.l1),
        _r(RiskLevel.orange, analysisLevel: AnalysisLevel.l2),
        _r(RiskLevel.green, analysisLevel: AnalysisLevel.l3),
      );
      expect(
        fused.overallRiskLevel.index,
        greaterThanOrEqualTo(RiskLevel.orange.index),
      );
    });

    test('error and fallback flags propagate', () {
      final fused = AnalysisFusion.fuse(
        _r(RiskLevel.green, isError: true),
        _r(RiskLevel.green, isFallback: true),
        _r(RiskLevel.green),
      );
      expect(fused.isError, isTrue);
      expect(fused.isFallback, isTrue);
    });
  });
}
