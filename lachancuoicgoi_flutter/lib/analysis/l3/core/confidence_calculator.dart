import 'gemini_response.dart';

double calculateConfidence(AnalysisResponse response, [String? originalText]) {
  if (response.confidenceScore != null) {
    final score = response.confidenceScore!.clamp(0.0, 1.0);
    if (originalText != null && originalText.trim().length < 30) {
      return (score * 0.8).clamp(0.0, 1.0);
    }
    return score;
  }

  var confidence = 0.0;
  final level = response.level?.trim().toLowerCase();
  if (<String>{'green', 'yellow', 'orange', 'red'}.contains(level)) {
    confidence += 0.3;
  }
  final reason = (response.reason ?? '').trim();
  if (reason.isNotEmpty) {
    confidence += 0.15;
    if (reason.length > 20) {
      confidence += 0.15;
    }
  } else {
    confidence -= 0.2;
  }
  if ((response.label ?? '').trim().isNotEmpty) {
    confidence += 0.15;
  }
  if ((response.recommendation ?? '').trim().isNotEmpty) {
    confidence += 0.15;
  }
  final reasoningSteps = response.reasoningSteps;
  if (reasoningSteps != null && reasoningSteps.isNotEmpty) {
    confidence += (0.05 * reasoningSteps.length).clamp(0.0, 0.15);
  }
  final lowerReason = reason.toLowerCase();
  final uncertaintyWords = ['có thể', 'không chắc', 'có lẽ', 'hơi', 'tạm thời'];
  final uncertaintyCount = uncertaintyWords.where(lowerReason.contains).length;
  if (uncertaintyCount > 0) {
    confidence -= 0.1 * uncertaintyCount;
  }
  if (originalText != null && originalText.trim().length < 30) {
    confidence -= 0.15;
  }
  return confidence.clamp(0.0, 1.0);
}
