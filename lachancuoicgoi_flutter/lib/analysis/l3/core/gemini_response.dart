class AnalysisResponse {
  const AnalysisResponse({
    this.level,
    this.label,
    this.reason,
    this.recommendation,
  });

  final String? level;
  final String? label;
  final String? reason;
  final String? recommendation;

  factory AnalysisResponse.fromJson(Map<String, Object?> json) {
    return AnalysisResponse(
      level: json['level'] as String?,
      label: json['label'] as String?,
      reason: json['reason'] as String?,
      recommendation: json['recommendation'] as String?,
    );
  }
}
