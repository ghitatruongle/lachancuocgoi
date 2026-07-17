import 'dart:async';

import 'package:google_generative_ai/google_generative_ai.dart';

import 'api_key_provider.dart';
import 'gemini_config.dart';
import 'gemini_metrics.dart';
import 'key_health_tracker.dart';
import 'operation_result.dart';
import '../../../../core/system_logger.dart';

typedef GeminiRequestExecutor =
    Future<String> Function({
      required String apiKey,
      required GeminiConfig config,
      required String modelName,
      required String prompt,
    });

enum GeminiErrorType { quota, auth, modelNotFound, timeout, network, unknown }

/// Shared error classifier used by both [GeminiClient] and [GeminiChatSession].
GeminiErrorType classifyGeminiError(Object? error) {
  final message = error?.toString().toLowerCase() ?? '';
  if (message.contains('429') || message.contains('quota')) {
    return GeminiErrorType.quota;
  }
  if (message.contains('403') ||
      message.contains('401') ||
      message.contains('unauthorized') ||
      message.contains('api key') ||
      message.contains('api_key')) {
    return GeminiErrorType.auth;
  }
  if (message.contains('404') || message.contains('not found')) {
    return GeminiErrorType.modelNotFound;
  }
  if (message.contains('timeout')) {
    return GeminiErrorType.timeout;
  }
  if (message.contains('socket') ||
      message.contains('network') ||
      message.contains('connection')) {
    return GeminiErrorType.network;
  }
  return GeminiErrorType.unknown;
}

/// Default model priority list for Gemini API, shared across client and session.
/// The client tries each model in order, falling back to the next on failure.
/// Priority: newest/most capable first → oldest/lightest last.
const List<String> geminiFallbackModels = <String>[
  'gemini-3.5-flash',        // Ưu tiên 1: Model mới nhất, mạnh nhất
  'gemini-3.1-flash-lite',   // Ưu tiên 2: Fallback nhẹ hơn
  'gemini-3-flash',          // Ưu tiên 3: Thế hệ 3 cơ bản
  'gemini-2.5-flash',        // Ưu tiên 4: Thế hệ 2.5 đầy đủ
  'gemini-2.5-flash-lite',   // Ưu tiên 5 (cuối): Nhẹ nhất, fallback an toàn
];

class GeminiClient {
  GeminiClient({
    required this.apiKeyProvider,
    required this.config,
    this.keyHealthTracker,
    this.onAllKeysExhausted,
    GeminiRequestExecutor? requestExecutor,
  }) : _requestExecutor = requestExecutor ?? _defaultRequestExecutor;

  static const Duration _minInterval = Duration(seconds: 1);
  static const int _circuitBreakerThreshold = 5;
  static const Duration _circuitBreakerTimeout = Duration(seconds: 30);
  static const List<String> _fallbackModels = geminiFallbackModels;

  final ApiKeyProvider apiKeyProvider;
  final GeminiConfig config;
  final KeyHealthTracker? keyHealthTracker;
  final void Function()? onAllKeysExhausted;
  final GeminiRequestExecutor _requestExecutor;

  _CircuitState _circuitState = _CircuitState.closed;
  int _consecutiveFailures = 0;
  DateTime? _circuitOpenedAt;
  bool _hasNotifiedAllExhausted = false;
  // Rate-limit serialization: a Future chain that every call appends to.
  // Each call awaits the previous link, then enforces the min spacing
  // relative to the previous call's completion. This makes _applyRateLimit
  // atomic under concurrency — two overlapping query() calls can no longer
  // both read the stale timestamp and fire simultaneously (which previously
  // defeated the 1s minimum spacing).
  Future<void> _rateLimitChain = Future<void>.value();
  DateTime? _lastCallTimestamp;

  Future<Result<T>> query<T>(
    String prompt,
    T Function(String responseText, String modelName) parser,
  ) async {
    if (!_shouldAllowRequest()) {
      return Result.failure(
        StateError(
          'Circuit breaker open. Retry after ${_circuitBreakerTimeout.inMilliseconds}ms',
        ),
      );
    }

    await _applyRateLimit();
    final startTime = DateTime.now();
    final keys = apiKeyProvider.getApiKeys();
    if (keys.isEmpty) {
      return Result.failure(StateError('No API keys available'));
    }

    final activeIndices =
        keyHealthTracker?.getActiveKeyIndices() ??
        List<int>.generate(keys.length, (index) => index);
    if (activeIndices.isEmpty) {
      _notifyAllKeysExhausted();
      SystemLogger.instance.log(
        LogCategory.model,
        'Tất cả các API key của Gemini đều hết hạn mức (Quota) hoặc lỗi.',
        level: LogLevel.error,
      );
      return Result.failure(
        StateError(
          'All API keys are in COOLDOWN/EXHAUSTED. Quota resets at 00:00.',
        ),
      );
    }

    Object? lastError;
    StackTrace? lastStackTrace;

    for (final keyIndex in activeIndices) {
      final apiKey = keys[keyIndex];
      var quotaBackoffAttempt = 0;

      for (
        var modelIndex = 0;
        modelIndex < _fallbackModels.length;
        modelIndex++
      ) {
        final modelName = _fallbackModels[modelIndex];
        try {
          SystemLogger.instance.log(LogCategory.model, 'Đang gửi prompt phân tích tới Gemini ($modelName)...');
          final responseText = await _requestExecutor(
            apiKey: apiKey,
            config: config,
            modelName: modelName,
            prompt: prompt,
          );
          final parsed = parser(responseText, modelName);
          keyHealthTracker?.markSuccess(keyIndex);

          // L3 Resilience: Cost tracking
          final estimatedTokens = (prompt.length + responseText.length) ~/ 4;
          keyHealthTracker?.recordTokenUsage(keyIndex, estimatedTokens);

          _recordSuccess();
          SystemLogger.instance.log(LogCategory.model, 'Gemini phản hồi thành công ($modelName).');
          GeminiMetrics.instance.recordCall(
            success: true,
            latencyMs: DateTime.now().difference(startTime).inMilliseconds,
            keyIndex: keyIndex,
          );
          return Result.success(parsed);
        } on Object catch (error, stackTrace) {
          lastError = error;
          lastStackTrace = stackTrace;
          _recordFailure();

          final errorType = _classifyError(error);
          SystemLogger.instance.log(
            LogCategory.model,
            'Lỗi gọi Gemini ($modelName): ${error.toString().split('\n').first}. Loại: ${errorType.name}',
            level: LogLevel.warning,
          );
          if (errorType == GeminiErrorType.auth) {
            keyHealthTracker?.markInvalid(keyIndex, error.toString());
            break;
          }
          if (errorType == GeminiErrorType.quota) {
            keyHealthTracker?.markError(keyIndex, error.toString());
            if (modelIndex < _fallbackModels.length - 1) {
              quotaBackoffAttempt++;
              await Future<void>.delayed(
                Duration(seconds: quotaBackoffAttempt),
              );
              continue;
            }
            break;
          }
          if (errorType == GeminiErrorType.modelNotFound) {
            if (modelIndex < _fallbackModels.length - 1) {
              continue;
            }
            break;
          }

          keyHealthTracker?.markError(keyIndex, error.toString());
          break;
        }
      }
      final finalType = _classifyError(lastError);
      if (finalType == GeminiErrorType.quota) {
        keyHealthTracker?.markQuotaExceeded(keyIndex);
      }
    }

    if (keyHealthTracker?.areAllKeysDown() ?? false) {
      _notifyAllKeysExhausted();
    }
    GeminiMetrics.instance.recordCall(
      success: false,
      latencyMs: DateTime.now().difference(startTime).inMilliseconds,
    );
    return Result.failure(
      lastError ?? StateError('All API keys failed'),
      lastStackTrace,
    );
  }

  bool _shouldAllowRequest() {
    switch (_circuitState) {
      case _CircuitState.closed:
        return true;
      case _CircuitState.halfOpen:
        return true;
      case _CircuitState.open:
        final openedAt = _circuitOpenedAt;
        if (openedAt == null ||
            DateTime.now().difference(openedAt) >= _circuitBreakerTimeout) {
          _circuitState = _CircuitState.halfOpen;
          return true;
        }
        return false;
    }
  }

  void _recordSuccess() {
    _consecutiveFailures = 0;
    // Fix: chỉ reset cờ "all keys exhausted" khi có request thành công
    // trở lại — tránh onAllKeysExhausted bị bắn lặp ở mọi query khi
    // toàn bộ key vẫn đang down.
    _hasNotifiedAllExhausted = false;
    if (_circuitState == _CircuitState.halfOpen) {
      _circuitState = _CircuitState.closed;
    }
  }

  void _recordFailure() {
    _consecutiveFailures++;
    if (_consecutiveFailures >= _circuitBreakerThreshold) {
      _circuitState = _CircuitState.open;
      _circuitOpenedAt = DateTime.now();
    }
  }

  Future<void> _applyRateLimit() async {
    // Serialize rate-limit checks through a Future chain so concurrent callers
    // queue up rather than each reading a stale _lastCallTimestamp and firing
    // together. Each caller appends its own delay link after the previous one.
    final completer = Completer<void>();
    final previous = _rateLimitChain;
    _rateLimitChain = completer.future;
    try {
      await previous;
      final lastCall = _lastCallTimestamp;
      if (lastCall != null) {
        final elapsed = DateTime.now().difference(lastCall);
        if (elapsed < _minInterval) {
          await Future<void>.delayed(_minInterval - elapsed);
        }
      }
      _lastCallTimestamp = DateTime.now();
    } finally {
      completer.complete();
    }
  }

  void _notifyAllKeysExhausted() {
    if (_hasNotifiedAllExhausted) {
      return;
    }
    _hasNotifiedAllExhausted = true;
    onAllKeysExhausted?.call();
  }

  GeminiErrorType _classifyError(Object? error) => classifyGeminiError(error);

  static Future<String> _defaultRequestExecutor({
    required String apiKey,
    required GeminiConfig config,
    required String modelName,
    required String prompt,
  }) async {
    final model = GenerativeModel(
      model: modelName,
      apiKey: apiKey,
      generationConfig: GenerationConfig(
        temperature: config.temperature,
        topK: config.topK,
        topP: config.topP,
        responseMimeType: config.responseMimeType,
      ),
    );
    final response = await model
        .generateContent(<Content>[Content.text(prompt)])
        .timeout(config.timeout);
    final text = response.text?.trim();
    if (text == null || text.isEmpty) {
      throw StateError('Empty response from Gemini');
    }
    return text;
  }
}

enum _CircuitState { closed, open, halfOpen }
