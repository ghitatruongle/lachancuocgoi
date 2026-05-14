class GeminiConfig {
  const GeminiConfig({
    this.modelName = 'gemini-2.5-flash-lite',
    required this.temperature,
    required this.topK,
    required this.topP,
    this.timeout = const Duration(milliseconds: 7000),
    this.responseMimeType,
  });

  final String modelName;
  final double temperature;
  final int topK;
  final double topP;
  final Duration timeout;
  final String? responseMimeType;

  static GeminiConfig forAnalysis() {
    return const GeminiConfig(
      modelName: 'gemini-2.5-flash-lite',
      temperature: 0.2,
      topK: 20,
      topP: 0.9,
      responseMimeType: 'application/json',
    );
  }

  static GeminiConfig forSummarization() {
    return const GeminiConfig(
      modelName: 'gemini-2.5-flash-lite',
      temperature: 0.7,
      topK: 40,
      topP: 0.95,
    );
  }
}
