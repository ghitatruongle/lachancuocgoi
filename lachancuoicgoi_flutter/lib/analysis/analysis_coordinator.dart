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

  Analyzer _analyzerFor(AnalysisMode mode) {
    return switch (mode) {
      AnalysisMode.normal => _l1Analyzer,
      AnalysisMode.gDetection => _l2Analyzer,
      AnalysisMode.geminiApi => _l3Analyzer,
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
    // Mode is passed explicitly to every internal call — there is no
    // shared "last used mode" field. This eliminates the cross-call
    // contamination that previously caused `getLastResult()` to return
    // another analyzer's stale state when concurrent calls used
    // different modes.
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
    };
  }

  Future<AnalysisResult> analyzeIncremental(
    String fullText,
    AnalysisMode mode,
  ) async {
    // No shared "last used mode" — mode is read from the parameter for
    // every sub-call, preventing concurrent calls with different modes
    // from polluting each other's reads.
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

  int _adaptiveMinDelta(RiskLevel currentRiskLevel, AnalysisMode mode) {
    final modeMultiplier = switch (mode) {
      AnalysisMode.normal => 0.6,
      AnalysisMode.gDetection => 0.8,
      AnalysisMode.geminiApi => 1.0,
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
    }
  }

  int getProcessedTextLength(AnalysisMode mode) {
    return _analyzerFor(mode).processedTextLength;
  }

  AnalysisResult getLastResult(AnalysisMode mode) {
    final result = _analyzerFor(mode).lastResult;
    if (mode == AnalysisMode.geminiApi &&
        result.overallRiskLevel == RiskLevel.green &&
        result.matches.isEmpty) {
      return _defaultResultFor(mode);
    }
    return result;
  }

  void syncProcessedTextLength(int length, AnalysisMode mode) {
    _analyzerFor(mode).syncProcessedTextLength(length);
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
    };
    return AnalysisResult(
      overallRiskLevel: RiskLevel.green,
      matches: const <KeywordMatch>[],
      analysisLevel: level,
    );
  }
}
