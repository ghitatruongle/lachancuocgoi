import 'dart:math' as math;

import '../../analysis_result.dart';
import 'g_flash.dart';
import 'g_models.dart';

class GPatternMatcher {
  GPatternMatcher();

  static final GPatternMatcher _singleton = GPatternMatcher();

  final Map<String, String> _normalizedKeywordCache = <String, String>{};

  void clearCacheInstance() {
    _normalizedKeywordCache.clear();
  }

  static void clearCache() => _singleton.clearCacheInstance();

  List<MatchedPattern> matchPatternsInstance(
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

  static List<MatchedPattern> matchPatterns(
    List<String> tokens,
    List<ScamPattern> patterns,
    Set<KeywordMatch> keywordMatches,
  ) => _singleton.matchPatternsInstance(tokens, patterns, keywordMatches);

  bool _matchSinglePattern(
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

  bool _matchRemainingSequence(
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

  bool _checkElementAt(
    int index,
    PatternElement element,
    List<String> tokens,
    Map<int, List<KeywordMatch>> matchesByIndex,
  ) {
    if (index >= tokens.length) return false;
    final result = _tryConsumeElement(index, element, tokens, matchesByIndex);
    return result != -1;
  }

  int _tryConsumeElement(
    int index,
    PatternElement element,
    List<String> tokens,
    Map<int, List<KeywordMatch>> matchesByIndex,
  ) {
    if (index >= tokens.length) return -1;

    return switch (element) {
      PatternKeyword(:final value) => _matchKeyword(tokens, index, value),
      PatternCategory(:final categoryName) =>
        matchesByIndex[index]?.any(
                  (match) =>
                      match.category.toLowerCase() ==
                      categoryName.toLowerCase(),
                ) ==
                true
            ? index
            : -1,
      PatternWildcard() => index,
    };
  }

  int _matchKeyword(List<String> tokens, int startIndex, String rawKeyword) {
    final normalized = _normalizedKeywordCache.putIfAbsent(
      rawKeyword,
      () => GFlash.tokenize(rawKeyword).join(' '),
    );
    final keywordTokens = normalized
        .split(' ')
        .where((part) => part.isNotEmpty)
        .toList();
    if (keywordTokens.isEmpty) return -1;

    if (startIndex + keywordTokens.length > tokens.length) return -1;
    for (var i = 0; i < keywordTokens.length; i++) {
      if (tokens[startIndex + i] != keywordTokens[i]) return -1;
    }

    return startIndex + keywordTokens.length - 1;
  }
}
