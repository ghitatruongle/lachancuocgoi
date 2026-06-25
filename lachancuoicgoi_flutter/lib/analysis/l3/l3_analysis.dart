import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;

import '../analysis_level.dart';
import '../analysis_result.dart';
import '../analyzer.dart';
import '../health_check.dart';
import '../../core/risk_level.dart';
import '../../core/asset_loader.dart';
import '../../core/logger.dart';
import 'core/api_key_provider.dart';
import 'core/gemini_chat_session.dart';
import 'core/gemini_client.dart';
import 'core/gemini_config.dart';
import 'core/gemini_metrics.dart';
import 'core/gemini_response.dart';
import 'core/key_health_tracker.dart';
import 'core/pii_stripper.dart';
import 'core/response_cache.dart';
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
  }) {
    final provider =
        apiKeyProvider ??
        EnvironmentApiKeyProvider(assetLoader: assetLoader, logger: logger);
    final tracker = keyHealthTracker ?? KeyHealthTracker(provider);
    final client =
        geminiClient ??
        GeminiClient(
          apiKeyProvider: provider,
          config: GeminiConfig.forAnalysis(),
          keyHealthTracker: tracker,
        );
    return L3Analyzer._(
      apiKeyProvider: provider,
      keyHealthTracker: tracker,
      geminiClient: client,
      sessionFactory: sessionFactory,
      cache: cache ?? ResponseCache<AnalysisResult>(),
    );
  }

  L3Analyzer._({
    required ApiKeyProvider apiKeyProvider,
    required KeyHealthTracker keyHealthTracker,
    required GeminiClient geminiClient,
    required GeminiChatSession Function()? sessionFactory,
    required ResponseCache<AnalysisResult> cache,
  }) : _apiKeyProvider = apiKeyProvider,
       _keyHealthTracker = keyHealthTracker,
       _client = geminiClient,
       _sessionFactory = sessionFactory,
       _cache = cache;

  static const int _minWords = 3;
  static const int _minIncrementalChars = 60;
  static const int _maxIncrementalChars = 250;

  final ApiKeyProvider _apiKeyProvider;
  final KeyHealthTracker _keyHealthTracker;
  final GeminiClient _client;
  final GeminiChatSession Function()? _sessionFactory;
  final ResponseCache<AnalysisResult> _cache;

  GeminiChatSession? _activeSession;
  bool _isAnalyzing = false;
  int _processedTextLength = 0;
  RiskLevel _maxRiskLevel = RiskLevel.green;
  int _consecutiveGreenCount = 0;
  DateTime? _lastErrorTime;
  DateTime? _circuitBreakerUntil;
  int _consecutiveErrors = 0;
  final List<DateTime> _requestTimestamps = [];
  final List<DateTime> _errorTimestamps = [];
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

  /// Đóng Gemini chat session (giữ kết nối HTTP keep-alive + history).
  /// Trước đây L3Analyzer không có dispose() trong contract Analyzer → session
  /// bị phụ thuộc hoàn toàn vào GC. Idempotent.
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
    final isRecentError =
        _lastErrorTime != null &&
        DateTime.now().difference(_lastErrorTime!) < const Duration(minutes: 1);

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
    if (_consecutiveErrors >= 3) {
      return HealthReport(
        status: HealthStatus.degraded,
        component: 'L3',
        message:
            '$_consecutiveErrors lỗi liên tiếp. $activeCount/$totalKeys keys ACTIVE.',
      );
    }
    if (isRecentError) {
      return HealthReport(
        status: HealthStatus.degraded,
        component: 'L3',
        message:
            'Gần đây có lỗi (consecutiveErrors=$_consecutiveErrors, errorRate=${_getErrorRateString()}). $activeCount/$totalKeys keys ACTIVE.',
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
    // Concurrency guard: previously only analyzeIncremental() checked
    // _isAnalyzing. If the coordinator calls analyze() while an incremental
    // run is in flight, both mutate _lastResult / _maxRiskLevel /
    // _consecutiveGreenCount across awaits → torn state. Reuse the same flag.
    if (_isAnalyzing) {
      return _lastResult;
    }

    if (_circuitBreakerUntil != null) {
      if (DateTime.now().isBefore(_circuitBreakerUntil!)) {
        return const AnalysisResult(
          overallRiskLevel: RiskLevel.green,
          matches: <KeywordMatch>[],
          reason: 'L3 đang tạm ngưng do lỗi mạng (Circuit Breaker)',
          analysisLevel: AnalysisLevel.l3,
        );
      } else {
        _circuitBreakerUntil = null;
        _consecutiveErrors = 0;
      }
    }

    _isAnalyzing = true;
    try {
      final validationError = _validateInput(text);
      if (validationError != null) {
        _lastResult = validationError;
        return validationError;
      }

      final normalizedKey = _normalizeForCache(text);
      final cached = _cache.get(normalizedKey);
      if (cached != null) {
        GeminiMetrics.instance.recordCacheHit();
        _lastResult = cached;
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
          _recordRequest(false);
          _lastResult = analysisResult;
          return analysisResult;
        },
        onFailure: (error, _) {
          _recordRequest(true);
          final analysisResult = AnalysisResult(
            overallRiskLevel: RiskLevel.green,
            matches: const <KeywordMatch>[],
            reason: 'API Error: $error',
            analysisLevel: AnalysisLevel.l3,
            isError: true,
          );
          _lastResult = analysisResult;
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
    _maxRiskLevel = RiskLevel.green;
    _consecutiveGreenCount = 0;
  }

  Future<AnalysisResult?> analyzeIncremental(String fullText) async {
    if (_isAnalyzing) return null;

    if (_circuitBreakerUntil != null) {
      if (DateTime.now().isBefore(_circuitBreakerUntil!)) {
        return null;
      } else {
        _circuitBreakerUntil = null;
        _consecutiveErrors = 0;
      }
    }

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
      if (!_isSentenceBoundary(newText) &&
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
        // Exponential Backoff with Jitter
        final random = math.Random();
        final baseDelay =
            math.pow(2, _consecutiveErrors.clamp(0, 5)).toInt() * 1000;
        final delayMs = baseDelay + random.nextInt(1000);
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
          _processedTextLength = fullText.length;
          _recordRequest(false);
          _lastResult = analysisResult;
          return analysisResult;
        },
        onFailure: (error, _) {
          _recordRequest(true);
          final analysisResult = AnalysisResult(
            overallRiskLevel: RiskLevel.green,
            matches: const <KeywordMatch>[],
            reason: 'Lỗi phân tích L3: $error',
            analysisLevel: AnalysisLevel.l3,
            isError: true,
          );
          _lastResult = analysisResult;
          return analysisResult;
        },
      );
    } finally {
      _isAnalyzing = false;
    }
  }

  void closeSession({bool resetProgress = true}) {
    _activeSession?.close();
    _activeSession = null;
    if (resetProgress) {
      _processedTextLength = 0;
    }
    _maxRiskLevel = RiskLevel.green;
    _consecutiveGreenCount = 0;
  }

  MetricsSnapshot getMetrics() => GeminiMetrics.instance.getSnapshot();

  /// Parses the raw LLM response text into an [AnalysisResult].
  ///
  /// NOTE: this method has a side effect — it mutates [_maxRiskLevel] and
  /// [_consecutiveGreenCount] to implement the de-escalation state machine
  /// (3 consecutive greens de-escalate from yellow only). This is safe because
  /// both [analyze] and [analyzeIncremental] guard entry with [_isAnalyzing],
  /// so only one parse can be in flight at a time per analyzer instance.
  AnalysisResult parseResponse(
    String responseText,
    String modelName, [
    String? originalText,
  ]) {
    if (responseText.trim().isEmpty) {
      throw const FormatException('Response is blank');
    }
    final jsonString = _extractJson(responseText);
    final decoded = jsonDecode(jsonString);
    if (decoded is! Map) {
      throw const FormatException('Expected JSON object');
    }
    final response = AnalysisResponse.fromJson(decoded.cast<String, Object?>());
    final riskLevel = _parseRiskLevel(response.level, response.reason);

    var finalRiskLevel = riskLevel;
    if (riskLevel == RiskLevel.green) {
      _consecutiveGreenCount++;
      // Only de-escalate from yellow, not from orange/red during active scam
      if (_consecutiveGreenCount >= 3 &&
          _maxRiskLevel.index > RiskLevel.green.index &&
          _maxRiskLevel.index <= RiskLevel.yellow.index) {
        _maxRiskLevel = _maxRiskLevel.deescalate();
        _consecutiveGreenCount = 0;
      }
      finalRiskLevel = _maxRiskLevel;
    } else {
      _consecutiveGreenCount = 0;
      if (riskLevel.index > _maxRiskLevel.index) {
        _maxRiskLevel = riskLevel;
      }
    }

    final reasonParts = <String>[
      if ((response.label ?? '').trim().isNotEmpty) '[${response.label}]',
      if ((response.reason ?? '').trim().isNotEmpty) response.reason!.trim(),
      if ((response.recommendation ?? '').trim().isNotEmpty)
        'Khuyến cáo: ${response.recommendation!.trim()}',
    ];
    final reason = reasonParts.join(' ').trim().isNotEmpty
        ? reasonParts.join(' ')
        : 'Phân tích hoàn tất';

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
      confidence: _calculateConfidence(response, originalText),
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
      // NOTE: String interpolation with const variables is supported in Dart.
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
    return text
        .toLowerCase()
        .replaceAll(RegExp(r'[^\w\s]'), '')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
  }

  bool _isSentenceBoundary(String text) {
    final trimmed = text.trimRight();
    if (trimmed.isEmpty) {
      return false;
    }
    final lower = trimmed.toLowerCase();
    final lastChar = trimmed[trimmed.length - 1];
    if ('.?!\n;:'.contains(lastChar) || trimmed.endsWith('...')) {
      return true;
    }
    final endings = <String>[
      ' à',
      ' ạ',
      ' nhé',
      ' nha',
      ' vậy',
      ' rồi',
      ' đi',
      ' nhỉ',
      ' hen',
      ' nghe',
    ];
    return endings.any(lower.endsWith);
  }

  String _extractJson(String responseText) {
    // Try to find a markdown json block first
    final markdownRegex = RegExp(r'```json\s*(\{.*?\})\s*```', dotAll: true);
    final match = markdownRegex.firstMatch(responseText);
    if (match != null) {
      return match.group(1) ?? responseText;
    }

    // Fallback to finding the first { and last }
    final startIndex = responseText.indexOf('{');
    final endIndex = responseText.lastIndexOf('}');
    if (startIndex != -1 && endIndex != -1 && endIndex > startIndex) {
      return responseText.substring(startIndex, endIndex + 1);
    }
    return responseText;
  }

  RiskLevel _parseRiskLevel(String? level, String? reason) {
    switch (level?.trim().toLowerCase()) {
      case 'red':
        return RiskLevel.red;
      case 'orange':
        return RiskLevel.orange;
      case 'yellow':
        return RiskLevel.yellow;
      case 'green':
        return RiskLevel.green;
      default:
        return _inferLevelFromReason(reason);
    }
  }

  RiskLevel _inferLevelFromReason(String? reason) {
    final lower = reason?.toLowerCase() ?? '';
    final redWords = <String>[
      'lừa đảo',
      'chuyển tiền',
      'mã otp',
      'đe dọa',
      'khởi tố',
      'bắt cóc',
      'tống tiền',
    ];
    if (redWords.any(lower.contains)) {
      return RiskLevel.red;
    }
    final orangeWords = <String>[
      'công an',
      'kiểm sát',
      'tài khoản',
      'mật khẩu',
      'cấp bách',
      'ngay lập tức',
      'ứng dụng',
    ];
    if (orangeWords.any(lower.contains)) {
      return RiskLevel.orange;
    }
    final yellowWords = <String>[
      'đáng ngờ',
      'cẩn thận',
      'lưu ý',
      'chú ý',
      'không chắc',
      'có thể',
    ];
    if (yellowWords.any(lower.contains)) {
      return RiskLevel.yellow;
    }
    return RiskLevel.green;
  }

  double _calculateConfidence(
    AnalysisResponse response, [
    String? originalText,
  ]) {
    if (response.confidenceScore != null) {
      final score = response.confidenceScore!.clamp(0.0, 1.0);
      if (originalText != null && originalText.trim().length < 30) {
        return (score * 0.8).clamp(0.0, 1.0);
      }
      return score;
    }

    var confidence = 0.0;
    final level = response.level?.trim().toLowerCase();
    if (<String>{'green', 'yellow', 'orange', 'red'}.contains(level)) {
      confidence += 0.3;
    }
    final reason = (response.reason ?? '').trim();
    if (reason.isNotEmpty) {
      confidence += 0.15;
      if (reason.length > 20) {
        confidence += 0.15;
      }
    } else {
      // Graceful degradation: L3 response chỉ có level mà không có reason
      // Chấp nhận nhưng giảm confidence thay vì ném lỗi ở parseResponse
      confidence -= 0.2;
    }
    if ((response.label ?? '').trim().isNotEmpty) {
      confidence += 0.15;
    }
    if ((response.recommendation ?? '').trim().isNotEmpty) {
      confidence += 0.15;
    }
    final reasoningSteps = response.reasoningSteps;
    if (reasoningSteps != null && reasoningSteps.isNotEmpty) {
      confidence += (0.05 * reasoningSteps.length).clamp(0.0, 0.15);
    }
    final lowerReason = reason.toLowerCase();
    final uncertaintyWords = [
      'có thể',
      'không chắc',
      'có lẽ',
      'hơi',
      'tạm thời',
    ];
    final uncertaintyCount = uncertaintyWords
        .where(lowerReason.contains)
        .length;
    if (uncertaintyCount > 0) {
      confidence -= 0.1 * uncertaintyCount;
    }
    if (originalText != null && originalText.trim().length < 30) {
      confidence -= 0.15;
    }
    return confidence.clamp(0.0, 1.0);
  }

  void _recordRequest(bool isError) {
    final now = DateTime.now();
    _requestTimestamps.add(now);
    if (isError) {
      _errorTimestamps.add(now);
      _consecutiveErrors++;
      _lastErrorTime = now;
    } else {
      _consecutiveErrors = 0;
      _circuitBreakerUntil = null;
    }

    // Sliding window: 10 mins
    final windowStart = now.subtract(const Duration(minutes: 10));
    _requestTimestamps.removeWhere((t) => t.isBefore(windowStart));
    _errorTimestamps.removeWhere((t) => t.isBefore(windowStart));

    // Check circuit breaker: > 60% errors in the last 10 mins (min 5 requests)
    if (_requestTimestamps.length >= 5) {
      final errorRate = _errorTimestamps.length / _requestTimestamps.length;
      if (errorRate > 0.6) {
        _circuitBreakerUntil = now.add(const Duration(minutes: 2));
      }
    }
  }

  String _getErrorRateString() {
    if (_requestTimestamps.isEmpty) return '0%';
    final rate = (_errorTimestamps.length / _requestTimestamps.length) * 100;
    return '${rate.toStringAsFixed(1)}%';
  }
}
