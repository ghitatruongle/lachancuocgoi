import 'dart:async';

import 'package:google_generative_ai/google_generative_ai.dart';

import 'api_key_provider.dart';
import 'gemini_config.dart';
import 'gemini_metrics.dart';
import 'key_health_tracker.dart';
import 'operation_result.dart';

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

/// Default fallback models for Gemini API, shared across client and session.
const List<String> geminiFallbackModels = <String>[
  'gemini-2.5-flash-lite',
  'gemini-2.5-flash',
  'gemini-2.0-flash',
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
      return Result.failure(
        StateError(
          'All API keys are in COOLDOWN/EXHAUSTED. Quota resets at 00:00.',
        ),
      );
    }

    Object? lastError;
    StackTrace? lastStackTrace;
    _hasNotifiedAllExhausted = false;

    for (final keyIndex in activeIndices) {
      final apiKey = keys[keyIndex];
      var retryCount = 0;
      for (final modelName in _fallbackModels) {
        // Exponential backoff between retries: 1s, 2s, 4s
        if (retryCount > 0) {
          final delayMs = 1000 * (1 << (retryCount - 1)); // 1000, 2000, 4000
          await Future<void>.delayed(Duration(milliseconds: delayMs));
        }
        retryCount++;
        try {
          final responseText = await _requestExecutor(
            apiKey: apiKey,
            config: config,
            modelName: modelName,
            prompt: prompt,
          );
          final parsed = parser(responseText, modelName);
          keyHealthTracker?.markSuccess(keyIndex);
          _recordSuccess();
          GeminiMetrics.instance.recordCall(
            success: true,
            latencyMs: DateTime.now().difference(startTime).inMilliseconds,
            keyIndex: keyIndex,
          );
          return Result.success(parsed);
        } catch (error, stackTrace) {
          lastError = error;
          lastStackTrace = stackTrace;
          _recordFailure();
          final errorType = _classifyError(error);
          if (errorType == GeminiErrorType.auth) {
            keyHealthTracker?.markInvalid(keyIndex, error.toString());
            break;
          }
          if (errorType == GeminiErrorType.quota ||
              errorType == GeminiErrorType.modelNotFound) {
            continue;
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
    final lastCall = _lastCallTimestamp;
    if (lastCall != null) {
      final elapsed = DateTime.now().difference(lastCall);
      if (elapsed < _minInterval) {
        await Future<void>.delayed(_minInterval - elapsed);
      }
    }
    _lastCallTimestamp = DateTime.now();
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
