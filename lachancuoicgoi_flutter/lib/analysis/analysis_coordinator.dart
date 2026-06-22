import 'dart:async';
import 'dart:collection';

import '../core/risk_level.dart';
import 'analysis_level.dart';
import 'analysis_mode.dart';
import 'analysis_result.dart';
import 'analyzer.dart';
import 'health_check.dart';
import 'l1/l1_analysis.dart';
import 'l2/l2_analysis.dart';
import 'l3/l3_analysis.dart';

class AnalysisCoordinator {
  AnalysisCoordinator({
    L1Analyzer? l1Analyzer,
    L2Analyzer? l2Analyzer,
    L3Analyzer? l3Analyzer,
  }) : _l1Analyzer = l1Analyzer ?? L1Analyzer(),
       _l2Analyzer = l2Analyzer ?? L2Analyzer(),
       _l3Analyzer = l3Analyzer ?? L3Analyzer();

  static const int _minDeltaDefault = 50;
  static const int _minDeltaOrange = 30;
  static const int _minDeltaRed = 20;

  final L1Analyzer _l1Analyzer;
  final L2Analyzer _l2Analyzer;
  final L3Analyzer _l3Analyzer;

  AnalysisResult? _lastParallelResult;

  Analyzer _analyzerFor(AnalysisMode mode) {
    return switch (mode) {
      AnalysisMode.normal => _l1Analyzer,
      AnalysisMode.gDetection => _l2Analyzer,
      AnalysisMode.geminiApi => _l3Analyzer,
      AnalysisMode.parallel => _l3Analyzer, // Fallback for some properties
    };
  }

  Future<AnalysisResult> analyze(String text, AnalysisMode mode) async {
    return analyzeWithTranscript(text, text, mode);
  }

  Future<AnalysisResult> analyzeWithTranscript(
    String incrementalText,
    String fullText,
    AnalysisMode mode,
  ) async {
    if (mode == AnalysisMode.gDetection && !_l2Analyzer.isReady) {
      await _l2Analyzer.initialize();
      if (!_l2Analyzer.isReady) {
        return const AnalysisResult(
          overallRiskLevel: RiskLevel.green,
          matches: <KeywordMatch>[],
          reason: 'Hệ thống AI (L2) đang khởi tạo...',
          analysisLevel: AnalysisLevel.l2,
        );
      }
    }
    return switch (mode) {
      AnalysisMode.normal => _l1Analyzer.analyzeStream(fullText),
      AnalysisMode.gDetection => Future.value(
        _l2Analyzer.analyze(incrementalText, fullText),
      ),
      AnalysisMode.geminiApi => _analyzeL3WithFallback(
        incrementalText: incrementalText,
        fullText: fullText,
      ),
      AnalysisMode.parallel => _analyzeParallel(
        incrementalText: incrementalText,
        fullText: fullText,
      ),
    };
  }

  Future<AnalysisResult> analyzeIncremental(
    String fullText,
    AnalysisMode mode,
  ) async {
    if (mode == AnalysisMode.parallel) {
      return _analyzeIncrementalParallel(fullText);
    }

    final processedTextLength = getProcessedTextLength(mode);
    final lastResult = getLastResult(mode);

    if (fullText.length <= processedTextLength) {
      return lastResult.overallRiskLevel.index >= RiskLevel.orange.index
          ? lastResult.copyWith(alertEnabled: false)
          : lastResult;
    }

    final deltaLength = fullText.length - processedTextLength;
    final minDelta = _adaptiveMinDelta(lastResult.overallRiskLevel, mode);
    if (deltaLength < minDelta) {
      return lastResult.overallRiskLevel.index >= RiskLevel.orange.index
          ? lastResult.copyWith(alertEnabled: false)
          : lastResult;
    }

    if (mode == AnalysisMode.geminiApi) {
      final result = await analyzeIncrementalL3(fullText);
      return result ?? _defaultResultFor(mode);
    }

    final textToAnalyze = fullText.substring(processedTextLength);
    return analyzeWithTranscript(textToAnalyze, fullText, mode);
  }

  Future<AnalysisResult> _analyzeParallel({
    required String incrementalText,
    required String fullText,
  }) async {
    final l1Future = _l1Analyzer.analyzeStream(fullText);

    if (!_l2Analyzer.isReady) {
      await _l2Analyzer.initialize();
    }
    final l2Future = _l2Analyzer.isReady
        ? Future.value(_l2Analyzer.analyze(incrementalText, fullText))
        : Future.value(_defaultResultFor(AnalysisMode.gDetection));

    final results = await Future.wait([l1Future, l2Future]);
    final l1Result = results[0];
    final l2Result = results[1];

    if (l1Result.overallRiskLevel.index >= RiskLevel.orange.index) {
      return l1Result;
    }
    if (l2Result.overallRiskLevel.index >= RiskLevel.orange.index) {
      return l2Result;
    }

    final l3Future = _analyzeL3WithFallback(
      incrementalText: incrementalText,
      fullText: fullText,
    );
    try {
      final l3Result = await l3Future.timeout(
        const Duration(milliseconds: 800),
      );
      return _fuseResults(l1Result, l2Result, l3Result);
    } on TimeoutException {
      return _fuseResults(
        l1Result,
        l2Result,
        _defaultResultFor(AnalysisMode.geminiApi),
      );
    }
  }

  Future<AnalysisResult> _analyzeIncrementalParallel(String fullText) async {
    final processedLength = _l1Analyzer.processedTextLength;
    final lastResult =
        _lastParallelResult ?? _defaultResultFor(AnalysisMode.parallel);

    if (fullText.length <= processedLength) {
      return lastResult.overallRiskLevel.index >= RiskLevel.orange.index
          ? lastResult.copyWith(alertEnabled: false)
          : lastResult;
    }

    final deltaLength = fullText.length - processedLength;
    final minDelta = _adaptiveMinDelta(
      lastResult.overallRiskLevel,
      AnalysisMode.parallel,
    );
    if (deltaLength < minDelta) {
      return lastResult.overallRiskLevel.index >= RiskLevel.orange.index
          ? lastResult.copyWith(alertEnabled: false)
          : lastResult;
    }

    final incrementalText = fullText.substring(processedLength);
    final l1Future = _l1Analyzer.analyzeStream(fullText);

    if (!_l2Analyzer.isReady) await _l2Analyzer.initialize();
    final l2Future = _l2Analyzer.isReady
        ? Future.value(_l2Analyzer.analyze(incrementalText, fullText))
        : Future.value(_defaultResultFor(AnalysisMode.gDetection));

    final results = await Future.wait([l1Future, l2Future]);
    final l1Result = results[0];
    final l2Result = results[1];

    // Fast-track
    if (l1Result.overallRiskLevel.index >= RiskLevel.orange.index) {
      _lastParallelResult = l1Result;
      return l1Result;
    }
    if (l2Result.overallRiskLevel.index >= RiskLevel.orange.index) {
      _lastParallelResult = l2Result;
      return l2Result;
    }

    // L3
    final l3Future = analyzeIncrementalL3(fullText);
    AnalysisResult l3Result;
    try {
      final result = await l3Future.timeout(const Duration(milliseconds: 800));
      l3Result = result ?? _defaultResultFor(AnalysisMode.geminiApi);
    } on TimeoutException {
      l3Result = _defaultResultFor(AnalysisMode.geminiApi);
    }

    final fusionResult = _fuseResults(l1Result, l2Result, l3Result);
    _lastParallelResult = fusionResult;
    return fusionResult;
  }

  AnalysisResult fuseResultsForTesting(
    AnalysisResult l1,
    AnalysisResult l2,
    AnalysisResult l3,
  ) {
    return _fuseResults(l1, l2, l3);
  }

  AnalysisResult _fuseResults(
    AnalysisResult l1,
    AnalysisResult l2,
    AnalysisResult l3,
  ) {
    final combinedMatches = LinkedHashSet<KeywordMatch>.of(<KeywordMatch>[
      ...l1.matches,
      ...l2.matches,
      ...l3.matches,
    ]).toList();
    final selected = _selectFusionSource(l1, l2, l3);
    final highestRisk = selected.overallRiskLevel;

    return AnalysisResult(
      overallRiskLevel: highestRisk,
      matches: combinedMatches,
      reason: selected.reason,
      analysisLevel: selected.analysisLevel,
      alertEnabled:
          highestRisk != RiskLevel.green ||
          l1.alertEnabled ||
          l2.alertEnabled ||
          l3.alertEnabled,
      confidence: [
        l1.confidence,
        l2.confidence,
        l3.confidence,
      ].reduce((a, b) => a > b ? a : b),
      modelName: selected.modelName,
      isError: l1.isError || l2.isError || l3.isError,
      isFallback: l1.isFallback || l2.isFallback || l3.isFallback,
    );
  }

  AnalysisResult _selectFusionSource(
    AnalysisResult l1,
    AnalysisResult l2,
    AnalysisResult l3,
  ) {
    final highestRisk = <AnalysisResult>[l1, l2, l3]
        .map((result) => result.overallRiskLevel)
        .reduce((a, b) => a.index > b.index ? a : b);
    if (highestRisk == RiskLevel.green) {
      return l1;
    }
    if (l3.overallRiskLevel == highestRisk) return l3;
    if (l2.overallRiskLevel == highestRisk) return l2;
    return l1;
  }

  int _adaptiveMinDelta(RiskLevel currentRiskLevel, AnalysisMode mode) {
    final modeMultiplier = switch (mode) {
      AnalysisMode.normal => 0.6,
      AnalysisMode.gDetection => 0.8,
      AnalysisMode.geminiApi => 1.0,
      AnalysisMode.parallel => 0.6, // Dùng tốc độ cập nhật của L1 cho song song
    };
    final baseDelta = switch (currentRiskLevel) {
      RiskLevel.red => _minDeltaRed,
      RiskLevel.orange => _minDeltaOrange,
      _ => _minDeltaDefault,
    };
    return (baseDelta * modeMultiplier).round();
  }

  void reset() {
    for (final mode in AnalysisMode.values) {
      resetMode(mode);
    }
  }

  void resetMode(AnalysisMode mode) {
    switch (mode) {
      case AnalysisMode.normal:
        _l1Analyzer.resetSession();
        break;
      case AnalysisMode.gDetection:
        _l2Analyzer.resetSession();
        break;
      case AnalysisMode.geminiApi:
        closeL3Session(resetProgress: true);
        break;
      case AnalysisMode.parallel:
        _l1Analyzer.resetSession();
        _l2Analyzer.resetSession();
        closeL3Session(resetProgress: true);
        _lastParallelResult = null;
        break;
    }
  }

  int getProcessedTextLength(AnalysisMode mode) {
    if (mode == AnalysisMode.parallel) {
      return _l1Analyzer.processedTextLength;
    }
    return _analyzerFor(mode).processedTextLength;
  }

  AnalysisResult getLastResult(AnalysisMode mode) {
    if (mode == AnalysisMode.parallel) {
      return _lastParallelResult ?? _defaultResultFor(AnalysisMode.parallel);
    }
    final result = _analyzerFor(mode).lastResult;
    if (mode == AnalysisMode.geminiApi &&
        result.overallRiskLevel == RiskLevel.green &&
        result.matches.isEmpty) {
      return _defaultResultFor(mode);
    }
    return result;
  }

  void syncProcessedTextLength(int length, AnalysisMode mode) {
    if (mode == AnalysisMode.parallel) {
      _l1Analyzer.syncProcessedTextLength(length);
      _l2Analyzer.syncProcessedTextLength(length);
      _l3Analyzer.syncProcessedTextLength(length);
    } else {
      _analyzerFor(mode).syncProcessedTextLength(length);
    }
  }

  void createL3Session({int initialProcessedTextLength = 0}) {
    _l3Analyzer.createSession(
      initialProcessedTextLength: initialProcessedTextLength < 0
          ? 0
          : initialProcessedTextLength,
    );
  }

  Future<AnalysisResult?> analyzeIncrementalL3(String fullText) async {
    if (!_l3Analyzer.isReady) {
      await _l3Analyzer.initialize();
    }
    if (_l3Analyzer.processedTextLength == 0) {
      createL3Session();
    }
    final result = await _l3Analyzer.analyzeIncremental(fullText);
    if (result == null) {
      return null;
    }
    if (!result.isError) {
      return result;
    }
    return _fallbackToL2(
      incrementalText: fullText.substring(
        _l3Analyzer.processedTextLength.clamp(0, fullText.length),
      ),
      fullText: fullText,
      fallbackReason: result.reason ?? 'L3 lỗi, chuyển sang L2.',
    );
  }

  void closeL3Session({bool resetProgress = false}) {
    _l3Analyzer.closeSession(resetProgress: resetProgress);
  }

  Map<String, HealthReport> runAllHealthChecks() {
    final analyzers = <Analyzer>[_l1Analyzer, _l2Analyzer, _l3Analyzer];
    return <String, HealthReport>{
      for (final analyzer in analyzers)
        analyzer.level.id: analyzer.healthCheck(),
    };
  }

  Future<AnalysisResult> _analyzeL3WithFallback({
    required String incrementalText,
    required String fullText,
  }) async {
    if (!_l3Analyzer.isReady) {
      await _l3Analyzer.initialize();
    }
    if (!_l3Analyzer.isReady) {
      return _fallbackToL2(
        incrementalText: incrementalText,
        fullText: fullText,
        fallbackReason: 'L3 không sẵn sàng, chuyển sang L2.',
      );
    }
    final result = await _l3Analyzer.analyze(fullText);
    if (!result.isError) {
      return result;
    }
    return _fallbackToL2(
      incrementalText: incrementalText,
      fullText: fullText,
      fallbackReason: result.reason ?? 'L3 lỗi, chuyển sang L2.',
    );
  }

  Future<AnalysisResult> _fallbackToL2({
    required String incrementalText,
    required String fullText,
    required String fallbackReason,
  }) async {
    if (!_l2Analyzer.isReady) {
      await _l2Analyzer.initialize();
    }
    if (!_l2Analyzer.isReady) {
      return AnalysisResult(
        overallRiskLevel: RiskLevel.green,
        matches: const <KeywordMatch>[],
        reason: fallbackReason,
        analysisLevel: AnalysisLevel.l2,
        isError: true,
        isFallback: true,
      );
    }
    final l2Result = await _l2Analyzer.analyze(incrementalText, fullText);
    return l2Result.copyWith(
      reason: '$fallbackReason ${l2Result.reason ?? ''}'.trim(),
      isFallback: true,
    );
  }

  AnalysisResult _defaultResultFor(AnalysisMode mode) {
    final level = switch (mode) {
      AnalysisMode.normal => AnalysisLevel.l1,
      AnalysisMode.gDetection => AnalysisLevel.l2,
      AnalysisMode.geminiApi => AnalysisLevel.l3,
      AnalysisMode.parallel => AnalysisLevel.l3,
    };
    return AnalysisResult(
      overallRiskLevel: RiskLevel.green,
      matches: const <KeywordMatch>[],
      analysisLevel: level,
    );
  }
}
