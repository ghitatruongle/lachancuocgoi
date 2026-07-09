import 'dart:async';

import '../core/risk_level.dart';
import '../core/system_logger.dart';
import 'analysis_fallback.dart';
import 'analysis_fusion.dart';
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

  /// Maximum wall-clock time the parallel pipeline waits for L3 (Gemini)
  /// before falling back to a default L3 result. Tuned so end-to-end UI
  /// latency stays under ~1s even on slow networks.
  static const Duration _l3Timeout = Duration(milliseconds: 800);

  final L1Analyzer _l1Analyzer;
  final L2Analyzer _l2Analyzer;
  final L3Analyzer _l3Analyzer;

  AnalysisResult? _lastParallelResult;

  Analyzer _analyzerFor(AnalysisMode mode) {
    return switch (mode) {
      AnalysisMode.normal => _l1Analyzer,
      AnalysisMode.gDetection => _l2Analyzer,
      AnalysisMode.geminiApi => _l3Analyzer,
      AnalysisMode.parallel => _l3Analyzer,
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
    SystemLogger.instance.log(LogCategory.analysis, 'Bắt đầu phân tích. Chế độ: ${mode.name}, độ dài văn bản: ${fullText.length} kí tự.');
    if (mode == AnalysisMode.gDetection && !_l2Analyzer.isReady) {
      SystemLogger.instance.log(LogCategory.model, 'Đang khởi tạo L2 Analyzer (Local Vocabulary & Regex)...');
      await _l2Analyzer.initialize();
      if (!_l2Analyzer.isReady) {
        SystemLogger.instance.log(LogCategory.model, 'L2 Analyzer khởi tạo thất bại.', level: LogLevel.error);
        return const AnalysisResult(
          overallRiskLevel: RiskLevel.green,
          matches: <KeywordMatch>[],
          reason: 'Hệ thống AI (L2) đang khởi tạo...',
          analysisLevel: AnalysisLevel.l2,
        );
      }
      SystemLogger.instance.log(LogCategory.model, 'L2 Analyzer khởi tạo thành công.');
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
    final minDelta = _adaptiveMinDelta(
      lastResult.overallRiskLevel,
      mode,
      // Context parameters for adaptive calculation (default: no adjustment)
      transcriptLength: fullText.length,
      matchCount: lastResult.matches.length,
      lastConfidence: lastResult.confidence,
      speechRate: 0,
    );
    if (deltaLength < minDelta) {
      return lastResult.overallRiskLevel.index >= RiskLevel.orange.index
          ? lastResult.copyWith(alertEnabled: false)
          : lastResult;
    }

    if (mode == AnalysisMode.geminiApi) {
      final result = await analyzeIncrementalL3(fullText);
      return result ?? AnalysisFallback.defaultForMode(mode);
    }

    final textToAnalyze = fullText.substring(processedTextLength);
    return analyzeWithTranscript(textToAnalyze, fullText, mode);
  }

  Future<AnalysisResult> _analyzeParallel({
    required String incrementalText,
    required String fullText,
  }) async {
    final (l1Result, l2Result) = await _runL1L2Parallel(
      incrementalText: incrementalText,
      fullText: fullText,
    );

    final fastTrack = _parallelFastTrack(l1Result, l2Result);
    if (fastTrack != null) {
      return fastTrack;
    }

    final l3Result = await _runL3WithTimeout(
      _analyzeL3WithFallback(
        incrementalText: incrementalText,
        fullText: fullText,
      ),
    );
    return AnalysisFusion.fuse(l1Result, l2Result, l3Result);
  }

  Future<AnalysisResult> _analyzeIncrementalParallel(String fullText) async {
    final processedLength = _l1Analyzer.processedTextLength;
    final lastResult =
        _lastParallelResult ??
        AnalysisFallback.defaultForMode(AnalysisMode.parallel);

    if (fullText.length <= processedLength) {
      return lastResult.overallRiskLevel.index >= RiskLevel.orange.index
          ? lastResult.copyWith(alertEnabled: false)
          : lastResult;
    }

    final deltaLength = fullText.length - processedLength;
    final minDelta = _adaptiveMinDelta(
      lastResult.overallRiskLevel,
      AnalysisMode.parallel,
      transcriptLength: lastResult.matches.isNotEmpty ? fullText.length : 0,
      matchCount: lastResult.matches.length,
      lastConfidence: lastResult.confidence,
      speechRate: 0,
    );
    if (deltaLength < minDelta) {
      return lastResult.overallRiskLevel.index >= RiskLevel.orange.index
          ? lastResult.copyWith(alertEnabled: false)
          : lastResult;
    }

    final incrementalText = fullText.substring(processedLength);
    final (l1Result, l2Result) = await _runL1L2Parallel(
      incrementalText: incrementalText,
      fullText: fullText,
    );

    // Fast-track: orange+ from L1 or L2 short-circuits past L3.
    final fastTrack = _parallelFastTrack(l1Result, l2Result);
    if (fastTrack != null) {
      _lastParallelResult = fastTrack;
      return fastTrack;
    }

    // L3 with timeout; falls back to a default green result on timeout/null.
    final l3Result = await _runL3WithTimeout(analyzeIncrementalL3(fullText));

    final fusionResult = AnalysisFusion.fuse(l1Result, l2Result, l3Result);
    _lastParallelResult = fusionResult;
    return fusionResult;
  }

  // ─── Shared parallel-pipeline helpers ─────────────────────────────────────
  //
  // [_analyzeParallel] and [_analyzeIncrementalParallel] share three steps:
  //   1. Fan out L1 (stream) and L2 (after lazy init) in parallel.
  //   2. Fast-track: if either hits orange+, return it without waiting for L3.
  //   3. Run L3 with an [_l3Timeout] guard, then fuse L1+L2+L3.
  // Extracted to remove ~100 lines of duplication between the two entry points.

  /// Runs L1 (full-text stream) and L2 (incremental + full-text) in parallel,
  /// lazily initializing L2 first if needed. Falls back to a default L2 green
  /// result when L2 cannot be initialized.
  Future<(AnalysisResult, AnalysisResult)> _runL1L2Parallel({
    required String incrementalText,
    required String fullText,
  }) async {
    final l1Future = _l1Analyzer.analyzeStream(fullText);

    if (!_l2Analyzer.isReady) {
      await _l2Analyzer.initialize();
    }
    final l2Future = _l2Analyzer.isReady
        ? Future.value(_l2Analyzer.analyze(incrementalText, fullText))
        : Future.value(
            AnalysisFallback.defaultForMode(AnalysisMode.gDetection),
          );

    final results = await Future.wait([l1Future, l2Future]);
    return (results[0], results[1]);
  }

  /// Returns the first orange+ result for fast-track short-circuit, or `null`
  /// when neither L1 nor L2 reach the alert threshold (so L3 should run).
  AnalysisResult? _parallelFastTrack(
    AnalysisResult l1Result,
    AnalysisResult l2Result,
  ) {
    if (l1Result.overallRiskLevel.index >= RiskLevel.orange.index) {
      return l1Result;
    }
    if (l2Result.overallRiskLevel.index >= RiskLevel.orange.index) {
      return l2Result;
    }
    return null;
  }

  /// Awaits [l3Future] with an [_l3Timeout] guard. On timeout returns a default
  /// L3 result so the pipeline fuses with a graceful green fallback instead of
  /// stalling the UI. A `null` L3 result is treated the same as a timeout.
  Future<AnalysisResult> _runL3WithTimeout(
    Future<AnalysisResult?> l3Future,
  ) async {
    try {
      final result = await l3Future.timeout(_l3Timeout);
      return result ?? AnalysisFallback.defaultForMode(AnalysisMode.geminiApi);
    } on TimeoutException {
      return AnalysisFallback.defaultForMode(AnalysisMode.geminiApi);
    }
  }

  AnalysisResult fuseResultsForTesting(
    AnalysisResult l1,
    AnalysisResult l2,
    AnalysisResult l3,
  ) {
    return AnalysisFusion.fuse(l1, l2, l3);
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
      return _lastParallelResult ??
          AnalysisFallback.defaultForMode(AnalysisMode.parallel);
    }
    final result = _analyzerFor(mode).lastResult;
    if (mode == AnalysisMode.geminiApi &&
        result.overallRiskLevel == RiskLevel.green &&
        result.matches.isEmpty) {
      return AnalysisFallback.defaultForMode(mode);
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
      SystemLogger.instance.log(LogCategory.model, 'Đang khởi tạo L3 Analyzer (Gemini API)...');
      await _l3Analyzer.initialize();
      if (_l3Analyzer.isReady) {
        SystemLogger.instance.log(LogCategory.model, 'L3 Analyzer đã sẵn sàng.');
      } else {
        SystemLogger.instance.log(LogCategory.model, 'L3 Analyzer khởi tạo thất bại.', level: LogLevel.error);
      }
    }
    if (!_l3Analyzer.hasActiveSession) {
      createL3Session();
    }
    final result = await _l3Analyzer.analyzeIncremental(fullText);
    if (result == null) {
      return null;
    }
    if (!result.isError) {
      return result;
    }
    final fallbackReason = result.reason ?? 'L3 lỗi, chuyển sang L2.';
    SystemLogger.instance.log(LogCategory.analysis, 'L3 Analyzer gặp lỗi: $fallbackReason. Tiến hành hạ cấp xuống L2...', level: LogLevel.warning);
    return AnalysisFallback.fallbackToL2(
      incrementalText: fullText.substring(
        _l3Analyzer.processedTextLength.clamp(0, fullText.length),
      ),
      fullText: fullText,
      fallbackReason: fallbackReason,
      isL2Ready: () => _l2Analyzer.isReady,
      initializeL2: () => _l2Analyzer.initialize(),
      runL2Analysis: _l2Analyzer.analyze,
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
      SystemLogger.instance.log(LogCategory.model, 'Đang khởi tạo L3 Analyzer (Gemini API)...');
      await _l3Analyzer.initialize();
      if (_l3Analyzer.isReady) {
        SystemLogger.instance.log(LogCategory.model, 'L3 Analyzer đã sẵn sàng.');
      } else {
        SystemLogger.instance.log(LogCategory.model, 'L3 Analyzer khởi tạo thất bại.', level: LogLevel.error);
      }
    }
    if (!_l3Analyzer.isReady) {
      SystemLogger.instance.log(LogCategory.analysis, 'L3 không sẵn sàng. Tiến hành hạ cấp xuống L2...', level: LogLevel.warning);
      return AnalysisFallback.fallbackToL2(
        incrementalText: incrementalText,
        fullText: fullText,
        fallbackReason: 'L3 không sẵn sàng, chuyển sang L2.',
        isL2Ready: () => _l2Analyzer.isReady,
        initializeL2: () => _l2Analyzer.initialize(),
        runL2Analysis: _l2Analyzer.analyze,
      );
    }
    final result = await _l3Analyzer.analyze(fullText);
    if (!result.isError) {
      return result;
    }
    final fallbackReason = result.reason ?? 'L3 lỗi, chuyển sang L2.';
    SystemLogger.instance.log(LogCategory.analysis, 'L3 Analyzer gặp lỗi: $fallbackReason. Tiến hành hạ cấp xuống L2...', level: LogLevel.warning);
    return AnalysisFallback.fallbackToL2(
      incrementalText: incrementalText,
      fullText: fullText,
      fallbackReason: fallbackReason,
      isL2Ready: () => _l2Analyzer.isReady,
      initializeL2: () => _l2Analyzer.initialize(),
      runL2Analysis: _l2Analyzer.analyze,
    );
  }

  /// Computes the minimum character delta required before re-analysis triggers.
  ///
  /// The delta adapts to:
  /// - [riskLevel]: higher risk → smaller delta (faster reaction)
  /// - [mode]: different modes have different cost/reward trade-offs
  /// - [matchCount]/[transcriptLength]: match density — dense matches → smaller delta
  /// - [lastConfidence]: high confidence in scam → smaller delta
  /// - [speechRate]: faster speech → smaller delta
  int _adaptiveMinDelta(
    RiskLevel riskLevel,
    AnalysisMode mode, {
    int transcriptLength = 0,
    int matchCount = 0,
    double lastConfidence = 0.0,
    double speechRate = 0.0,
  }) {
    final baseDelta = switch (riskLevel) {
      RiskLevel.red => _minDeltaRed,
      RiskLevel.orange => _minDeltaOrange,
      _ => _minDeltaDefault,
    };

    final modeMultiplier = switch (mode) {
      AnalysisMode.normal => 0.6,
      AnalysisMode.gDetection => 0.8,
      AnalysisMode.geminiApi => 1.0,
      AnalysisMode.parallel => 0.6,
    };

    // Match density factor: dense matches → analyze more frequently.
    // If match count is high relative to transcript length, we likely have
    // active scam signals needing quick reaction.
    double densityFactor = 1.0;
    if (transcriptLength > 0 && matchCount > 0) {
      final density = matchCount / transcriptLength;
      densityFactor = 1.0 - (density * 10.0).clamp(0.0, 0.3);
    }

    // Confidence factor: high scam confidence → smaller delta.
    // Low confidence → wait for more evidence.
    double confidenceFactor = 1.0;
    if (riskLevel.index >= RiskLevel.orange.index && lastConfidence > 0) {
      confidenceFactor = 1.0 - (lastConfidence * 0.2).clamp(0.0, 0.2);
    }

    // Speech rate factor: faster speech → smaller delta.
    // Prevents missed signals when scammer speaks quickly.
    double rateFactor = 1.0;
    if (speechRate > 5.0) {
      rateFactor = 0.7;
    } else if (speechRate > 2.0) {
      rateFactor = 0.85;
    }

    final delta =
        (baseDelta *
                modeMultiplier *
                densityFactor *
                confidenceFactor *
                rateFactor)
            .round()
            .clamp(5, 100);
    return delta;
  }
}
