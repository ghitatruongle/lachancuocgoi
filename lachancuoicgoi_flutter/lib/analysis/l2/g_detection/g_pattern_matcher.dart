import 'dart:math' as math;

import '../../analysis_result.dart';
import 'g_flash.dart';
import 'g_models.dart';

class GPatternMatcher {
  GPatternMatcher._();

  static final Map<String, String> _normalizedKeywordCache = <String, String>{};

  static List<MatchedPattern> matchPatterns(
    List<String> tokens,
    List<ScamPattern> patterns,
    Set<KeywordMatch> keywordMatches,
  ) {
    final results = <MatchedPattern>[];
    final matchesByIndex = <int, List<KeywordMatch>>{};
    for (final match in keywordMatches) {
      matchesByIndex.putIfAbsent(match.startIndex, () => []).add(match);
    }

    for (final pattern in patterns) {
      final capturedElements = <String>[];
      if (_matchSinglePattern(
        tokens,
        pattern,
        matchesByIndex,
        capturedElements,
      )) {
        results.add(
          MatchedPattern(
            patternId: pattern.id,
            matchedElements: List<String>.of(capturedElements),
            score: pattern.riskBonus,
          ),
        );
      }
    }

    return results;
  }

  static bool _matchSinglePattern(
    List<String> tokens,
    ScamPattern pattern,
    Map<int, List<KeywordMatch>> matchesByIndex,
    List<String> capturedElements,
  ) {
    final firstElement = pattern.template.isEmpty
        ? null
        : pattern.template.first;
    if (firstElement == null) return false;

    for (var i = 0; i < tokens.length; i++) {
      if (_checkElementAt(i, firstElement, tokens, matchesByIndex)) {
        capturedElements
          ..clear()
          ..add(tokens[i]);
        if (_matchRemainingSequence(
          i,
          1,
          tokens,
          pattern,
          matchesByIndex,
          capturedElements,
        )) {
          return true;
        }
      }
    }

    capturedElements.clear();
    return false;
  }

  static bool _matchRemainingSequence(
    int currentIndex,
    int patternIndex,
    List<String> tokens,
    ScamPattern pattern,
    Map<int, List<KeywordMatch>> matchesByIndex,
    List<String> capturedElements,
  ) {
    if (patternIndex >= pattern.template.length) return true;

    final targetElement = pattern.template[patternIndex];
    final searchStart = currentIndex + 1;
    final searchEnd = math.min(tokens.length, searchStart + pattern.maxGap + 1);

    for (var nextIndex = searchStart; nextIndex < searchEnd; nextIndex++) {
      if (_checkElementAt(nextIndex, targetElement, tokens, matchesByIndex)) {
        capturedElements.add(tokens[nextIndex]);
        if (_matchRemainingSequence(
          nextIndex,
          patternIndex + 1,
          tokens,
          pattern,
          matchesByIndex,
          capturedElements,
        )) {
          return true;
        }
        capturedElements.removeLast();
      }
    }

    return false;
  }

  static bool _checkElementAt(
    int index,
    PatternElement element,
    List<String> tokens,
    Map<int, List<KeywordMatch>> matchesByIndex,
  ) {
    if (index >= tokens.length) return false;

    return switch (element) {
      PatternKeyword(:final value) => _matchesKeyword(tokens[index], value),
      PatternCategory(:final categoryName) =>
        matchesByIndex[index]?.any(
              (match) =>
                  match.category.toLowerCase() == categoryName.toLowerCase(),
            ) ==
            true,
      PatternWildcard() => true,
    };
  }

  static bool _matchesKeyword(String token, String rawKeyword) {
    final normalized = _normalizedKeywordCache.putIfAbsent(
      rawKeyword,
      () => GFlash.tokenize(rawKeyword).join(' '),
    );
    final keywordTokens = normalized
        .split(' ')
        .where((part) => part.isNotEmpty)
        .toList();
    if (keywordTokens.isEmpty) return false;
    return token == keywordTokens.first;
  }
}
