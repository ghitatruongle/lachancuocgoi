import 'dart:math' as math;

import '../../analysis_result.dart';
import 'g_flash.dart';
import 'g_models.dart';

/// Pattern matcher cho L2 — match ScamPattern templates (keyword + category +
/// wildcard) trên token stream.
///
/// Phase 6: trước đây toàn bộ state + methods là static → `_normalizedKeywordCache`
/// là process-wide mutable. 2 L2Analyzer instance song song sẻ cache → race
/// condition + test pollution. Giờ cache là instance field; static API
/// (`matchPatterns`, `clearCache`) giữ làm backward-compat facade delegate
/// sang singleton `_singleton`. GDetectionEngine inject instance riêng.
class GPatternMatcher {
  GPatternMatcher();

  /// Static facade singleton — chỉ dùng cho backward-compat static API.
  /// GDetectionEngine nên inject instance riêng (xem `GDetectionEngine._patternMatcher`).
  static final GPatternMatcher _singleton = GPatternMatcher();

  /// Per-instance cache: normalize keyword → tokenized string. Phân biệt
  /// "đã compute" (key exist) vs "chưa" — tránh re-normalize cùng keyword.
  final Map<String, String> _normalizedKeywordCache = <String, String>{};

  /// Clear instance cache.
  void clearCacheInstance() {
    _normalizedKeywordCache.clear();
  }

  /// Static facade — clear cache của singleton.
  /// @deprecated: dùng instance method qua `GDetectionEngine.patternMatcher.clearCacheInstance()`.
  static void clearCache() => _singleton.clearCacheInstance();

  /// Instance API: match patterns trên token stream, dùng instance cache.
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

  /// Static facade — delegate sang singleton. Giữ tên `matchPatterns` để
  /// backward-compat với tất cả call site hiện tại (test + GDetectionEngine).
  /// @deprecated: dùng instance method `matchPatternsInstance`.
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

  /// Check if element matches at given index.
  /// Returns true if element matches, false otherwise.
  /// For PatternKeyword, supports multi-token keywords (e.g. "chuyen khoan").
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

  /// Match keyword tokens starting at [startIndex] in the input tokens.
  /// Returns the index of the last matched token, or -1 if no match.
  /// For multi-token keywords (e.g. "chuyen khoan"), checks sequential tokens.
  /// ✓ BUG #2 FIX: Now correctly checks ALL keyword tokens, not just the first.
  /// Uses instance `_normalizedKeywordCache` thay vì static (Phase 6).
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

    // Check all keyword tokens match sequentially from startIndex
    if (startIndex + keywordTokens.length > tokens.length) return -1;
    for (var i = 0; i < keywordTokens.length; i++) {
      if (tokens[startIndex + i] != keywordTokens[i]) return -1;
    }
    // Return index of last matched token
    return startIndex + keywordTokens.length - 1;
  }
}
