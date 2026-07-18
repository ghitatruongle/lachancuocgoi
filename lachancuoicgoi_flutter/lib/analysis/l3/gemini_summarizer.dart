import 'core/api_key_provider.dart';
import 'core/gemini_client.dart';
import 'core/gemini_config.dart';
import 'core/key_health_tracker.dart';
import 'prompt_builder.dart';
import '../../data/cloud_analysis_consent_store.dart';

class GeminiSummarizer {
  GeminiSummarizer({
    ApiKeyProvider? apiKeyProvider,
    KeyHealthTracker? keyHealthTracker,
    GeminiClient? geminiClient,
    CloudAnalysisConsentStore? cloudConsentStore,
  }) : _apiKeyProvider = apiKeyProvider ?? EnvironmentApiKeyProvider(),
       _keyHealthTracker = keyHealthTracker,
       _geminiClient = geminiClient,
       _cloudConsentStore = cloudConsentStore;

  static const int _minWords = 5;

  final ApiKeyProvider _apiKeyProvider;
  final KeyHealthTracker? _keyHealthTracker;
  final GeminiClient? _geminiClient;
  final CloudAnalysisConsentStore? _cloudConsentStore;
  GeminiClient? _cachedClient; // Cache client để preserve circuit breaker state

  GeminiClient get _client {
    if (_geminiClient != null) return _geminiClient;
    return _cachedClient ??= GeminiClient(
      apiKeyProvider: _apiKeyProvider,
      config: GeminiConfig.forSummarization(),
      keyHealthTracker: _keyHealthTracker,
      cloudConsentStore: _cloudConsentStore,
    );
  }

  Future<String> summarize(String text) async {
    final trimmed = text.trim();
    final words = trimmed
        .split(RegExp(r'\s+'))
        .where((part) => part.isNotEmpty);
    if (words.length < _minWords) {
      return 'Không đủ nội dung để tóm tắt (cần ít nhất $_minWords từ)';
    }
    try {
      _cloudConsentStore?.requireConsent();
    } on CloudAnalysisConsentRequiredException {
      return 'Phân tích cloud chưa được đồng ý; giữ kết quả offline.';
    }
    final prompt = PromptBuilder.buildSummarizationPrompt(trimmed);
    final result = await _client.query<String>(
      prompt,
      (responseText, _) => responseText.trim(),
    );
    return result.fold(
      onSuccess: (value) => value,
      onFailure: (error, _) => 'Lỗi tóm tắt: $error',
    );
  }
}
