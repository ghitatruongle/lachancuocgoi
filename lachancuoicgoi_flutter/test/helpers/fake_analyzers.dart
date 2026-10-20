import 'package:lachancuocgoi_flutter/analysis/analysis_coordinator.dart';
import 'package:lachancuocgoi_flutter/analysis/analysis_level.dart';
import 'package:lachancuocgoi_flutter/analysis/analysis_mode.dart';
import 'package:lachancuocgoi_flutter/analysis/analysis_result.dart';
import 'package:lachancuocgoi_flutter/analysis/analyzer.dart';
import 'package:lachancuocgoi_flutter/analysis/health_check.dart';

import 'package:lachancuocgoi_flutter/core/risk_level.dart';

class FakeAnalysisCoordinator extends AnalysisCoordinator {
  FakeAnalysisCoordinator({AnalysisResult? resultToReturn, this.errorToThrow})
    : _resultToReturn =
          resultToReturn ??
          const AnalysisResult(
            overallRiskLevel: RiskLevel.green,
            matches: <KeywordMatch>[],
            analysisLevel: AnalysisLevel.l1,
          );

  final AnalysisResult _resultToReturn;
  final Object? errorToThrow;
  int analyzeCallCount = 0;
  int analyzeIncrementalCallCount = 0;
  String? lastAnalyzedText;
  AnalysisMode? lastMode;

  @override
  Future<AnalysisResult> analyze(String text, AnalysisMode mode) async {
    analyzeCallCount++;
    lastAnalyzedText = text;
    lastMode = mode;
    if (errorToThrow != null) throw errorToThrow!;
    return _resultToReturn;
  }

  @override
  Future<AnalysisResult> analyzeIncremental(
    String fullText,
    AnalysisMode mode, {
    double? speechRate,
  }) async {
    analyzeIncrementalCallCount++;
    lastAnalyzedText = fullText;
    lastMode = mode;
    if (errorToThrow != null) throw errorToThrow!;
    return _resultToReturn;
  }
}

class FakeAnalyzer implements Analyzer {
  FakeAnalyzer({this.ready = true});

  final bool ready;

  int _processedTextLength = 0;
  AnalysisResult _lastResult = const AnalysisResult(
    overallRiskLevel: RiskLevel.green,
    matches: <KeywordMatch>[],
    analysisLevel: AnalysisLevel.l1,
  );

  @override
  AnalysisLevel get level => AnalysisLevel.l1;

  @override
  Future<void> initialize() async {}

  @override
  bool get isReady => ready;

  @override
  int get processedTextLength => _processedTextLength;

  @override
  AnalysisResult get lastResult => _lastResult;

  @override
  void resetSession() {
    _processedTextLength = 0;
    _lastResult = const AnalysisResult(
      overallRiskLevel: RiskLevel.green,
      matches: <KeywordMatch>[],
      analysisLevel: AnalysisLevel.l1,
    );
  }

  @override
  void syncProcessedTextLength(int length) {
    _processedTextLength = length.clamp(0, length);
  }

  @override
  HealthReport healthCheck() {
    return HealthReport(
      status: ready ? HealthStatus.healthy : HealthStatus.down,
      component: 'FakeAnalyzer',
      message: ready ? 'OK' : 'Not ready',
    );
  }

  @override
  void dispose() {}
}

class FakeNoOpAnalyzer extends FakeAnalyzer {
  FakeNoOpAnalyzer() : super(ready: true);

  static const AnalysisResult _green = AnalysisResult(
    overallRiskLevel: RiskLevel.green,
    matches: <KeywordMatch>[],
    reason: 'No-op analyzer',
    analysisLevel: AnalysisLevel.l1,
    alertEnabled: false,
  );

  @override
  AnalysisResult get lastResult => _green;

  @override
  void resetSession() {}
}
