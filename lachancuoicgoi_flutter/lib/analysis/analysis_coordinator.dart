import 'dart:async';
import 'dart:math' as math;

import '../core/risk_level.dart';
import '../core/system_logger.dart';
import 'analysis_fallback.dart';
import 'analysis_fusion.dart';
import 'fallback_tracker.dart';
import 'analysis_level.dart';
import 'analysis_mode.dart';
import 'analysis_mode_policy.dart';
import 'analysis_result.dart';
import 'analyzer.dart';
import 'health_check.dart';
import 'l1/l1_analysis.dart';
import 'l2/l2_analysis.dart';
import 'l3/core/risk_deescalation.dart';
import 'l3/l3_analysis.dart';

class AnalysisCoordinator {
  AnalysisCoordinator({
    L1Analyzer? l1Analyzer,
    L2Analyzer? l2Analyzer,
    L3Analyzer? l3Analyzer,
    RiskDeescalationMachine? sessionDeescalation,
    bool Function()? networkAvailable,
  }) : _l1Analyzer = l1Analyzer ?? L1Analyzer(),
       _l2Analyzer = l2Analyzer ?? L2Analyzer(),
       _l3Analyzer = l3Analyzer ?? L3Analyzer(),
       _sessionDeescalation = sessionDeescalation ?? RiskDeescalationMachine(),
       _networkAvailableCallback = networkAvailable;

  static const int _minDeltaDefault = 50;
  static const int _minDeltaOrange = 30;
  static const int _minDeltaRed = 20;

  /// L3 timeout bounds for adaptive calibration.
  /// Instead of a fixed 1800ms, we measure actual RTT and set timeout = RTT × 2,
  /// clamped to [min, max]. This avoids over-waiting on fast networks and
  /// under-waiting on slow ones.
  static const Duration _l3TimeoutMin = Duration(milliseconds: 800);
  static const Duration _l3TimeoutMax = Duration(milliseconds: 1800);
  static const Duration _l3TimeoutElevatedMin = Duration(milliseconds: 500);
  static const Duration _l3TimeoutElevatedMax = Duration(milliseconds: 800);

  /// Measured RTT (exponential moving average, α=0.3). Null until first
  /// successful L3 response calibrates it.
  Duration? _measuredRtt;

  /// Returns an adaptive L3 timeout based on measured RTT.
  /// Falls back to conservative max until first calibration.
  Duration _l3TimeoutFor(bool elevated) {
    final rtt = _measuredRtt;
    if (rtt == null) {
      return elevated ? _l3TimeoutElevatedMax : _l3TimeoutMax;
    }
    final doubledMs = rtt.inMilliseconds * 2;
    if (elevated) {
      return Duration(
        milliseconds: doubledMs.clamp(
          _l3TimeoutElevatedMin.inMilliseconds,
          _l3TimeoutElevatedMax.inMilliseconds,
        ),
      );
    }
    return Duration(
      milliseconds: doubledMs.clamp(
        _l3TimeoutMin.inMilliseconds,
        _l3TimeoutMax.inMilliseconds,
      ),
    );
  }

  /// Called after a successful L3 request to calibrate future timeouts.
  /// Uses EMA (α=0.3) to smooth jitter.
  void recordL3Rtt(Duration rtt) {
    final previous = _measuredRtt;
    if (previous == null) {
      _measuredRtt = rtt;
    } else {
      _measuredRtt = Duration(
        milliseconds: (previous.inMilliseconds * 0.7 + rtt.inMilliseconds * 0.3)
            .round(),
      );
    }
  }

  final L1Analyzer _l1Analyzer;
  final L2Analyzer _l2Analyzer;
  final L3Analyzer _l3Analyzer;
  final RiskDeescalationMachine _sessionDeescalation;
  final bool Function()? _networkAvailableCallback;

  AnalysisResult? _lastParallelResult;

  /// Optional speech rate (chars/sec) provided by the UI layer.
  double _speechRate = 0;

  /// Network flag updated by the monitoring layer (default: online).
  bool _networkAvailableFlag = true;

  void setSpeechRate(double charsPerSecond) {
    _speechRate = charsPerSecond < 0 ? 0 : charsPerSecond;
  }

  void setNetworkAvailable(bool available) {
    _networkAvailableFlag = available;
  }

  bool _isNetworkAvailable() {
    return _networkAvailableCallback?.call() ?? _networkAvailableFlag;
  }

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
    SystemLogger.instance.log(
      LogCategory.analysis,
      'Bắt đầu phân tích. Chế độ: ${mode.name}, độ dài văn bản: ${fullText.length} kí tự.',
    );
    if (mode == AnalysisMode.gDetection && !_l2Analyzer.isReady) {
      SystemLogger.instance.log(
        LogCategory.model,
        'Đang khởi tạo L2 Analyzer (Local Vocabulary & Regex)...',
      );
      await _l2Analyzer.initialize();
      if (!_l2Analyzer.isReady) {
        SystemLogger.instance.log(
          LogCategory.model,
          'L2 Analyzer khởi tạo thất bại.',
          level: LogLevel.error,
        );
        return const AnalysisResult(
          overallRiskLevel: RiskLevel.green,
          matches: <KeywordMatch>[],
          reason: 'Hệ thống AI (L2) đang khởi tạo...',
          analysisLevel: AnalysisLevel.l2,
        );
      }
      SystemLogger.instance.log(
        LogCategory.model,
        'L2 Analyzer khởi tạo thành công.',
      );
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
    AnalysisMode mode, {
    double? speechRate,
  }) async {
    if (speechRate != null) {
      setSpeechRate(speechRate);
    }
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
      transcriptLength: fullText.length,
      matchCount: lastResult.matches.length,
      lastConfidence: lastResult.confidence,
      speechRate: _speechRate,
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
      return _applySessionDeescalation(fastTrack);
    }

    if (AnalysisModePolicy.shouldSkipCloudTier(
      AnalysisMode.parallel,
      _isNetworkAvailable(),
    )) {
      final offlineFuse = AnalysisFusion.fuse(
        l1Result,
        l2Result,
        AnalysisFallback.defaultForMode(AnalysisMode.geminiApi),
      );
      final result = offlineFuse.copyWith(
        isFallback: true,
        reason: offlineFuse.reason == null
            ? 'Offline: chỉ L1+L2.'
            : '${offlineFuse.reason} (offline L1+L2)',
      );
      return _applySessionDeescalation(result);
    }

    final elevated =
        l1Result.overallRiskLevel.index >= RiskLevel.yellow.index ||
        l2Result.overallRiskLevel.index >= RiskLevel.yellow.index;
    final l3Result = await _runL3WithTimeout(
      _analyzeL3WithFallback(
        incrementalText: incrementalText,
        fullText: fullText,
      ),
      elevated: elevated,
    );
    return _applySessionDeescalation(
      AnalysisFusion.fuse(l1Result, l2Result, l3Result),
    );
  }

  Future<AnalysisResult> _analyzeIncrementalParallel(String fullText) async {
    final processedLength = getProcessedTextLength(AnalysisMode.parallel);
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
      speechRate: _speechRate,
    );
    if (deltaLength < minDelta) {
      return lastResult.overallRiskLevel.index >= RiskLevel.orange.index
          ? lastResult.copyWith(alertEnabled: false)
          : lastResult;
    }

    final incrementalText = fullText.substring(
      processedLength.clamp(0, fullText.length),
    );
    final (l1Result, l2Result) = await _runL1L2Parallel(
      incrementalText: incrementalText,
      fullText: fullText,
    );

    final fastTrack = _parallelFastTrack(l1Result, l2Result);
    if (fastTrack != null) {
      final deescalated = _applySessionDeescalation(fastTrack);
      _lastParallelResult = deescalated;
      return deescalated;
    }

    if (AnalysisModePolicy.shouldSkipCloudTier(
      AnalysisMode.parallel,
      _isNetworkAvailable(),
    )) {
      final offlineFuse = AnalysisFusion.fuse(
        l1Result,
        l2Result,
        AnalysisFallback.defaultForMode(AnalysisMode.geminiApi),
      );
      final result = _applySessionDeescalation(
        offlineFuse.copyWith(isFallback: true),
      );
      _lastParallelResult = result;
      return result;
    }

    final elevated =
        l1Result.overallRiskLevel.index >= RiskLevel.yellow.index ||
        l2Result.overallRiskLevel.index >= RiskLevel.yellow.index;
    final l3Result = await _runL3WithTimeout(
      analyzeIncrementalL3(fullText),
      elevated: elevated,
    );

    final fusionResult = _applySessionDeescalation(
      AnalysisFusion.fuse(l1Result, l2Result, l3Result),
    );
    _lastParallelResult = fusionResult;
    return fusionResult;
  }

  Future<(AnalysisResult, AnalysisResult)> _runL1L2Parallel({
    required String incrementalText,
    required String fullText,
  }) async {
    final l1Future = _l1Analyzer.analyzeStream(fullText);

    if (!_l2Analyzer.isReady) {
      await _l2Analyzer.initialize();
    }
    // Prefer full readiness (GDetection + intent). If only GDetection is
    // ready we still run L2 in degraded mode rather than skipping entirely.
    final l2Future = _l2Analyzer.isReady
        ? Future.value(_l2Analyzer.analyze(incrementalText, fullText))
        : Future.value(
            AnalysisFallback.defaultForMode(AnalysisMode.gDetection),
          );

    if (_l2Analyzer.isReady && !_l2Analyzer.isFullyReady) {
      SystemLogger.instance.log(
        LogCategory.model,
        'L2 chạy chế độ degraded (intent/TFLite chưa sẵn sàng).',
        level: LogLevel.warning,
      );
    }

    final results = await Future.wait([l1Future, l2Future]);
    return (results[0], results[1]);
  }

  /// Fast-track rules (Phase 1):
  /// - L1 **red** alone → critical hard path (OTP / immediate danger).
  /// - L2 ≥ orange → trust on-device AI without waiting for L3.
  /// - L1 orange alone does **not** skip L3 (reduces false positives).
  AnalysisResult? _parallelFastTrack(
    AnalysisResult l1Result,
    AnalysisResult l2Result,
  ) {
    if (l1Result.overallRiskLevel == RiskLevel.red) {
      return l1Result;
    }
    if (l2Result.overallRiskLevel.index >= RiskLevel.orange.index) {
      return l2Result;
    }
    return null;
  }

  Future<AnalysisResult> _runL3WithTimeout(
    Future<AnalysisResult?> l3Future, {
    bool elevated = false,
  }) async {
    final budget = _l3TimeoutFor(elevated);
    final stopwatch = Stopwatch()..start();
    try {
      final result = await l3Future.timeout(budget);
      stopwatch.stop();
      // Calibrate future timeouts based on this successful RTT.
      recordL3Rtt(stopwatch.elapsed);
      return result ?? AnalysisFallback.defaultForMode(AnalysisMode.geminiApi);
    } on TimeoutException {
      stopwatch.stop();
      SystemLogger.instance.log(
        LogCategory.analysis,
        'L3 timeout after ${budget.inMilliseconds}ms — fuse without L3.',
        level: LogLevel.warning,
      );
      return AnalysisFallback.defaultForMode(AnalysisMode.geminiApi);
    }
  }

  AnalysisResult _applySessionDeescalation(AnalysisResult result) {
    final level = _sessionDeescalation.process(result.overallRiskLevel);
    if (level == result.overallRiskLevel) return result;
    return result.copyWith(
      overallRiskLevel: level,
      alertEnabled: level.shouldAlert ? result.alertEnabled : false,
    );
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
    _sessionDeescalation.reset();
  }

  int getProcessedTextLength(AnalysisMode mode) {
    if (mode == AnalysisMode.parallel) {
      // Use the max cursor so we don't re-run prematurely on a lagging tier,
      // but never skip text that L1 has not yet consumed.
      return math.max(
        _l1Analyzer.processedTextLength,
        math.max(
          _l2Analyzer.processedTextLength,
          _l3Analyzer.processedTextLength,
        ),
      );
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
      SystemLogger.instance.log(
        LogCategory.model,
        'Đang khởi tạo L3 Analyzer (Gemini API)...',
      );
      await _l3Analyzer.initialize();
      if (_l3Analyzer.isReady) {
        SystemLogger.instance.log(
          LogCategory.model,
          'L3 Analyzer đã sẵn sàng.',
        );
      } else {
        SystemLogger.instance.log(
          LogCategory.model,
          'L3 Analyzer khởi tạo thất bại.',
          level: LogLevel.error,
        );
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
    SystemLogger.instance.log(
      LogCategory.analysis,
      'L3 Analyzer gặp lỗi: $fallbackReason. Tiến hành hạ cấp xuống L2...',
      level: LogLevel.warning,
    );
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

  /// Human-readable health snapshot for settings / dev panel.
  Map<String, String> healthSummary() {
    final reports = runAllHealthChecks();
    final fallbackTotal = FallbackTracker.instance.total;
    return {
      for (final entry in reports.entries)
        entry.key: entry.value.isHealthy
            ? 'OK: ${entry.value.message}'
            : 'FAIL: ${entry.value.message}',
      'l2_full': _l2Analyzer.isFullyReady ? 'OK' : 'degraded',
      'network': _isNetworkAvailable() ? 'online' : 'offline',
      if (fallbackTotal > 0)
        'fallbacks':
            '$fallbackTotal (${FallbackTracker.instance.allCounts.entries.map((e) => '${e.key}:${e.value}').join(', ')})',
    };
  }

  Future<AnalysisResult> _analyzeL3WithFallback({
    required String incrementalText,
    required String fullText,
  }) async {
    if (!_l3Analyzer.isReady) {
      SystemLogger.instance.log(
        LogCategory.model,
        'Đang khởi tạo L3 Analyzer (Gemini API)...',
      );
      await _l3Analyzer.initialize();
      if (_l3Analyzer.isReady) {
        SystemLogger.instance.log(
          LogCategory.model,
          'L3 Analyzer đã sẵn sàng.',
        );
      } else {
        SystemLogger.instance.log(
          LogCategory.model,
          'L3 Analyzer khởi tạo thất bại.',
          level: LogLevel.error,
        );
      }
    }
    if (!_l3Analyzer.isReady) {
      SystemLogger.instance.log(
        LogCategory.analysis,
        'L3 không sẵn sàng. Tiến hành hạ cấp xuống L2...',
        level: LogLevel.warning,
      );
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
    SystemLogger.instance.log(
      LogCategory.analysis,
      'L3 Analyzer gặp lỗi: $fallbackReason. Tiến hành hạ cấp xuống L2...',
      level: LogLevel.warning,
    );
    return AnalysisFallback.fallbackToL2(
      incrementalText: incrementalText,
      fullText: fullText,
      fallbackReason: fallbackReason,
      isL2Ready: () => _l2Analyzer.isReady,
      initializeL2: () => _l2Analyzer.initialize(),
      runL2Analysis: _l2Analyzer.analyze,
    );
  }

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

    double densityFactor = 1.0;
    if (transcriptLength > 0 && matchCount > 0) {
      final density = matchCount / transcriptLength;
      densityFactor = 1.0 - (density * 10.0).clamp(0.0, 0.3);
    }

    double confidenceFactor = 1.0;
    if (riskLevel.index >= RiskLevel.orange.index && lastConfidence > 0) {
      confidenceFactor = 1.0 - (lastConfidence * 0.2).clamp(0.0, 0.2);
    }

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
