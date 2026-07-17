import '../../analysis_result.dart';

/// Pure-function context scoring: proximity bonus and time-decay position
/// weight for keyword matches within a transcript.
///
/// Extracted from `GDetectionEngine` (Sprint 3) so the engine can delegate
/// scoring rather than owning the math inline.
class ContextScoreCalculator {
  /// Computes a context score for the given [matches] within a transcript of
  /// [totalTokens] tokens.
  ///
  /// The score is the sum of a proximity bonus (pairs of nearby matches
  /// boost the score) and the average position weight minus 1.0 (keywords
  /// appearing later carry more weight, reflecting that the scammer's
  /// current pitch is more indicative of intent than earlier small talk).
  double calculateContextScore(Set<KeywordMatch> matches, int totalTokens) {
    final proximityBonus = _calculateProximityBonus(matches);
    var totalPositionWeight = 0.0;
    for (final match in matches) {
      totalPositionWeight += _positionWeight(match.startIndex, totalTokens);
    }
    final averagePositionWeight = matches.isNotEmpty
        ? totalPositionWeight / matches.length
        : 1.0;
    return proximityBonus + (averagePositionWeight - 1.0);
  }

  double _calculateProximityBonus(Set<KeywordMatch> matches) {
    if (matches.length < 2) return 0;

    final sortedMatches = matches.toList()
      ..sort((a, b) => a.startIndex.compareTo(b.startIndex));
    var totalBonus = 0.0;
    for (var i = 0; i < sortedMatches.length - 1; i++) {
      final current = sortedMatches[i];
      final next = sortedMatches[i + 1];
      final distance = next.startIndex - current.endIndex - 1;
      if (distance >= 0 && distance <= 5) {
        totalBonus += 0.15;
      } else if (distance >= 6 && distance <= 10) {
        totalBonus += 0.05;
      }
    }
    return totalBonus.clamp(0.0, 0.5);
  }

  /// Time-decay position weight: keywords appearing later in the transcript
  /// (more recent) carry higher weight. This reflects that the scammer's
  /// current pitch is more indicative of intent than earlier small talk.
  /// Returns a multiplier in range [0.85, 1.25].
  double _positionWeight(int tokenIndex, int totalTokens) {
    if (totalTokens == 0) return 1.0;
    final relativePosition = tokenIndex / totalTokens;
    // Linear decay: 0.85 at start → 1.25 at end.
    return 0.85 + (relativePosition * 0.40);
  }
}
