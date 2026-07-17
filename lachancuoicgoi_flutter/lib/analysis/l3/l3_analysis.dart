import 'dart:async';

import 'package:flutter/foundation.dart' show visibleForTesting;

import '../analysis_level.dart';
import '../analysis_result.dart';
import '../analyzer.dart';
import '../health_check.dart';
import '../../core/risk_level.dart';
import '../../core/asset_loader.dart';
import '../../core/logger.dart';
import 'core/api_key_provider.dart';
import 'core/circuit_breaker.dart';
import 'core/confidence_calculator.dart';
import 'core/gemini_chat_session.dart';
import 'core/gemini_client.dart';
import 'core/gemini_config.dart';
import 'core/gemini_metrics.dart';
import 'core/key_health_tracker.dart';
import 'core/l3_response_parser.dart';
import 'core/pii_stripper.dart';
import 'core/proxy_l3_client.dart';
import 'core/response_cache.dart';
import 'core/risk_deescalation.dart';
import 'prompt_builder.dart';

class L3Analyzer implements Analyzer {
  factory L3Analyzer({
    AssetLoader? assetLoader,
    AppLogger? logger,
    ApiKeyProvider? apiKeyProvider,
    KeyHealthTracker? keyHealthTracker,
    GeminiClient? geminiClient,
    GeminiChatSession Function()? sessionFactory,
    ResponseCache<AnalysisResult>? cache,
    CircuitBreaker? circuitBreaker,
    L3ResponseParser? responseParser,
    RiskDeescalationMachine? deescalationMachine,
  }) {
    final provider =
        apiKeyProvider ??
        EnvironmentApiKeyProvider(assetLoader: assetLoader, logger: logger);
    final tracker = keyHealthTracker ?? KeyHealthTracker(provider);

    // Phase 2 (P2-SEC): When L3_BACKEND_URL is set via dart-define, route
    // all L3 inference through a backend proxy instead of calling Gemini
    // directly with keys bundled in the APK. When empty (default), the app
    // uses Gemini directly with keys from env.json — this is insecure for
    // public release but works for development/testing without a server.
    //
    // To enable proxy mode:
    //   flutter build apk --dart-define=L3_BACKEND_URL=https://your-api.com
    final client = geminiClient ?? _createDefaultClient(provider, tracker);
    return L3Analyzer._(
      apiKeyProvider: provider,
      keyHealthTracker: tracker,
      geminiClient: client,
      sessionFactory: sessionFactory,
      cache: cache ?? ResponseCache<AnalysisResult>(),
      circuitBreaker: circuitBreaker ?? CircuitBreaker(),
      responseParser: responseParser ?? L3ResponseParser(),
      deescalationMachine: deescalationMachine ?? RiskDeescalationMachine(),
    );
  }

  /// Phase 2 (P2-SEC): Creates the default [GeminiClient].
  ///
  /// When `L3_BACKEND_URL` is set via dart-define, all L3 requests are routed
  /// through a backend proxy. The API keys from [provider] are still tracked
  /// for health/circuit-breaker purposes but are NOT sent to the proxy — the
  /// server holds its own keys.
  ///
  /// When `L3_BACKEND_URL` is empty (default), the app calls Gemini directly
  /// with keys from `env.json`. This is **insecure for public release** (keys
  /// are extractable from the APK) but works for development without a server.
  static GeminiClient _createDefaultClient(
    ApiKeyProvider provider,
    KeyHealthTracker tracker,
  ) {
    const backendUrl = String.fromEnvironment(
      'L3_BACKEND_URL',
      defaultValue: '',
    );
    if (backendUrl.isEmpty) {
      // Default mode: direct Gemini calls with bundled keys.
      return GeminiClient(
        apiKeyProvider: provider,
        config: GeminiConfig.forAnalysis(),
        keyHealthTracker: tracker,
      );
    }
    // Proxy mode: route through backend. Keys are NOT used for the request.
    return GeminiClient(
      apiKeyProvider: provider,
      config: GeminiConfig.forAnalysis(),
      keyHealthTracker: tracker,
      requestExecutor: proxyExecutorFrom(backendUrl),
    );
  }

  L3Analyzer._({
    required ApiKeyProvider apiKeyProvider,
    required KeyHealthTracker keyHealthTracker,
    required GeminiClient geminiClient,
    required GeminiChatSession Function()? sessionFactory,
    required ResponseCache<AnalysisResult> cache,
    required CircuitBreaker circuitBreaker,
    required L3ResponseParser responseParser,
    required RiskDeescalationMachine deescalationMachine,
  })  : _apiKeyProvider = apiKeyProvider,
        _keyHealthTracker = keyHealthTracker,
        _client = geminiClient,
        _sessionFactory = sessionFactory,
        _cache = cache,
        _circuitBreaker = circuitBreaker,
        _responseParser = responseParser,
        _deescalation = deescalationMachine;

  static const int _minWords = 3;
  static const int _minIncrementalChars = 60;
  static const int _maxIncrementalChars = 250;

  final ApiKeyProvider _apiKeyProvider;
  final KeyHealthTracker _keyHealthTracker;
  final GeminiClient _client;
  final GeminiChatSession Function()? _sessionFactory;
  final ResponseCache<AnalysisResult> _cache;

  // Extracted sub-components
  final CircuitBreaker _circuitBreaker;
  final L3ResponseParser _responseParser;
  final RiskDeescalationMachine _deescalation;

  GeminiChatSession? _activeSession;
  bool _isAnalyzing = false;
  int _processedTextLength = 0;
  // BUG-L3-INFLIGHT-CIRCUIT-BLOCK fix: Generation counter to prevent stale
  // in-flight results from writing to _lastResult after closeSession() is called.
  // Previously: user exits monitoring mid-Gemini-call (up to 25s) → closeSession
  // sets _activeSession=null but _isAnalyzing=true stays. When in-flight resolves,
  // it writes _lastResult from OLD session, leaking PII into new session.
  int _sessionGeneration = 0;
  AnalysisResult _lastResult = const AnalysisResult(
    overallRiskLevel: RiskLevel.green,
    matches: <KeywordMatch>[],
    analysisLevel: AnalysisLevel.l3,
  );

  @override
  AnalysisLevel get level => AnalysisLevel.l3;

  @override
  Future<void> initialize() async {
    final provider = _apiKeyProvider;
    if (provider is EnvironmentApiKeyProvider) {
      await provider.ensureLoaded();
    }
  }

  @override
  bool get isReady {
    return _apiKeyProvider.getApiKeys().isNotEmpty &&
        _keyHealthTracker.hasActiveKeys();
  }

  /// Whether a Gemini chat session is currently active.
  ///
  /// BUG FIX (Bug #1): Previously the coordinator decided whether to create
  /// a new session by checking [_processedTextLength] == 0. But short-text
  /// incremental analysis returns early WITHOUT updating
  /// `_processedTextLength`, so the next call would see length=0 again and
  /// recreate the session — discarding all chat history. Now callers should
  /// check [hasActiveSession] instead.
  bool get hasActiveSession => _activeSession != null;

  @override
  void resetSession() {
    closeSession();
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
    closeSession();
  }

  @override
  HealthReport healthCheck() {
    final hasApiKey = _apiKeyProvider.getApiKeys().isNotEmpty;
    final summary = _keyHealthTracker.getHealthSummary();
    final totalKeys = summary.length;
    final activeCount = summary
        .where((item) => item.status == KeyStatus.active)
        .length;
    final cooldownCount = summary
        .where((item) => item.status == KeyStatus.cooldown)
        .length;
    final exhaustedCount = summary
        .where((item) => item.status == KeyStatus.exhausted)
        .length;
    final isRecentError = _circuitBreaker.lastErrorTime != null &&
        DateTime.now().difference(_circuitBreaker.lastErrorTime!) <
            const Duration(minutes: 1);

    if (!hasApiKey) {
      return const HealthReport(
        status: HealthStatus.down,
        component: 'L3',
        message: 'API key không hợp lệ hoặc chưa cấu hình.',
      );
    }
    if (totalKeys > 0 && exhaustedCount == totalKeys) {
      return HealthReport(
        status: HealthStatus.down,
        component: 'L3',
        message:
            'Tất cả $totalKeys keys đều INVALID/REVOKED. Cần thay thế API keys.',
      );
    }
    if (activeCount == 0 && cooldownCount > 0) {
      return HealthReport(
        status: HealthStatus.degraded,
        component: 'L3',
        message:
            '$cooldownCount/$totalKeys keys hết quota (cooldown đến 00:00). $exhaustedCount keys invalid.',
      );
    }
    if (_circuitBreaker.consecutiveErrors >= 3) {
      return HealthReport(
        status: HealthStatus.degraded,
        component: 'L3',
        message:
            '${_circuitBreaker.consecutiveErrors} lỗi liên tiếp. $activeCount/$totalKeys keys ACTIVE.',
      );
    }
    if (isRecentError) {
      return HealthReport(
        status: HealthStatus.degraded,
        component: 'L3',
        message:
            'Gần đây có lỗi (consecutiveErrors=${_circuitBreaker.consecutiveErrors}, errorRate=${_circuitBreaker.getErrorRateString()}). $activeCount/$totalKeys keys ACTIVE.',
      );
    }
    return HealthReport(
      status: HealthStatus.healthy,
      component: 'L3',
      message:
          '$activeCount/$totalKeys keys ACTIVE, $cooldownCount cooldown, $exhaustedCount invalid.',
    );
  }

  Future<AnalysisResult> analyze(String text) async {
    if (_isAnalyzing) {
      return _lastResult;
    }

    if (_circuitBreaker.isOpen) {
      return const AnalysisResult(
        overallRiskLevel: RiskLevel.green,
        matches: <KeywordMatch>[],
        reason: 'L3 đang tạm ngưng do lỗi mạng (Circuit Breaker)',
        analysisLevel: AnalysisLevel.l3,
      );
    }

    // BUG-L3-INFLIGHT-CIRCUIT-BLOCK fix: Capture generation at call start.
    final myGeneration = _sessionGeneration;
    _isAnalyzing = true;
    try {
      final validationError = _validateInput(text);
      if (validationError != null) {
        // Only write if generation hasn't changed (session not closed mid-flight).
        if (myGeneration == _sessionGeneration) {
          _lastResult = validationError;
        }
        return validationError;
      }

      final normalizedKey = _normalizeForCache(text);
      final cached = _cache.get(normalizedKey);
      if (cached != null) {
        GeminiMetrics.instance.recordCacheHit();
        if (myGeneration == _sessionGeneration) {
          _lastResult = cached;
        }
        return cached;
      }
      GeminiMetrics.instance.recordCacheMiss();

      final redaction = PIIStripper.redactPII(text);
      final prompt = PromptBuilder.buildAnalysisPrompt(redaction.redactedText);
      final result = await _client.query<AnalysisResult>(
        prompt,
        (responseText, modelName) => parseResponse(
          PIIStripper.restorePII(responseText, redaction.tokensMap),
          modelName,
          text,
        ),
      );
      return result.fold(
        onSuccess: (analysisResult) {
          _cache.put(
            normalizedKey,
            analysisResult,
            riskLevel: analysisResult.overallRiskLevel,
          );
          _circuitBreaker.recordSuccess();
          // Only write if generation hasn't changed.
          if (myGeneration == _sessionGeneration) {
            _lastResult = analysisResult;
          }
          return analysisResult;
        },
        onFailure: (error, _) {
          // BUG-L3-CIRCUIT-RACE fix: Do NOT record failure in L3Analyzer's
          // circuit breaker if the error is "Circuit breaker open" from
          // GeminiClient's own circuit breaker. GeminiClient already tracks
          // failures and opens its circuit after 5 consecutive fails (30s cooldown).
          // Recording this as an L3Analyzer failure causes double-tripping:
          // L3 would trip for 2 minutes AFTER GeminiClient's 30s cooldown ends,
          // resulting in ~2.5 minutes total unavailability instead of the intended 30s.
          final errorString = error.toString();
          if (!errorString.contains('Circuit breaker open')) {
            _circuitBreaker.recordFailure();
          }
          final analysisResult = AnalysisResult(
            overallRiskLevel: RiskLevel.green,
            matches: const <KeywordMatch>[],
            reason: 'API Error: $error',
            analysisLevel: AnalysisLevel.l3,
            isError: true,
          );
          // Only write if generation hasn't changed.
          if (myGeneration == _sessionGeneration) {
            _lastResult = analysisResult;
          }
          return analysisResult;
        },
      );
    } finally {
      _isAnalyzing = false;
    }
  }

  void createSession({int initialProcessedTextLength = 0}) {
    _activeSession?.close();
    _activeSession =
        _sessionFactory?.call() ??
        GeminiChatSession(
          apiKeyProvider: _apiKeyProvider,
          config: GeminiConfig.forAnalysis(),
          keyHealthTracker: _keyHealthTracker,
        );
    _processedTextLength = initialProcessedTextLength < 0
        ? 0
        : initialProcessedTextLength;
    _deescalation.reset();
  }

  Future<AnalysisResult?> analyzeIncremental(String fullText) async {
    if (_isAnalyzing) return null;

    if (_circuitBreaker.isOpen) {
      return null;
    }

    // BUG-L3-INFLIGHT-CIRCUIT-BLOCK fix: Capture generation at call start.
    final myGeneration = _sessionGeneration;
    _isAnalyzing = true;
    try {
      final session = _activeSession;
      if (session == null) {
        return null;
      }
      final newTextLength = fullText.length - _processedTextLength;
      if (newTextLength <= 0) {
        return _lastResult;
      }
      final newText = fullText.substring(_processedTextLength);
      if (newTextLength < _minIncrementalChars) {
        return null;
      }
      if (!_responseParser.isSentenceBoundary(newText) &&
          newTextLength < _maxIncrementalChars) {
        return null;
      }

      final redaction = PIIStripper.redactPII(newText);
      final prompt = PromptBuilder.buildIncrementalPrompt(
        redaction.redactedText,
        _processedTextLength == 0,
      );
      var result = await session.sendMessage<AnalysisResult>(
        prompt,
        (responseText, modelName) => parseResponse(
          PIIStripper.restorePII(responseText, redaction.tokensMap),
          modelName,
          newText,
        ),
      );

      // Local retry once for transient network or timeout errors
      bool isTransient = false;
      result.fold(
        onSuccess: (_) {},
        onFailure: (error, _) {
          final errStr = error.toString().toLowerCase();
          if (error is TimeoutException ||
              errStr.contains('timeout') ||
              errStr.contains('socket') ||
              errStr.contains('network') ||
              errStr.contains('connection') ||
              errStr.contains('host')) {
            isTransient = true;
          }
        },
      );

      if (isTransient) {
        // BUG-L3-RETRY-DELAY-OVERFLOW fix: Exponential Backoff with Jitter
        // Previously: baseDelay could reach (1 << 5) * 1000 = 32000ms (32s),
        // but AnalysisCoordinator._analyzeParallel times out L3 after 800ms.
        // A 32s delay means the retry is guaranteed to be cut by the timeout,
        // wasting Gemini quota and leaving _isAnalyzing=true for 32s (blocking
        // all subsequent calls). Cap at 1500ms to stay under coordinator timeout.
        final random = DateTime.now().microsecond % 1000;
        final baseDelay =
            (1 << _circuitBreaker.consecutiveErrors.clamp(0, 5)) * 1000;
        final delayMs = (baseDelay + random).clamp(100, 1500);
        await Future<void>.delayed(Duration(milliseconds: delayMs));
        result = await session.sendMessage<AnalysisResult>(
          prompt,
          (responseText, modelName) => parseResponse(
            PIIStripper.restorePII(responseText, redaction.tokensMap),
            modelName,
            newText,
          ),
        );
      }

      return result.fold(
        onSuccess: (analysisResult) {
          // Only write if generation hasn't changed (session not closed mid-flight).
          if (myGeneration == _sessionGeneration) {
            _processedTextLength = fullText.length;
            _lastResult = analysisResult;
          }
          _circuitBreaker.recordSuccess();
          return analysisResult;
        },
        onFailure: (error, _) {
          // BUG-L3-CIRCUIT-RACE fix: Same logic as in analyze() — skip
          // recording failure if error comes from GeminiClient's circuit breaker.
          final errorString = error.toString();
          if (!errorString.contains('Circuit breaker open')) {
            _circuitBreaker.recordFailure();
          }
          final analysisResult = AnalysisResult(
            overallRiskLevel: RiskLevel.green,
            matches: const <KeywordMatch>[],
            reason: 'Lỗi phân tích L3: $error',
            analysisLevel: AnalysisLevel.l3,
            isError: true,
          );
          // Only write if generation hasn't changed.
          if (myGeneration == _sessionGeneration) {
            _lastResult = analysisResult;
          }
          return analysisResult;
        },
      );
    } finally {
      _isAnalyzing = false;
    }
  }

  void closeSession({bool resetProgress = true}) {
    // BUG-L3-INFLIGHT-CIRCUIT-BLOCK fix: Increment generation to invalidate
    // any in-flight analyze() calls. When user exits monitoring mid-Gemini-call,
    // the call may still complete after 25s and try to write _lastResult.
    // Incrementing generation here ensures those stale writes are ignored.
    _sessionGeneration++;
    _activeSession?.close();
    _activeSession = null;
    if (resetProgress) {
      _processedTextLength = 0;
    }
    _deescalation.reset();
  }

  MetricsSnapshot getMetrics() => GeminiMetrics.instance.getSnapshot();

  /// Parses the raw LLM response text into an [AnalysisResult].
  ///
  /// Delegates to [L3ResponseParser] for JSON extraction and risk level
  /// parsing, and to [RiskDeescalationMachine] for de-escalation logic.
  AnalysisResult parseResponse(
    String responseText,
    String modelName, [
    String? originalText,
  ]) {
    final response = _responseParser.parse(responseText);
    final riskLevel = _responseParser.parseRiskLevel(
      response.level,
      response.reason,
    );

    final finalRiskLevel = _deescalation.process(riskLevel);

    final reason = _responseParser.assembleReason(response);

    final matches = (response.label ?? '').trim().isNotEmpty
        ? <KeywordMatch>[
            KeywordMatch(
              keyword: response.label!.trim(),
              level: finalRiskLevel,
              category: 'L3 (Gemini)',
            ),
          ]
        : const <KeywordMatch>[];

    return AnalysisResult(
      overallRiskLevel: finalRiskLevel,
      matches: matches,
      reason: reason,
      analysisLevel: AnalysisLevel.l3,
      confidence: calculateConfidence(response, originalText),
      modelName: modelName,
    );
  }

  AnalysisResult? _validateInput(String text) {
    final trimmed = text.trim();
    if (trimmed.isEmpty) {
      return const AnalysisResult(
        overallRiskLevel: RiskLevel.green,
        matches: <KeywordMatch>[],
        reason: 'Văn bản trống',
        analysisLevel: AnalysisLevel.l3,
      );
    }
    final wordCount = trimmed
        .split(RegExp(r'\s+'))
        .where((part) => part.isNotEmpty)
        .length;
    if (wordCount < _minWords) {
      return const AnalysisResult(
        overallRiskLevel: RiskLevel.green,
        matches: <KeywordMatch>[],
        reason: 'Nội dung quá ngắn (cần ít nhất $_minWords từ)',
        analysisLevel: AnalysisLevel.l3,
      );
    }
    return null;
  }

  String _normalizeForCache(String text) {
    // BUG-L2-CACHE-NORMALIZED-KEY fix: Use Unicode-aware regex to preserve
    // Vietnamese diacritics. Previously \w (ASCII [A-Za-z0-9_]) stripped
    // all accents: "công an" → "cng an", "cộng án" → "cng n" → collision.
    // Now \p{L} matches any Unicode letter, \p{N} matches any number.
    return text
        .toLowerCase()
        .replaceAll(RegExp(r'[^\p{L}\p{N}\s]', unicode: true), '')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
  }

  // Backward-compatible accessors for tests that inspect internal state.
  @visibleForTesting
  int get consecutiveErrors => _circuitBreaker.consecutiveErrors;

  @visibleForTesting
  String get errorRateString => _circuitBreaker.getErrorRateString();
}
