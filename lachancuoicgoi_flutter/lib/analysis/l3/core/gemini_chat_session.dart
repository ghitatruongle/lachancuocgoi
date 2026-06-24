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
  // Max number of Content entries in _safeHistory (user + model = 2 per exchange).
  // 20 entries = 10 exchanges. Prevents exceeding Gemini context window.
  static const int _maxHistoryEntries = 20;
  static const List<String> _fallbackModels = geminiFallbackModels;

  final ApiKeyProvider apiKeyProvider;
  final GeminiConfig config;
  final KeyHealthTracker? keyHealthTracker;
  final GeminiChatExecutor _chatExecutor;

  int _currentKeyIndex = 0;
  int _currentModelIndex = 0;
  DateTime? _lastCallTime;
  // Rate-limit serialization chain (see _applyRateLimit). Prevents concurrent
  // sendMessage() calls from both reading a stale _lastCallTime and firing
  // closer together than _minInterval.
  Future<void> _rateLimitChain = Future<void>.value();
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

        int modelRetries = 0;
        bool shouldMoveToNextModel = false;

        while (modelRetries < 2 && !shouldMoveToNextModel) {
          if (modelRetries > 0) {
            await Future<void>.delayed(const Duration(milliseconds: 1000));
          }

          try {
            final responseText = await _chatExecutor(
              apiKey: keys[_currentKeyIndex],
              config: config,
              modelName: modelName,
              history: List<Content>.unmodifiable(_safeHistory),
              prompt: text,
            );
            final parsed = parser(responseText, modelName);

            // L3 Resilience: Cost tracking
            final historyTextLength = _safeHistory.fold<int>(
              0,
              (sum, content) =>
                  sum +
                  (content.parts.firstOrNull is TextPart
                      ? (content.parts.first as TextPart).text.length
                      : 0),
            );
            final estimatedTokens =
                (historyTextLength + text.length + responseText.length) ~/ 4;
            keyHealthTracker?.recordTokenUsage(
              _currentKeyIndex,
              estimatedTokens,
            );

            _safeHistory.add(Content.text(text));
            _safeHistory.add(Content.model(<Part>[TextPart(responseText)]));
            while (_safeHistory.length > _maxHistoryEntries) {
              _safeHistory.removeRange(0, 2);
            }
            keyHealthTracker?.markSuccess(_currentKeyIndex);
            GeminiMetrics.instance.recordCall(
              success: true,
              latencyMs: DateTime.now().difference(startTime).inMilliseconds,
              keyIndex: _currentKeyIndex,
            );
            return Result.success(parsed);
          } on Object catch (error, stackTrace) {
            lastError = error;
            lastStackTrace = stackTrace;
            final errorType = _classifyError(error);
            if (errorType == GeminiErrorType.auth) {
              keyHealthTracker?.markInvalid(_currentKeyIndex, error.toString());
              shouldMoveToNextModel = true;
              break;
            }
            if (errorType == GeminiErrorType.quota ||
                errorType == GeminiErrorType.modelNotFound) {
              shouldMoveToNextModel = true;
              continue;
            }
            if (error is TimeoutException) {
              modelRetries++;
              keyHealthTracker?.markError(_currentKeyIndex, error.toString());
              continue;
            }
            modelRetries++;
            keyHealthTracker?.markError(_currentKeyIndex, error.toString());
          }
        }

        if (_classifyError(lastError) == GeminiErrorType.auth) {
          break;
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
    // Serialize through a Future chain so concurrent callers queue up rather
    // than each reading a stale _lastCallTime and firing together.
    final completer = Completer<void>();
    final previous = _rateLimitChain;
    _rateLimitChain = completer.future;
    try {
      await previous;
      final lastCall = _lastCallTime;
      if (lastCall != null) {
        final elapsed = DateTime.now().difference(lastCall);
        if (elapsed < _minInterval) {
          await Future<void>.delayed(_minInterval - elapsed);
        }
      }
      _lastCallTime = DateTime.now();
    } finally {
      completer.complete();
    }
  }

  GeminiErrorType _classifyError(Object? error) => classifyGeminiError(error);

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
