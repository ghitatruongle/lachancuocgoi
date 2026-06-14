import 'dart:async' show Completer;

import 'package:flutter/foundation.dart';

import '../analysis_level.dart';
import '../analysis_result.dart';
import '../analyzer.dart';
import '../health_check.dart';
import '../../core/risk_level.dart';
import 'g_detection/g_detection_engine.dart';
import 'g_detection/g_models.dart';
import 'intent/intent_classifier.dart';
import 'intent/scam_intent.dart';
import 'l2_result.dart';
import 'safety/safety_filter.dart';
import 'wfsa/scam_graph_builder.dart';
import 'wfsa/wfsa_engine.dart';

class L2Analyzer implements Analyzer {
  L2Analyzer({
    GDetectionEngine? gDetectionEngine,
    IntentClassifier? intentClassifier,
    WfsaEngine? wfsaEngine,
  }) : _gDetectionEngine = gDetectionEngine ?? GDetectionEngine(),
       _intentClassifier = intentClassifier ?? const DisabledIntentClassifier(),
       _wfsaEngine =
           wfsaEngine ?? WfsaEngine(ScamGraphBuilder.buildDefaultGraphs());

  static const double aiHighConfidenceThreshold = 0.80;
  static const double aiDirectConfidence = 0.62;
  static const double aiDirectMargin = 0.15;
  static const double aiAssistConfidence = 0.50;
  static const double aiAssistMargin = 0.08;

  // Phase 2.3: Concurrency limiter — only one analyze() runs at a time.
  // Prevents CPU spike from concurrent TFLite + GDetection + WFSA.
  Future<void> _analysisMutex = Future.value();

  // Generation counter: incremented at the start of each analyze() call.
  // When a mutex timeout forces a new analysis to start while the previous
  // one is still in-flight, the stale analysis will see a mismatched
  // generation and skip writing to _lastResult / _processedTextLength.
  int _analysisGeneration = 0;

  final GDetectionEngine _gDetectionEngine;
  final IntentClassifier _intentClassifier;
  final WfsaEngine _wfsaEngine;

  int _processedTextLength = 0;
  AnalysisResult _lastResult = const AnalysisResult(
    overallRiskLevel: RiskLevel.green,
    matches: <KeywordMatch>[],
    analysisLevel: AnalysisLevel.l2,
  );

  @override
  AnalysisLevel get level => AnalysisLevel.l2;

  @override
  Future<void> initialize() async {
    // Chạy song song 3 component — mỗi component đã có Future.delayed nội bộ
    await Future.wait(<Future<void>>[
      _gDetectionEngine.initialize(),
      _intentClassifier.initialize(),
      SafetyFilter.loadConfig(),
    ]);
  }

  @override
  bool get isReady => _gDetectionEngine.isReady;

  bool get isFullyReady =>
      _gDetectionEngine.isReady && _intentClassifier.isReady;

  bool get isIntentClassifierReady => _intentClassifier.isReady;

  @override
  HealthReport healthCheck() {
    final gdReady = _gDetectionEngine.isReady;
    final icReady = _intentClassifier.isReady;
    if (!gdReady) {
      return const HealthReport(
        status: HealthStatus.down,
        component: 'L2',
        message:
            'GDetectionEngine chưa sẵn sàng. Keywords/patterns có thể chưa load.',
      );
    }
    if (!icReady) {
      return const HealthReport(
        status: HealthStatus.degraded,
        component: 'L2',
        message:
            'GDetection OK nhưng IntentClassifier chưa sẵn sàng. Chỉ Luồng 2 hoạt động.',
      );
    }
    return const HealthReport(
      status: HealthStatus.healthy,
      component: 'L2',
      message:
          'GDetection + IntentClassifier đều sẵn sàng. Cả 2 luồng hoạt động.',
    );
  }

  @override
  void resetSession() {
    _gDetectionEngine.reset();
    _wfsaEngine.resetSession();
    _processedTextLength = 0;
    _lastResult = const AnalysisResult(
      overallRiskLevel: RiskLevel.green,
      matches: <KeywordMatch>[],
      analysisLevel: AnalysisLevel.l2,
    );
  }

  @override
  int get processedTextLength => _processedTextLength;

  @override
  void syncProcessedTextLength(int length) {
    _processedTextLength = length < 0 ? 0 : length;
  }

  @override
  AnalysisResult get lastResult => _lastResult;

  Future<AnalysisResult> analyze(
    String incrementalText,
    String fullText,
  ) async {
    if (!isReady || fullText.trim().isEmpty) {
      const emptyResult = AnalysisResult(
        overallRiskLevel: RiskLevel.green,
        matches: <KeywordMatch>[],
        analysisLevel: AnalysisLevel.l2,
      );
      _lastResult = emptyResult;
      return emptyResult;
    }

    // Phase 2.3: Wait for any in-flight analysis to finish before starting.
    final prevMutex = _analysisMutex;
    final completer = Completer<void>();
    _analysisMutex = completer.future;

    // Capture the generation BEFORE incrementing — used to detect if a
    // newer analyze() call has superseded this one after a mutex timeout.
    final myGeneration = ++_analysisGeneration;

    await prevMutex.timeout(
      const Duration(seconds: 5),
      onTimeout: () {
        debugPrint('[L2Analyzer] Timeout waiting for previous analysis lock — force continuing');
      },
    );

    // Early bail-out: if a newer analyze() superseded us while we were waiting
    // on the mutex (or its timeout), don't bother running the expensive
    // TFLite + trie work — its result would be discarded by the generation
    // guard below anyway. This avoids doubling CPU load when calls overlap.
    if (myGeneration != _analysisGeneration) {
      return _lastResult;
    }

    try {
      final results = await Future.wait<Object>([
        _runIntentFlow(fullText),
        _gDetectionEngine.performFullAnalysis(fullText),
      ]);
      final luong1Result = results[0] as _Luong1Result;
      final gResult = results[1] as GResult;
      final parsedGDetectionResult = L2ResultParser.parse(gResult);

      final intentForWfsa = luong1Result is _Luong1Success
          ? <IntentPrediction>[luong1Result.prediction]
          : const <IntentPrediction>[];
      var wfsaScore = _wfsaEngine.analyzeIncremental(fullText, intentForWfsa);
      final safetyDiscount = SafetyFilter.calculateSafetyDiscount(fullText);
      wfsaScore *= safetyDiscount;

      final wfsaRiskLevel = switch (wfsaScore) {
        >= 50.0 => RiskLevel.red,
        >= 20.0 => RiskLevel.yellow,
        _ => RiskLevel.green,
      };
      final gDetectionRiskLevel = _discountGDetectionRisk(
        parsedGDetectionResult.overallRiskLevel,
        safetyDiscount,
        luong1Result,
      );
      final result2 = _mergeContextResult(
        parsedGDetectionResult,
        gDetectionRiskLevel,
        wfsaRiskLevel,
        wfsaScore,
      );

      final result = switch (luong1Result) {
        _Luong1Success() => _fuseIntentSuccess(luong1Result, result2, fullText),
        _Luong1Fallback() => _fallbackResult(result2, fullText),
      };

      // Guard: only write results if this generation is still the latest.
      // A newer analyze() call may have force-continued via mutex timeout,
      // in which case this stale result must not overwrite the fresher one.
      if (myGeneration == _analysisGeneration) {
        _processedTextLength = fullText.length;
        _lastResult = result;
      }
      return result;
    } finally {
      completer.complete();
    }
  }

  Future<_Luong1Result> _runIntentFlow(String fullText) async {
    if (!_intentClassifier.isReady) {
      return const _Luong1Fallback();
    }
    try {
      final intentPredictions = await _intentClassifier.predictIntent(fullText);
      if (intentPredictions.isEmpty) return const _Luong1Fallback();
      final topIntent = intentPredictions.first;
      final secondConfidence = intentPredictions.length > 1
          ? intentPredictions[1].confidence
          : 0.0;
      final confidenceMargin = topIntent.confidence - secondConfidence;
      final isAiConfident =
          topIntent.confidence >= aiAssistConfidence &&
          confidenceMargin >= aiAssistMargin;
      if (isAiConfident) {
        return _Luong1Success(topIntent, confidenceMargin);
      }
      return const _Luong1Fallback();
    } catch (_) {
      return const _Luong1Fallback();
    }
  }

  RiskLevel _discountGDetectionRisk(
    RiskLevel originalRisk,
    double safetyDiscount,
    _Luong1Result luong1Result,
  ) {
    if (safetyDiscount >= 1.0 || originalRisk == RiskLevel.red) {
      return originalRisk;
    }

    bool isAiHighlyConfidentScam = false;
    if (luong1Result is _Luong1Success) {
      final topIntent = luong1Result.prediction;
      final intentRisk = topIntent.intent.riskLevelForConfidence(topIntent.confidence);
      final isSafeIntent = topIntent.intent == ScamIntent.safe || intentRisk == RiskLevel.green;
      if (!isSafeIntent && topIntent.confidence > 0.8) {
        isAiHighlyConfidentScam = true;
      }
    }

    RiskLevel newRisk = originalRisk;
    // Strong safety context (discount <= 0.3) can reduce orange to yellow
    if (safetyDiscount <= 0.3 && originalRisk == RiskLevel.orange) {
      newRisk = RiskLevel.yellow;
    }
    // Moderate safety context (discount <= 0.5) can reduce yellow to green
    else if (safetyDiscount <= 0.5 && originalRisk == RiskLevel.yellow) {
      newRisk = RiskLevel.green;
    }

    if (isAiHighlyConfidentScam && newRisk == RiskLevel.green && originalRisk.index >= RiskLevel.yellow.index) {
      return RiskLevel.yellow; // Keep it at least yellow if AI is confident it's a scam
    }
    return newRisk;
  }

  AnalysisResult _mergeContextResult(
    AnalysisResult parsedGDetectionResult,
    RiskLevel gDetectionRiskLevel,
    RiskLevel wfsaRiskLevel,
    double wfsaScore,
  ) {
    if (wfsaRiskLevel.index > gDetectionRiskLevel.index) {
      return AnalysisResult(
        overallRiskLevel: wfsaRiskLevel,
        matches: parsedGDetectionResult.matches,
        reason: wfsaScore >= 50.0
            ? 'Cảnh báo L2 nghiêm trọng (Theo ngữ cảnh)'
            : 'Cảnh báo L2: Có phát hiện dấu hiệu lừa đảo',
        analysisLevel: AnalysisLevel.l2,
        alertEnabled:
            parsedGDetectionResult.alertEnabled ||
            wfsaRiskLevel.index > RiskLevel.green.index,
        confidence: parsedGDetectionResult.confidence,
      );
    }
    return parsedGDetectionResult.copyWith(
      overallRiskLevel: gDetectionRiskLevel,
      alertEnabled:
          parsedGDetectionResult.alertEnabled ||
          wfsaRiskLevel.index > RiskLevel.green.index,
    );
  }

  AnalysisResult _fuseIntentSuccess(
    _Luong1Success luong1Result,
    AnalysisResult result2,
    String fullText,
  ) {
    final topIntent = luong1Result.prediction;
    final intentLabel = topIntent.intent.displayName;
    final intentRisk = topIntent.intent.riskLevelForConfidence(
      topIntent.confidence,
    );
    final isSafeIntent =
        topIntent.intent == ScamIntent.safe || intentRisk == RiskLevel.green;
    final isAiDirectWinner =
        !isSafeIntent &&
        topIntent.confidence >= aiDirectConfidence &&
        luong1Result.confidenceMargin >= aiDirectMargin;
    final shouldFuseWithContext =
        !isSafeIntent &&
        result2.overallRiskLevel.index >= RiskLevel.yellow.index &&
        topIntent.confidence >= aiAssistConfidence &&
        luong1Result.confidenceMargin >= aiAssistMargin;
    final intentMatch = KeywordMatch(
      keyword: intentLabel,
      level: intentRisk,
      category:
          'Luồng 1 (AI) Độ tin cậy: ${(topIntent.confidence * 100).toInt()}% | Margin: ${(luong1Result.confidenceMargin * 100).toInt()}%',
    );

    final gDetectionOverride =
        isSafeIntent &&
        (result2.overallRiskLevel.index >= RiskLevel.red.index ||
            result2.matches.any((match) => match.category == 'Chủ đề Lừa đảo'));
    if (gDetectionOverride) {
      final overrideMatches = <KeywordMatch>[
        KeywordMatch(
          keyword: 'AI nói an toàn nhưng GDetection phát hiện rủi ro',
          level: result2.overallRiskLevel,
          category: 'Cross-validation Override',
        ),
        ...result2.matches,
      ];
      return AnalysisResult(
        overallRiskLevel: result2.overallRiskLevel,
        matches: overrideMatches,
        reason:
            result2.reason ??
            'GDetection override: Phát hiện rủi ro dù AI không nhận ra',
        analysisLevel: AnalysisLevel.l2Fused,
        alertEnabled: result2.alertEnabled,
        confidence: result2.confidence,
      );
    }

    final isAiHighConfidence =
        !isSafeIntent && topIntent.confidence >= aiHighConfidenceThreshold;
    if (isAiHighConfidence) {
      final highConfMatches = <KeywordMatch>[
        KeywordMatch(
          keyword: intentLabel.toUpperCase(),
          level: intentRisk,
          category:
              'AI >= 80% — Độ tin cậy: ${(topIntent.confidence * 100).toInt()}%',
        ),
        ...result2.matches,
      ];
      return AnalysisResult(
        overallRiskLevel: _maxRisk(intentRisk, result2.overallRiskLevel),
        matches: _distinctMatches(highConfMatches),
        reason:
            '⚠️ ${intentLabel.toUpperCase()} — ${topIntent.intent.description.toUpperCase()}',
        analysisLevel: AnalysisLevel.l2Ai,
        alertEnabled: intentRisk != RiskLevel.green,
        confidence: topIntent.confidence,
      );
    }

    if (isAiDirectWinner) {
      return AnalysisResult(
        overallRiskLevel: intentRisk,
        matches: <KeywordMatch>[intentMatch],
        reason: '⚠️ $intentLabel — ${topIntent.intent.description}',
        analysisLevel: AnalysisLevel.l2Ai,
        alertEnabled: intentRisk != RiskLevel.green,
        confidence: topIntent.confidence,
      );
    }

    if (shouldFuseWithContext) {
      double aiWeight = topIntent.confidence > 0.9 ? 0.8 : 0.6;
      double contextWeight = 1.0 - aiWeight;
      
      final ensembleConfidence = result2.confidence > 0
          ? (topIntent.confidence * aiWeight + result2.confidence * contextWeight).clamp(
              0.0,
              1.0,
            )
          : topIntent.confidence;
      return AnalysisResult(
        overallRiskLevel: _maxRisk(intentRisk, result2.overallRiskLevel),
        matches: _distinctMatches(<KeywordMatch>[
          intentMatch,
          ...result2.matches,
        ]),
        reason: '⚠️ $intentLabel — ${topIntent.intent.description}',
        analysisLevel: AnalysisLevel.l2Fused,
        alertEnabled: result2.alertEnabled || intentRisk != RiskLevel.green,
        confidence: ensembleConfidence,
      );
    }

    return result2;
  }

  AnalysisResult _fallbackResult(AnalysisResult result2, String fullText) {
    final wfsaInfo = _wfsaEngine.activeScenarioName;
    final wfsaStage = _wfsaEngine.activeScenarioStage;
    final fallbackLabel = wfsaInfo != null && wfsaStage != null
        ? 'Luồng 2 — Theo dõi: $wfsaInfo (Giai đoạn $wfsaStage/4)'
        : 'Sử dụng Luồng 2 (GDetection & WFSA)';
    return AnalysisResult(
      overallRiskLevel: result2.overallRiskLevel,
      matches: <KeywordMatch>[
        KeywordMatch(
          keyword: fallbackLabel,
          level: RiskLevel.green,
          category: 'Analysis Fallback',
        ),
        ...result2.matches,
      ],
      reason: result2.reason ?? 'Cảnh báo ngữ cảnh (Luồng 2)',
      analysisLevel: AnalysisLevel.l2,
      alertEnabled: result2.alertEnabled,
      confidence: result2.confidence,
    );
  }

  RiskLevel _maxRisk(RiskLevel left, RiskLevel right) {
    return left.index >= right.index ? left : right;
  }

  List<KeywordMatch> _distinctMatches(List<KeywordMatch> matches) {
    return <KeywordMatch>{...matches}.toList();
  }
}

sealed class _Luong1Result {
  const _Luong1Result();
}

class _Luong1Success extends _Luong1Result {
  const _Luong1Success(this.prediction, this.confidenceMargin);

  final IntentPrediction prediction;
  final double confidenceMargin;
}

class _Luong1Fallback extends _Luong1Result {
  const _Luong1Fallback();
}
