import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

import '../../../../core/system_logger.dart';
import 'gemini_client.dart';
import 'gemini_config.dart';

/// Phase 2 (P2-SEC): A [GeminiRequestExecutor] that routes L3 inference
/// through a secure backend proxy instead of calling the Gemini API directly
/// with keys bundled in the APK.
///
/// **Why this exists:**
/// `env.json` → asset → APK. Any user can extract it. XOR obfuscation is
/// trivially reversible. The only durable fix is to move the API keys to a
/// server the app authenticates against.
///
/// **Backend contract** (the server you deploy):
/// ```
/// POST /analyze
/// Headers:
///   Content-Type: application/json
///   X-Device-Attestation: <Firebase App Check token>  (recommended)
/// Body:
///   {
///     "prompt": "<PII-stripped transcript text>",
///     "model": "gemini-3.5-flash",
///     "temperature": 0.1,
///     "topK": 1,
///     "topP": 1.0
///   }
/// Response (200):
///   { "text": "<Gemini response text>" }
/// Response (4xx/5xx):
///   { "error": "<message>" }
/// ```
///
/// The backend:
/// 1. Validates the device attestation token (Firebase App Check).
/// 2. Strips PII again server-side (defense in depth).
/// 3. Calls Gemini with the server-held API key.
/// 4. Returns only the response text.
///
/// **Circuit breaker:** the existing [GeminiClient] circuit breaker still
/// applies — if the proxy returns 5xx repeatedly, the circuit opens and L3
/// falls back to L2 results.
class ProxyGeminiExecutor {
  ProxyGeminiExecutor({
    required String baseUrl,
    String endpoint = '/analyze',
    Map<String, String> headers = const {},
    http.Client? httpClient,
    Duration timeout = const Duration(seconds: 25),
  })  : _url = '$baseUrl$endpoint',
        _headers = {
          'Content-Type': 'application/json',
          ...headers,
        },
        _httpClient = httpClient ?? http.Client(),
        _timeout = timeout;

  final String _url;
  final Map<String, String> _headers;
  final http.Client _httpClient;
  final Duration _timeout;

  /// Mirrors [GeminiRequestExecutor]'s signature so it can be injected
  /// directly into [GeminiClient].
  ///
  /// The `apiKey` and `config` parameters are accepted for signature
  /// compatibility but the proxy does NOT use `apiKey` — that's the whole
  /// point.
  Future<String> call({
    required String apiKey, // ignored — keys live on the server
    required GeminiConfig config,
    required String modelName,
    required String prompt,
  }) async {
    final uri = Uri.tryParse(_url);
    if (uri == null || !uri.isScheme('https')) {
      throw Exception('P2-SEC: proxy URL must be HTTPS — $_url');
    }

    final body = jsonEncode({
      'prompt': prompt,
      'model': modelName,
      'temperature': config.temperature,
      'topK': config.topK,
      'topP': config.topP,
    });

    SystemLogger.instance.log(
      LogCategory.model,
      'P2-SEC: sending L3 request to proxy ($modelName)...',
    );

    final response = await _httpClient
        .post(uri, headers: _headers, body: body)
        .timeout(_timeout);

    if (response.statusCode != 200) {
      final errorBody = response.body;
      SystemLogger.instance.log(
        LogCategory.model,
        'P2-SEC: proxy returned ${response.statusCode}: $errorBody',
        level: LogLevel.error,
      );
      // Mimic Gemini error messages so [classifyGeminiError] can categorize.
      if (response.statusCode == 429) {
        throw Exception('429 quota exceeded');
      }
      if (response.statusCode == 401 || response.statusCode == 403) {
        throw Exception('${response.statusCode} unauthorized');
      }
      throw Exception('Proxy error ${response.statusCode}: $errorBody');
    }

    final json = jsonDecode(response.body) as Map<String, dynamic>;
    final text = (json['text'] as String?)?.trim();
    if (text == null || text.isEmpty) {
      throw StateError('Empty response from proxy');
    }
    return text;
  }

  void dispose() {
    _httpClient.close();
  }
}

/// Creates a [GeminiRequestExecutor] from a [ProxyGeminiExecutor].
/// Usage:
/// ```dart
/// GeminiClient(
///   apiKeyProvider: provider, // still needed for health tracking, but
///                              // keys are NOT sent to the proxy.
///   config: GeminiConfig.forAnalysis(),
///   requestExecutor: ProxyGeminiExecutor(baseUrl: 'https://api.example.com').call,
/// );
/// ```
GeminiRequestExecutor proxyExecutorFrom(String baseUrl) {
  final proxy = ProxyGeminiExecutor(baseUrl: baseUrl);
  return proxy.call;
}
