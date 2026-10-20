import 'dart:async' show Completer;
import 'dart:math' as math;

import '../analysis_config.dart';
import '../analysis_level.dart';
import '../analysis_result.dart';
import '../analyzer.dart';
import '../common/text_normalizer.dart';
import '../health_check.dart';
import '../../core/risk_level.dart';
import '../../core/logger.dart';
import '../../core/asset_loader.dart';
import '../../core/noop_asset_loader.dart';
import 'g_detection/g_detection_engine.dart';
import 'intent/intent_classifier.dart';
import 'intent/intent_classifier_factory.dart';
import 'intent/intent_output_mapper.dart';
import 'intent/scam_intent.dart';
import '../l3/core/response_cache.dart';
import 'l2_initialization.dart';
import 'l2_result.dart';
import 'safety/safety_filter.dart';
import 'wfsa/scam_graph_builder.dart';
import 'wfsa/wfsa_engine.dart';

class L2Analyzer implements Analyzer {
  L2Analyzer({
    this.config = const L2Config(),
    AssetLoader? assetLoader,
    AppLogger? logger,
    GDetectionEngine? gDetectionEngine,
    IntentClassifier? intentClassifier,
    WfsaEngine? wfsaEngine,
    ResponseCache<AnalysisResult>? cache,
  }) : _assetLoader = assetLoader ?? const NoopAssetLoader(),
       _logger = logger,
       _gDetectionEngine =
           gDetectionEngine ??
           GDetectionEngine(
             assetLoader: assetLoader ?? const NoopAssetLoader(),
             logger: logger,
           ),
       _intentClassifier =
           intentClassifier ??
           createPlatformIntentClassifier(
             assetLoader: assetLoader ?? const NoopAssetLoader(),
             logger: logger,
           ),
       _wfsaEngine =
           wfsaEngine ?? WfsaEngine(ScamGraphBuilder.buildDefaultGraphs()),
       _cache = cache ?? ResponseCache<AnalysisResult>() {
    _initialization = L2Initialization(
      gDetectionEngine: _gDetectionEngine,
      intentClassifier: _intentClassifier,
      assetLoader: _assetLoader,
      logger: _logger,
    );
  }

  final L2Config config;
  final ResponseCache<AnalysisResult> _cache;
  final AssetLoader _assetLoader;
  final AppLogger? _logger;
  late final L2Initialization _initialization;

  double get aiHighConfidenceThreshold => config.aiHighConfidenceThreshold;
  double get aiDirectConfidence => config.aiDirectConfidence;
  double get aiDirectMargin => config.aiDirectMargin;
  double get aiAssistConfidence => config.aiAssistConfidence;
  double get aiAssistMargin => config.aiAssistMargin;

  double get _ensembleHighConfCutoff => config.ensembleHighConfCutoff;
  double get _ensembleHighConfAiWeight => config.ensembleHighConfAiWeight;
  double get _ensembleDefaultAiWeight => config.ensembleDefaultAiWeight;

  static const String _confirmedScamTopicMarker = 'Chủ đề Lừa đảo';

  Future<void> _analysisMutex = Future.value();

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
  Future<void> initialize() => _initialization.initialize();

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
    _analysisGeneration++;

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

  @override
  void dispose() {
    _intentClassifier.close();
    _gDetectionEngine.dispose();
    _initialization.invalidate();
  }

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

    final textToAnalyze = fullText;

    final prevMutex = _analysisMutex;
    final completer = Completer<void>();
    _analysisMutex = completer.future;

    try {
      final myGeneration = ++_analysisGeneration;

      await prevMutex.timeout(
        const Duration(seconds: 5),
        onTimeout: () {
          _logger?.warning(
            'Timeout waiting for previous analysis lock — force continuing',
          );
        },
      );

      if (myGeneration != _analysisGeneration) {
        return _lastResult;
      }

      final normalizedKey = _normalizeForCache(fullText);
      final cached = _cache.get(normalizedKey);
      if (cached != null) {
        _lastResult = cached;
        return cached;
      }

      final gResult = await _gDetectionEngine.performFullAnalysis(
        textToAnalyze,
      );
      final parsedGDetectionResult = L2ResultParser.parse(gResult);

      final isLongText = textToAnalyze.length > 80;
      final hasGDetectionRisk =
          parsedGDetectionResult.overallRiskLevel.index >=
          RiskLevel.yellow.index;

      _Luong1Result luong1Result = const _Luong1Fallback();
      if (isLongText || hasGDetectionRisk) {
        luong1Result = await _runIntentFlow(textToAnalyze);
      }

      final intentForWfsa = luong1Result is _Luong1Success
          ? <IntentPrediction>[luong1Result.prediction]
          : const <IntentPrediction>[];
      var wfsaScore = _wfsaEngine.analyzeIncremental(
        textToAnalyze,
        intentForWfsa,
      );

      final normalizedForSafety = TextNormalizer.normalize(
        fullText,
        applySlang: true,
        noiseMode: NoiseMode.space,
      );
      final safetyDiscount = SafetyFilter.calculateSafetyDiscountNormalized(
        normalizedForSafety,
      );
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

      if (myGeneration == _analysisGeneration) {
        _processedTextLength = fullText.length;
        _lastResult = result;
        _cache.put(normalizedKey, result, riskLevel: result.overallRiskLevel);
      }
      return result;
    } finally {
      if (!completer.isCompleted) {
        completer.complete();
      }
    }
  }

  Future<_Luong1Result> _runIntentFlow(String fullText) async {
    if (!_intentClassifier.isReady) {
      return const _Luong1Fallback();
    }
    try {
      var intentPredictions = await _intentClassifier.predictIntent(fullText);
      if (intentPredictions.isEmpty) return const _Luong1Fallback();

      final rawConfidences = intentPredictions
          .map((p) => p.confidence)
          .toList();

      final approxLogits = rawConfidences.map((p) {
        final clamped = p.clamp(1e-7, 1.0 - 1e-7);
        return math.log(clamped / (1.0 - clamped));
      }).toList();
      final calibrated = IntentOutputMapper.plattCalibrate(approxLogits);
      intentPredictions = List.generate(intentPredictions.length, (i) {
        return IntentPrediction(
          intent: intentPredictions[i].intent,
          confidence: calibrated[i],
        );
      }).toList();

      intentPredictions.sort((a, b) => b.confidence.compareTo(a.confidence));
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
    } on Object catch (e, st) {
      _logger?.warning('Intent flow failed, falling back: $e', e, st);
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
      final intentRisk = topIntent.intent.riskLevelForConfidence(
        topIntent.confidence,
      );
      final isSafeIntent =
          topIntent.intent == ScamIntent.safe || intentRisk == RiskLevel.green;
      if (!isSafeIntent && topIntent.confidence > 0.8) {
        isAiHighlyConfidentScam = true;
      }
    }

    RiskLevel newRisk = originalRisk;

    if (safetyDiscount <= 0.3 && originalRisk == RiskLevel.orange) {
      newRisk = RiskLevel.yellow;
    } else if (safetyDiscount <= 0.5 && originalRisk == RiskLevel.yellow) {
      newRisk = RiskLevel.green;
    }

    if (isAiHighlyConfidentScam &&
        newRisk == RiskLevel.green &&
        originalRisk.index >= RiskLevel.yellow.index) {
      return RiskLevel.yellow;
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
    final fusionCtx = _IntentFusionContext(
      prediction: luong1Result.prediction,
      confidenceMargin: luong1Result.confidenceMargin,
      result2: result2,
    );

    return _tryCrossValidationOverride(fusionCtx) ??
        _tryContextPriorityOverride(fusionCtx) ??
        _tryAiHighConfidence(fusionCtx) ??
        _tryAiDirectWinner(fusionCtx) ??
        _tryFuseWithContext(fusionCtx) ??
        result2;
  }

  AnalysisResult? _tryCrossValidationOverride(_IntentFusionContext ctx) {
    final isSafeIntent =
        ctx.prediction.intent == ScamIntent.safe ||
        ctx.intentRisk == RiskLevel.green;
    if (!isSafeIntent) return null;

    final hasStrongRisk =
        ctx.result2.overallRiskLevel.index >= RiskLevel.red.index ||
        ctx.result2.matches.any(
          (match) => match.category == _confirmedScamTopicMarker,
        );
    if (!hasStrongRisk) return null;

    final overrideMatches = <KeywordMatch>[
      KeywordMatch(
        keyword: 'AI nói an toàn nhưng GDetection phát hiện rủi ro',
        level: ctx.result2.overallRiskLevel,
        category: 'Cross-validation Override',
      ),
      ...ctx.result2.matches,
    ];
    return AnalysisResult(
      overallRiskLevel: ctx.result2.overallRiskLevel,
      matches: overrideMatches,
      reason:
          ctx.result2.reason ??
          'GDetection override: Phát hiện rủi ro dù AI không nhận ra',
      analysisLevel: AnalysisLevel.l2Fused,
      alertEnabled: ctx.result2.alertEnabled,
      confidence: ctx.result2.confidence,
    );
  }

  AnalysisResult? _tryContextPriorityOverride(_IntentFusionContext ctx) {
    final wfsaIntent = _wfsaEngine.activeScenarioIntent;
    if (wfsaIntent == null) return null;

    if (_wfsaEngine.currentRiskScore < 50.0) return null;

    if (ctx.prediction.intent == wfsaIntent) return null;

    final isSafeIntent =
        ctx.prediction.intent == ScamIntent.safe ||
        ctx.intentRisk == RiskLevel.green;
    if (isSafeIntent) return null;

    final wfsaLabel = wfsaIntent.displayName;
    final wfsaRisk = wfsaIntent.baseRiskLevel;
    final aiLabel = ctx.intentLabel;
    final mergedRisk = _maxRisk(wfsaRisk, ctx.result2.overallRiskLevel);

    final overrideMatches = <KeywordMatch>[
      KeywordMatch(
        keyword: wfsaLabel,
        level: mergedRisk,
        category:
            'Context ưu tiên (WFSA ≥ 50) — AI đề xuất: $aiLabel (${(ctx.prediction.confidence * 100).toInt()}%)',
      ),
      ...ctx.result2.matches,
    ];
    return AnalysisResult(
      overallRiskLevel: _maxRisk(mergedRisk, ctx.intentRisk),
      matches: _distinctMatches(overrideMatches),
      reason:
          '⚠️ ${wfsaLabel.toUpperCase()} — ${wfsaIntent.description.toUpperCase()} '
          '(Context ưu tiên, AI đề xuất: ${aiLabel.toUpperCase()})',
      analysisLevel: AnalysisLevel.l2Fused,
      alertEnabled: true,
      confidence: ctx.prediction.confidence,
    );
  }

  AnalysisResult? _tryAiHighConfidence(_IntentFusionContext ctx) {
    final isSafeIntent =
        ctx.prediction.intent == ScamIntent.safe ||
        ctx.intentRisk == RiskLevel.green;
    if (isSafeIntent) return null;
    if (ctx.prediction.confidence < aiHighConfidenceThreshold) return null;

    final highConfMatches = <KeywordMatch>[
      KeywordMatch(
        keyword: ctx.intentLabel.toUpperCase(),
        level: ctx.intentRisk,
        category:
            'AI >= 80% — Độ tin cậy: ${(ctx.prediction.confidence * 100).toInt()}%',
      ),
      ...ctx.result2.matches,
    ];
    return AnalysisResult(
      overallRiskLevel: _maxRisk(ctx.intentRisk, ctx.result2.overallRiskLevel),
      matches: _distinctMatches(highConfMatches),
      reason:
          '⚠️ ${ctx.intentLabel.toUpperCase()} — ${ctx.prediction.intent.description.toUpperCase()}',
      analysisLevel: AnalysisLevel.l2Ai,
      alertEnabled: ctx.intentRisk != RiskLevel.green,
      confidence: ctx.prediction.confidence,
    );
  }

  AnalysisResult? _tryAiDirectWinner(_IntentFusionContext ctx) {
    final isSafeIntent =
        ctx.prediction.intent == ScamIntent.safe ||
        ctx.intentRisk == RiskLevel.green;
    if (isSafeIntent) return null;
    final isAiDirectWinner =
        ctx.prediction.confidence >= aiDirectConfidence &&
        ctx.confidenceMargin >= aiDirectMargin;
    if (!isAiDirectWinner) return null;

    return AnalysisResult(
      overallRiskLevel: ctx.intentRisk,
      matches: <KeywordMatch>[ctx.intentMatch],
      reason: '⚠️ ${ctx.intentLabel} — ${ctx.prediction.intent.description}',
      analysisLevel: AnalysisLevel.l2Ai,
      alertEnabled: ctx.intentRisk != RiskLevel.green,
      confidence: ctx.prediction.confidence,
    );
  }

  AnalysisResult? _tryFuseWithContext(_IntentFusionContext ctx) {
    final isSafeIntent =
        ctx.prediction.intent == ScamIntent.safe ||
        ctx.intentRisk == RiskLevel.green;
    if (isSafeIntent) return null;
    final shouldFuse =
        ctx.result2.overallRiskLevel.index >= RiskLevel.yellow.index &&
        ctx.prediction.confidence >= aiAssistConfidence &&
        ctx.confidenceMargin >= aiAssistMargin;
    if (!shouldFuse) return null;

    final aiWeight = ctx.prediction.confidence > _ensembleHighConfCutoff
        ? _ensembleHighConfAiWeight
        : _ensembleDefaultAiWeight;
    final contextWeight = 1.0 - aiWeight;
    final ensembleConfidence = ctx.result2.confidence > 0
        ? (ctx.prediction.confidence * aiWeight +
                  ctx.result2.confidence * contextWeight)
              .clamp(0.0, 1.0)
        : ctx.prediction.confidence;
    return AnalysisResult(
      overallRiskLevel: _maxRisk(ctx.intentRisk, ctx.result2.overallRiskLevel),
      matches: _distinctMatches(<KeywordMatch>[
        ctx.intentMatch,
        ...ctx.result2.matches,
      ]),
      reason: '⚠️ ${ctx.intentLabel} — ${ctx.prediction.intent.description}',
      analysisLevel: AnalysisLevel.l2Fused,
      alertEnabled:
          ctx.result2.alertEnabled || ctx.intentRisk != RiskLevel.green,
      confidence: ensembleConfidence,
    );
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

  String _normalizeForCache(String text) {
    return text
        .toLowerCase()
        .replaceAll(RegExp(r'[^\p{L}\p{N}\s]', unicode: true), '')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
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

class _IntentFusionContext {
  _IntentFusionContext({
    required this.prediction,
    required this.confidenceMargin,
    required this.result2,
  }) : intentRisk = prediction.intent.riskLevelForConfidence(
         prediction.confidence,
       ),
       intentLabel = prediction.intent.displayName,
       intentMatch = KeywordMatch(
         keyword: prediction.intent.displayName,
         level: prediction.intent.riskLevelForConfidence(prediction.confidence),
         category:
             'Luồng 1 (AI) Độ tin cậy: ${(prediction.confidence * 100).toInt()}% | Margin: ${(confidenceMargin * 100).toInt()}%',
       );

  final IntentPrediction prediction;
  final double confidenceMargin;
  final AnalysisResult result2;
  final RiskLevel intentRisk;
  final String intentLabel;
  final KeywordMatch intentMatch;
}
