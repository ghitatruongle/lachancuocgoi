import 'gemini_response.dart';

// ─── Confidence Calculator ──────────────────────────────────────────────
//
// Calculates a confidence score (0.0-1.0) for an L3 analysis response.
// Uses the LLM-provided confidence if available, otherwise applies
// heuristic scoring based on response completeness and uncertainty words.
//
// Extracted from [L3Analyzer] to enable independent testing and
// configuration of confidence heuristics.

/// Calculates a confidence score for the given [AnalysisResponse].
///
/// If the response includes a [AnalysisResponse.confidenceScore], it is
/// used (with a penalty for short input text). Otherwise, a heuristic
/// score is computed from response completeness.
double calculateConfidence(
  AnalysisResponse response, [
  String? originalText,
]) {
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
    // Graceful degradation: L3 response chỉ có level mà không có reason
    // Chấp nhận nhưng giảm confidence thay vì ném lỗi ở parseResponse
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
  final uncertaintyWords = [
    'có thể',
    'không chắc',
    'có lẽ',
    'hơi',
    'tạm thời',
  ];
  final uncertaintyCount = uncertaintyWords
      .where(lowerReason.contains)
      .length;
  if (uncertaintyCount > 0) {
    confidence -= 0.1 * uncertaintyCount;
  }
  if (originalText != null && originalText.trim().length < 30) {
    confidence -= 0.15;
  }
  return confidence.clamp(0.0, 1.0);
}
