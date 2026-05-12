import 'core/api_key_provider.dart';
import 'core/gemini_client.dart';
import 'core/gemini_config.dart';
import 'core/key_health_tracker.dart';
import 'prompt_builder.dart';

class GeminiSummarizer {
  GeminiSummarizer({
    ApiKeyProvider? apiKeyProvider,
    KeyHealthTracker? keyHealthTracker,
    GeminiClient? geminiClient,
  })  : _apiKeyProvider = apiKeyProvider ?? EnvironmentApiKeyProvider(),
        _keyHealthTracker = keyHealthTracker,
        _geminiClient = geminiClient;

  static const int _minWords = 5;

  final ApiKeyProvider _apiKeyProvider;
  final KeyHealthTracker? _keyHealthTracker;
  final GeminiClient? _geminiClient;

  GeminiClient get _client =>
      _geminiClient ??
      GeminiClient(
        apiKeyProvider: _apiKeyProvider,
        config: GeminiConfig.forSummarization(),
        keyHealthTracker: _keyHealthTracker,
      );

  Future<String> summarize(String text) async {
    final trimmed = text.trim();
    final words = trimmed.split(RegExp(r'\s+')).where((part) => part.isNotEmpty);
    if (words.length < _minWords) {
      return 'Không đủ nội dung để tóm tắt (cần ít nhất $_minWords từ)';
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
