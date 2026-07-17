class AnalysisResponse {
  const AnalysisResponse({
    this.reasoningSteps,
    this.level,
    this.label,
    this.reason,
    this.recommendation,
    this.confidenceScore,
  });

  final List<String>? reasoningSteps;
  final String? level;
  final String? label;
  final String? reason;
  final String? recommendation;
  final double? confidenceScore;

  factory AnalysisResponse.fromJson(Map<String, Object?> json) {
    List<String>? parsedSteps;
    if (json['reasoning_steps'] is List) {
      parsedSteps = (json['reasoning_steps'] as List)
          .map((e) => e.toString())
          .toList();
    }

    return AnalysisResponse(
      reasoningSteps: parsedSteps,
      level: json['level'] as String?,
      label: json['label'] as String?,
      reason: json['reason'] as String?,
      recommendation: json['recommendation'] as String?,
      confidenceScore: (json['confidence_score'] as num?)?.toDouble(),
    );
  }
}
