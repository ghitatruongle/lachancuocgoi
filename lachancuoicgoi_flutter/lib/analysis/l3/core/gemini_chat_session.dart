import 'dart:async';

import 'package:google_generative_ai/google_generative_ai.dart';

import 'api_key_provider.dart';
import 'gemini_client.dart';
import 'gemini_config.dart';
import 'gemini_metrics.dart';
import 'key_health_tracker.dart';
import 'operation_result.dart';

typedef GeminiChatExecutor =
    Future<String> Function({
      required String apiKey,
      required GeminiConfig config,
      required String modelName,
      required List<Content> history,
      required String prompt,
    });

class GeminiChatSession {
  GeminiChatSession({
    required this.apiKeyProvider,
    required this.config,
    this.keyHealthTracker,
    GeminiChatExecutor? chatExecutor,
  }) : _chatExecutor = chatExecutor ?? _defaultChatExecutor;

  static const Duration _minInterval = Duration(seconds: 1);
  static const List<String> _fallbackModels = <String>[
    'gemini-2.5-flash-lite',
    'gemini-3-flash-preview',
    'gemini-2.5-flash',
    'gemini-3.1-flash-lite-preview',
  ];

  final ApiKeyProvider apiKeyProvider;
  final GeminiConfig config;
  final KeyHealthTracker? keyHealthTracker;
  final GeminiChatExecutor _chatExecutor;

  int _currentKeyIndex = 0;
  int _currentModelIndex = 0;
  DateTime? _lastCallTime;
  final List<Content> _safeHistory = <Content>[];

  Future<Result<T>> sendMessage<T>(
    String text,
    T Function(String responseText, String modelName) parser,
  ) async {
    await _applyRateLimit();
    final startTime = DateTime.now();
    final keys = apiKeyProvider.getApiKeys();
    if (keys.isEmpty) {
      return Result.failure(StateError('No API keys available'));
    }

    final activeIndices = <int>[];
    final bestKey =
        keyHealthTracker?.getAvailableKeyIndex() ?? _currentKeyIndex;
    if (bestKey >= 0) {
      activeIndices.add(bestKey);
    }
    final others =
        keyHealthTracker?.getActiveKeyIndices() ??
        List<int>.generate(keys.length, (index) => index);
    for (final index in others) {
      if (!activeIndices.contains(index)) {
        activeIndices.add(index);
      }
    }
    if (activeIndices.isEmpty) {
      return Result.failure(
        StateError('All API keys are exhausted or in cooldown'),
      );
    }

    Object? lastError;
    StackTrace? lastStackTrace;
    var firstKeyAttempted = false;

    for (final keyIndex in activeIndices) {
      if (!firstKeyAttempted) {
        firstKeyAttempted = true;
      } else {
        await Future<void>.delayed(const Duration(seconds: 1));
      }

      if (keyIndex != _currentKeyIndex) {
        _currentKeyIndex = keyIndex;
        _currentModelIndex = 0;
      }

      for (
        var modelIndex = _currentModelIndex;
        modelIndex < _fallbackModels.length;
        modelIndex++
      ) {
        _currentModelIndex = modelIndex;
        final modelName = _fallbackModels[_currentModelIndex];
        try {
          final responseText = await _chatExecutor(
            apiKey: keys[_currentKeyIndex],
            config: config,
            modelName: modelName,
            history: List<Content>.unmodifiable(_safeHistory),
            prompt: text,
          );
          final parsed = parser(responseText, modelName);
          _safeHistory.add(Content.text(text));
          _safeHistory.add(Content.model(<Part>[TextPart(responseText)]));
          keyHealthTracker?.markSuccess(_currentKeyIndex);
          GeminiMetrics.recordCall(
            success: true,
            latencyMs: DateTime.now().difference(startTime).inMilliseconds,
            keyIndex: _currentKeyIndex,
          );
          return Result.success(parsed);
        } catch (error, stackTrace) {
          lastError = error;
          lastStackTrace = stackTrace;
          final errorType = _classifyError(error);
          if (errorType == GeminiErrorType.auth) {
            keyHealthTracker?.markInvalid(_currentKeyIndex, error.toString());
            break;
          }
          if (errorType == GeminiErrorType.quota ||
              errorType == GeminiErrorType.modelNotFound) {
            continue;
          }
          if (error is TimeoutException) {
            keyHealthTracker?.markError(_currentKeyIndex, error.toString());
            break;
          }
          keyHealthTracker?.markError(_currentKeyIndex, error.toString());
          return Result.failure(error, stackTrace);
        }
      }

      if (_classifyError(lastError) == GeminiErrorType.quota) {
        keyHealthTracker?.markQuotaExceeded(_currentKeyIndex);
      }
    }

    return Result.failure(
      lastError ?? StateError('Unknown error during chat session fallback'),
      lastStackTrace,
    );
  }

  void close() {
    _safeHistory.clear();
    _currentModelIndex = 0;
  }

  Future<void> _applyRateLimit() async {
    final lastCall = _lastCallTime;
    if (lastCall != null) {
      final elapsed = DateTime.now().difference(lastCall);
      if (elapsed < _minInterval) {
        await Future<void>.delayed(_minInterval - elapsed);
      }
    }
    _lastCallTime = DateTime.now();
  }

  GeminiErrorType _classifyError(Object? error) {
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

  static Future<String> _defaultChatExecutor({
    required String apiKey,
    required GeminiConfig config,
    required String modelName,
    required List<Content> history,
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
    final chat = model.startChat(history: history);
    final response = await chat
        .sendMessage(Content.text(prompt))
        .timeout(config.timeout);
    final text = response.text?.trim();
    if (text == null || text.isEmpty) {
      throw StateError('Empty response from Gemini');
    }
    return text;
  }
}
