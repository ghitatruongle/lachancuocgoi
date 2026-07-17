class GeminiConfig {
  const GeminiConfig({
    this.modelName = 'gemini-3.5-flash',
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

  /// Config cho phân tích L3 (classification với JSON response).
  /// Dùng temperature thấp + topK=1 (greedy) để output ổn định, deterministic.
  static GeminiConfig forAnalysis() {
    return const GeminiConfig(
      modelName: 'gemini-3.5-flash',
      temperature: 0.1,
      topK: 1,
      topP: 1.0,
      timeout: Duration(seconds: 15),
      responseMimeType: 'application/json',
    );
  }

  /// Config cho tóm tắt cuộc gọi (cần độ sáng tạo vừa phải).
  static GeminiConfig forSummarization() {
    return const GeminiConfig(
      modelName: 'gemini-3.5-flash',
      temperature: 0.7,
      topK: 20,
      topP: 0.95,
      timeout: Duration(seconds: 30),
    );
  }
}
