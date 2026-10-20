import '../../analysis_result.dart';

class ContextScoreCalculator {
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

  double _positionWeight(int tokenIndex, int totalTokens) {
    if (totalTokens == 0) return 1.0;
    final relativePosition = tokenIndex / totalTokens;

    return 0.85 + (relativePosition * 0.40);
  }
}
