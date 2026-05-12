import 'dart:convert';

import '../analysis_level.dart';
import '../analysis_result.dart';
import '../analyzer.dart';
import '../health_check.dart';
import '../../core/risk_level.dart';
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
    ApiKeyProvider? apiKeyProvider,
    KeyHealthTracker? keyHealthTracker,
    GeminiClient? geminiClient,
    GeminiChatSession Function()? sessionFactory,
    ResponseCache<AnalysisResult>? cache,
  }) {
    final provider = apiKeyProvider ?? EnvironmentApiKeyProvider();
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
  static const int _minIncrementalChars = 40;
  static const int _maxIncrementalChars = 200;

  final ApiKeyProvider _apiKeyProvider;
  final KeyHealthTracker _keyHealthTracker;
  final GeminiClient _client;
  final GeminiChatSession Function()? _sessionFactory;
  final ResponseCache<AnalysisResult> _cache;

  GeminiChatSession? _activeSession;
  int _processedTextLength = 0;
  RiskLevel _maxRiskLevel = RiskLevel.green;
  int _consecutiveGreenCount = 0;
  DateTime? _lastErrorTime;
  int _consecutiveErrors = 0;
  AnalysisResult _lastResult = const AnalysisResult(
    overallRiskLevel: RiskLevel.green,
    matches: <KeywordMatch>[],
    analysisLevel: AnalysisLevel.l3,
  );

  @override
  AnalysisLevel get level => AnalysisLevel.l3;

  @override
  Future<void> initialize() async {}

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
            'Gần đây có lỗi (consecutiveErrors=$_consecutiveErrors). $activeCount/$totalKeys keys ACTIVE.',
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
    final validationError = _validateInput(text);
    if (validationError != null) {
      _lastResult = validationError;
      return validationError;
    }

    final cached = _cache.get(text);
    if (cached != null) {
      GeminiMetrics.recordCacheHit();
      _lastResult = cached;
      return cached;
    }
    GeminiMetrics.recordCacheMiss();

    final redaction = PIIStripper.redactPII(text);
    final prompt = PromptBuilder.buildAnalysisPrompt(redaction.redactedText);
    final result = await _client.query<AnalysisResult>(
      prompt,
      (responseText, modelName) => parseResponse(
        PIIStripper.restorePII(responseText, redaction.tokensMap),
        modelName,
      ),
    );
    return result.fold(
      onSuccess: (analysisResult) {
        _cache.put(
          text,
          analysisResult,
          riskLevel: analysisResult.overallRiskLevel,
        );
        _consecutiveErrors = 0;
        _lastResult = analysisResult;
        return analysisResult;
      },
      onFailure: (error, _) {
        _consecutiveErrors++;
        _lastErrorTime = DateTime.now();
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
    if (!_isSentenceBoundary(newText) && newTextLength < _maxIncrementalChars) {
      return null;
    }

    final redaction = PIIStripper.redactPII(newText);
    final prompt = PromptBuilder.buildIncrementalPrompt(
      redaction.redactedText,
      _processedTextLength == 0,
    );
    final result = await session.sendMessage<AnalysisResult>(
      prompt,
      (responseText, modelName) => parseResponse(
        PIIStripper.restorePII(responseText, redaction.tokensMap),
        modelName,
      ),
    );
    return result.fold(
      onSuccess: (analysisResult) {
        _processedTextLength = fullText.length;
        _consecutiveErrors = 0;
        _lastResult = analysisResult;
        return analysisResult;
      },
      onFailure: (error, _) {
        _consecutiveErrors++;
        _lastErrorTime = DateTime.now();
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
  }

  void closeSession() {
    _activeSession?.close();
    _activeSession = null;
    _processedTextLength = 0;
    _maxRiskLevel = RiskLevel.green;
    _consecutiveGreenCount = 0;
  }

  MetricsSnapshot getMetrics() => GeminiMetrics.getSnapshot();

  AnalysisResult parseResponse(String responseText, String modelName) {
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
      if (_consecutiveGreenCount >= 3 &&
          _maxRiskLevel.index > RiskLevel.green.index) {
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
      confidence: _calculateConfidence(response),
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
    return endings.any(lower.endsWith) || trimmed.contains('  ');
  }

  String _extractJson(String responseText) {
    final match = RegExp(
      r'\{[\s\S]*\}',
      multiLine: true,
    ).firstMatch(responseText);
    return match?.group(0) ?? responseText;
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

  double _calculateConfidence(AnalysisResponse response) {
    var confidence = 0.0;
    final level = response.level?.trim().toLowerCase();
    if (<String>{'green', 'yellow', 'orange', 'red'}.contains(level)) {
      confidence += 0.3;
    }
    if ((response.reason ?? '').trim().isNotEmpty) {
      confidence += 0.3;
    }
    if ((response.label ?? '').trim().isNotEmpty) {
      confidence += 0.2;
    }
    if ((response.recommendation ?? '').trim().isNotEmpty) {
      confidence += 0.2;
    }
    return confidence.clamp(0.0, 1.0);
  }
}
