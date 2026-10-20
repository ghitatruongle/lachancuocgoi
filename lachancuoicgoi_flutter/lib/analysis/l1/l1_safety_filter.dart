import '../../core/risk_level.dart';
import '../../core/logger.dart';
import '../analysis_config.dart';
import '../analysis_result.dart';
import '../common/text_normalizer.dart';

class L1SafetyFilter {
  static Set<KeywordMatch> filterSafeMatches({
    required Set<KeywordMatch> matches,
    required List<String> tokens,
    required L1Config config,
    required AppLogger? logger,
    required List<RegExp> Function() getQuestionPatterns,
  }) {
    if (matches.isEmpty) return matches;

    final filtered = <KeywordMatch>{};

    final negationRegex = RegExp(
      config.negationRegexPattern,
      caseSensitive: false,
    );

    final safeBeneficiaries = config.safeBeneficiaries;
    final financialIndicatorKeywords = config.financialIndicatorKeywords;
    final generalSafePhrases = config.generalSafePhrases;
    final windowSize = config.contextWindowSize;
    final familyTerms = config.familyTerms;
    final questionPatterns = getQuestionPatterns();

    final fullText = TextNormalizer.normalize(
      tokens.join(' '),
      applySlang: true,
    );
    var globalSafeCount = 0;
    for (final safe in generalSafePhrases) {
      var idx = 0;
      while ((idx = fullText.indexOf(safe, idx)) != -1) {
        globalSafeCount++;
        idx += safe.length;
      }
    }

    for (final match in matches) {
      if (match.startIndex == -1 || match.endIndex == -1) {
        filtered.add(match);
        continue;
      }

      final startPrefix = (match.startIndex - windowSize).clamp(
        0,
        tokens.length,
      );
      final prefixTokens = tokens.sublist(startPrefix, match.startIndex);
      final prefixText = prefixTokens.join(' ');

      final endSuffix = (match.endIndex + windowSize + 1).clamp(
        0,
        tokens.length,
      );
      final suffixTokens = tokens.sublist(match.endIndex + 1, endSuffix);
      final suffixText = suffixTokens.join(' ');

      final wholeContextText = tokens.sublist(startPrefix, endSuffix).join(' ');

      bool shouldFilter = false;

      final normalizedPrefix = TextNormalizer.normalize(
        prefixText,
        applySlang: true,
      );
      if (negationRegex.hasMatch(normalizedPrefix)) {
        shouldFilter = true;
      }

      if (!shouldFilter) {
        final normalizedKeyword = TextNormalizer.normalize(
          match.keyword,
          applySlang: true,
        );
        final isFinancial = financialIndicatorKeywords.any(
          (fin) => normalizedKeyword.contains(fin),
        );
        if (isFinancial) {
          for (final ben in safeBeneficiaries) {
            if (suffixText.contains(ben)) {
              shouldFilter = true;
              break;
            }
          }
        }
      }

      if (!shouldFilter) {
        for (final safe in generalSafePhrases) {
          if (wholeContextText.contains(safe)) {
            shouldFilter = true;
            break;
          }
        }
      }

      if (!shouldFilter) {
        final normalizedPrefixCtx = TextNormalizer.normalize(
          prefixText,
          applySlang: true,
        );
        for (final pattern in questionPatterns) {
          if (pattern.hasMatch(normalizedPrefixCtx)) {
            shouldFilter = true;
            break;
          }
        }
      }

      if (!shouldFilter) {
        final normalizedKeyword = TextNormalizer.normalize(
          match.keyword,
          applySlang: true,
        );
        final isFinancialKw = financialIndicatorKeywords.any(
          (fin) => normalizedKeyword.contains(fin),
        );
        if (isFinancialKw) {
          final normalizedSuffix = TextNormalizer.normalize(
            suffixText,
            applySlang: true,
          );
          for (final term in familyTerms) {
            if (normalizedSuffix.contains(term)) {
              shouldFilter = true;
              break;
            }
          }
        }
      }

      if (!shouldFilter && globalSafeCount >= 2) {
        shouldFilter = true;
      }

      if (!shouldFilter) {
        filtered.add(match);
      } else {
        logger?.debug(
          'Negative lookahead filtered match: "${match.keyword}" at [${match.startIndex}, ${match.endIndex}]',
        );
      }
    }

    return filtered;
  }

  static Set<KeywordMatch> applyRiskDensity(
    Set<KeywordMatch> matches,
    int totalTokens,
  ) {
    if (matches.length < 2) return matches;

    final sortedMatches = matches.toList()
      ..sort((a, b) => a.startIndex.compareTo(b.startIndex));
    final result = <KeywordMatch>{};
    final processedIndices = <int>{};

    for (int i = 0; i < sortedMatches.length; i++) {
      if (processedIndices.contains(i)) continue;

      final match = sortedMatches[i];
      if (match.level == RiskLevel.yellow || match.level == RiskLevel.orange) {
        var denseCount = 1;
        var endIndex = match.endIndex;
        final cluster = <KeywordMatch>[match];
        final clusterIndices = <int>[i];

        for (int j = i + 1; j < sortedMatches.length; j++) {
          final nextMatch = sortedMatches[j];
          if (nextMatch.startIndex - match.startIndex <= 10) {
            if (nextMatch.level == RiskLevel.yellow ||
                nextMatch.level == RiskLevel.orange) {
              denseCount++;
              endIndex = nextMatch.endIndex > endIndex
                  ? nextMatch.endIndex
                  : endIndex;
              cluster.add(nextMatch);
              clusterIndices.add(j);
            }
          } else {
            break;
          }
        }

        if (denseCount >= 3) {
          result.add(
            KeywordMatch(
              keyword: cluster.map((m) => m.keyword).join(' + '),
              level: RiskLevel.red,
              category: 'Mật độ rủi ro cao (Risk Density)',
              startIndex: match.startIndex,
              endIndex: endIndex,
            ),
          );
          processedIndices.addAll(clusterIndices);
          continue;
        }
      }
      result.add(match);
    }
    return result;
  }
}
