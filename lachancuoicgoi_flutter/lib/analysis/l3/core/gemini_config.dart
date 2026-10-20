class GeminiConfig {
  const GeminiConfig({
    this.modelName = 'gemini-flash-latest',
    required this.temperature,
    required this.topK,
    required this.topP,
    this.timeout = const Duration(milliseconds: 25000),
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
      modelName: 'gemini-flash-latest',
      temperature: 0.1,
      topK: 1,
      topP: 1.0,
      timeout: Duration(seconds: 15),
      responseMimeType: 'application/json',
    );
  }

  static GeminiConfig forSummarization() {
    return const GeminiConfig(
      modelName: 'gemini-flash-latest',
      temperature: 0.7,
      topK: 20,
      topP: 0.95,
      timeout: Duration(seconds: 30),
    );
  }
}
