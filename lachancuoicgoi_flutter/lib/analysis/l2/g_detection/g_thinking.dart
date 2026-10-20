import '../../../core/risk_level.dart';
import '../../analysis_result.dart';
import '../../common/fuzzy_matcher.dart';
import '../../common/text_normalizer.dart';
import 'g_models.dart';
import 'g_thinking_models.dart';

class GThinking {
  GThinking._(this._tier1Topics, this._tier2Urgency, this._tier3Pii);

  static GThinking _instance = GThinking._(
    const <String>{},
    const <String>{},
    const <String>{},
  );

  final Set<String> _tier1Topics;
  final Set<String> _tier2Urgency;
  final Set<String> _tier3Pii;

  factory GThinking.withConfig({
    required Set<String> tier1,
    required Set<String> tier2,
    required Set<String> tier3,
  }) {
    return GThinking._(
      tier1.map(_normalizeTierText).toSet(),
      tier2.map(_normalizeTierText).toSet(),
      tier3.map(_normalizeTierText).toSet(),
    );
  }

  static void loadTierConfig({
    required Set<String> tier1,
    required Set<String> tier2,
    required Set<String> tier3,
  }) {
    _instance = GThinking.withConfig(tier1: tier1, tier2: tier2, tier3: tier3);
  }

  static bool get isTierConfigLoaded =>
      _instance._tier1Topics.isNotEmpty ||
      _instance._tier2Urgency.isNotEmpty ||
      _instance._tier3Pii.isNotEmpty;

  static GResult analyze({
    required Set<KeywordMatch> allMatchedKeywords,
    List<MatchedPattern> matchedPatterns = const <MatchedPattern>[],
    required String? topTopic,
    double contextScore = 0,
    ScenarioMatch? scenarioMatch,
    SentenceMatch? sentenceMatch,
    ScoringConfig config = const ScoringConfig(),
  }) {
    return _instance.analyzeInstance(
      allMatchedKeywords: allMatchedKeywords,
      matchedPatterns: matchedPatterns,
      topTopic: topTopic,
      contextScore: contextScore,
      scenarioMatch: scenarioMatch,
      sentenceMatch: sentenceMatch,
      config: config,
    );
  }

  GResult analyzeInstance({
    required Set<KeywordMatch> allMatchedKeywords,
    List<MatchedPattern> matchedPatterns = const <MatchedPattern>[],
    required String? topTopic,
    double contextScore = 0,
    ScenarioMatch? scenarioMatch,
    SentenceMatch? sentenceMatch,
    ScoringConfig config = const ScoringConfig(),
  }) {
    final sentenceResult = _evaluateSentenceMatch(
      allMatchedKeywords: allMatchedKeywords,
      sentenceMatch: sentenceMatch,
    );
    if (sentenceResult != null) return sentenceResult;

    final tier = _classifyTiers(allMatchedKeywords);
    final baseHighestKeywordRisk = _highestRisk(allMatchedKeywords);
    final totalPatternScore = matchedPatterns
        .fold<double>(0, (sum, pattern) => sum + pattern.score)
        .clamp(0.0, 1.0);
    final strongestPatternScore = matchedPatterns.fold<double>(
      0,
      (max, pattern) => pattern.score > max ? pattern.score : max,
    );

    final aggregated = _aggregateRisk(
      tier: tier,
      matchedPatterns: matchedPatterns,
      topTopic: topTopic,
      contextScore: contextScore,
      scenarioMatch: scenarioMatch,
      config: config,
      baseHighestKeywordRisk: baseHighestKeywordRisk,
      totalPatternScore: totalPatternScore,
      strongestPatternScore: strongestPatternScore,
    );

    return _finalizeResult(
      tier: tier,
      aggregated: aggregated,
      allMatchedKeywords: allMatchedKeywords,
      matchedPatterns: matchedPatterns,
      topTopic: topTopic,
      contextScore: contextScore,
      scenarioMatch: scenarioMatch,
      hasGoodScenarioMatch: aggregated.hasGoodScenarioMatch,
      baseHighestKeywordRisk: baseHighestKeywordRisk,
      totalPatternScore: totalPatternScore,
      config: config,
    );
  }

  static GResult? _evaluateSentenceMatch({
    required Set<KeywordMatch> allMatchedKeywords,
    required SentenceMatch? sentenceMatch,
  }) {
    if (sentenceMatch == null) return null;

    if (!sentenceMatch.isSafe) {
      final level = RiskLevel.fromInt(sentenceMatch.level);
      return GResult(
        riskLevel: level,
        reason: "Phát hiện câu thoại nguy hiểm: '${sentenceMatch.sentence}'",
        allMatchedKeywords: allMatchedKeywords,
        sentenceMatch: sentenceMatch,
        riskScore: const RiskScore(
          keywordScore: 1,
          topicScore: 1,
          patternScore: 1,
          contextScore: 1,
          sentenceScore: 1,
          finalScore: 1,
        ),
        alertEnabled: true,
      );
    }

    return GResult(
      riskLevel: RiskLevel.green,
      reason: "Phát hiện nội dung an toàn: '${sentenceMatch.sentence}'",
      allMatchedKeywords: allMatchedKeywords,
      sentenceMatch: sentenceMatch,
      riskScore: const RiskScore(
        keywordScore: 0,
        topicScore: 0,
        patternScore: 0,
        contextScore: 0,
        sentenceScore: -1,
        finalScore: 0,
      ),
      alertEnabled: false,
    );
  }

  TierClassification _classifyTiers(Set<KeywordMatch> allMatchedKeywords) {
    final tier3Matches = <KeywordMatch>[];
    final tier2Matches = <KeywordMatch>[];
    final tier1Matches = <KeywordMatch>[];

    for (final kw in allMatchedKeywords) {
      final normalizedKw = _normalizeTierText(kw.keyword);

      if (_tier3Pii.any((pii) => _matchesWholeWord(normalizedKw, pii))) {
        tier3Matches.add(kw);
      } else if (_fuzzyMatchTier(normalizedKw, _tier3Pii)) {
        tier3Matches.add(kw);
      } else if (_tier2Urgency.any(
        (urgent) => _matchesWholeWord(normalizedKw, urgent),
      )) {
        tier2Matches.add(kw);
      } else if (_fuzzyMatchTier(normalizedKw, _tier2Urgency)) {
        tier2Matches.add(kw);
      } else if (_tier1Topics.any(
        (topic) => _matchesWholeWord(normalizedKw, topic),
      )) {
        tier1Matches.add(kw);
      } else if (_fuzzyMatchTier(normalizedKw, _tier1Topics)) {
        tier1Matches.add(kw);
      }
    }

    final tier1Score = _computeTierScore(tier1Matches.length);
    final tier2Score = _computeTierScore(tier2Matches.length);
    final tier3Score = tier3Matches.isNotEmpty ? 1.0 : 0.0;

    final allTierMatches = [...tier1Matches, ...tier2Matches, ...tier3Matches];
    final hasCluster = _detectKeywordCluster(allTierMatches);

    return TierClassification(
      tier1Matches: tier1Matches,
      tier2Matches: tier2Matches,
      tier3Matches: tier3Matches,
      hasTier1: tier1Matches.isNotEmpty,
      hasTier2: tier2Matches.isNotEmpty,
      hasTier3: tier3Matches.isNotEmpty,
      tier1Count: tier1Matches.length,
      tier2Count: tier2Matches.length,
      tier1Score: tier1Score,
      tier2Score: tier2Score,
      tier3Score: tier3Score,
      hasCluster: hasCluster,
    );
  }

  static bool _fuzzyMatchTier(String normalizedKw, Set<String> tierSet) {
    if (normalizedKw.length < 4) return false;
    for (final tierWord in tierSet) {
      if (tierWord.length < 4) continue;
      final dist = FuzzyMatcher.damerauLevenshtein(
        normalizedKw,
        tierWord,
        maxDistance: 1,
      );
      if (dist <= 1) return true;
    }
    return false;
  }

  static double _computeTierScore(int matchCount) {
    if (matchCount <= 0) return 0.0;
    if (matchCount == 1) return 0.3;
    if (matchCount == 2) return 0.5;
    if (matchCount == 3) return 0.7;
    return 1.0;
  }

  static bool _detectKeywordCluster(List<KeywordMatch> matches) {
    if (matches.length < 2) return false;

    final positioned = matches.where((m) => m.startIndex >= 0).toList()
      ..sort((a, b) => a.startIndex.compareTo(b.startIndex));

    if (positioned.length < 2) return false;

    for (var i = 0; i < positioned.length - 1; i++) {
      final gap = positioned[i + 1].startIndex - positioned[i].endIndex;
      if (gap <= 5) return true;
    }
    return false;
  }

  static AggregatedRisk _aggregateRisk({
    required TierClassification tier,
    required List<MatchedPattern> matchedPatterns,
    required String? topTopic,
    required double contextScore,
    required ScenarioMatch? scenarioMatch,
    required ScoringConfig config,
    required RiskLevel baseHighestKeywordRisk,
    required double totalPatternScore,
    required double strongestPatternScore,
  }) {
    final hasGoodScenarioMatch =
        scenarioMatch != null &&
        scenarioMatch.similarityScore >= config.scenarioAlertThreshold;

    var (finalLevel, finalReason) = _escalateByTier(
      tier: tier,
      matchedPatterns: matchedPatterns,
      scenarioMatch: scenarioMatch,
      config: config,
      baseHighestKeywordRisk: baseHighestKeywordRisk,
      contextScore: contextScore,
    );

    if (hasGoodScenarioMatch) {
      final scenarioLevel = RiskLevel.fromInt(scenarioMatch.level);
      if (scenarioLevel.index > finalLevel.index) {
        final isCharity =
            scenarioMatch.group == 'CHARITY_DONATION' ||
            scenarioMatch.situationName.toLowerCase().contains('chữ thập đỏ');
        if (isCharity && !tier.hasTier2 && !tier.hasTier3) {
          if (finalLevel.index < RiskLevel.yellow.index) {
            finalLevel = RiskLevel.yellow;
          }
          finalReason = 'Chú ý: Có nhắc đến quyên góp/từ thiện';
        } else {
          finalLevel = scenarioLevel;
          finalReason = 'Tình huống: ${scenarioMatch.situationName}';
        }
      }
    }

    if (matchedPatterns.isNotEmpty) {
      final patternLevel = switch (strongestPatternScore) {
        >= 0.75 => RiskLevel.red,
        >= 0.45 when baseHighestKeywordRisk.index >= RiskLevel.orange.index =>
          RiskLevel.red,
        _ when totalPatternScore >= 0.5 => RiskLevel.orange,
        >= 0.3 => RiskLevel.yellow,
        _ => RiskLevel.green,
      };
      if (patternLevel.index > finalLevel.index) {
        finalLevel = patternLevel;
        finalReason =
            'Phát hiện mẫu câu rủi ro: ${matchedPatterns.first.patternId}';
      }
    }

    if (tier.hasTier1 &&
        hasGoodScenarioMatch &&
        scenarioMatch.level >= 3 &&
        finalLevel.index < RiskLevel.red.index) {
      finalLevel = RiskLevel.red;
      finalReason =
          'CẢNH BÁO: Kịch bản nguy hiểm xác nhận - ${scenarioMatch.situationName}';
    }

    return AggregatedRisk(
      finalLevel: finalLevel,
      finalReason: finalReason,
      hasGoodScenarioMatch: hasGoodScenarioMatch,
    );
  }

  static (RiskLevel, String) _escalateByTier({
    required TierClassification tier,
    required List<MatchedPattern> matchedPatterns,
    required ScenarioMatch? scenarioMatch,
    required ScoringConfig config,
    required RiskLevel baseHighestKeywordRisk,
    required double contextScore,
  }) {
    if (tier.hasTier3) {
      return (
        RiskLevel.red,
        'CẢNH BÁO: Yêu cầu thông tin nhạy cảm / Lệnh chuyển tiền (Tầng 3)',
      );
    }

    if (tier.hasTier1 &&
        tier.hasTier2 &&
        tier.tier1Count >= 2 &&
        tier.tier2Count >= 2) {
      if (_hasCorroboratingEvidence(
        matchedPatterns: matchedPatterns,
        scenarioMatch: scenarioMatch,
        config: config,
        baseHighestKeywordRisk: baseHighestKeywordRisk,
        tier1Count: tier.tier1Count,
        tier2Count: tier.tier2Count,
      )) {
        return (
          RiskLevel.red,
          'CẢNH BÁO: Kịch bản lừa đảo điển hình (${tier.tier1Count} chủ đề + ${tier.tier2Count} ép buộc)',
        );
      }
      return (
        RiskLevel.orange,
        'Cảnh báo: Dấu hiệu lừa đảo ban đầu, cần thêm bằng chứng (Tầng 1+2)',
      );
    }

    if (tier.hasTier1 && tier.hasTier2) {
      return (RiskLevel.orange, 'Cảnh báo: Chủ đề nhạy cảm + Thúc ép (Tầng 2)');
    }

    if (tier.hasTier1 && contextScore >= 0.3) {
      return (
        RiskLevel.orange,
        'Cảnh báo: Tập trung từ khóa nhạy cảm ở đầu cuộc gọi',
      );
    }

    if (tier.hasTier1) {
      return (
        RiskLevel.yellow,
        'Chú ý: Đang nhắc đến chủ đề nhạy cảm (Tầng 1)',
      );
    }

    return (RiskLevel.green, '');
  }

  static GResult _finalizeResult({
    required TierClassification tier,
    required AggregatedRisk aggregated,
    required Set<KeywordMatch> allMatchedKeywords,
    required List<MatchedPattern> matchedPatterns,
    required String? topTopic,
    required double contextScore,
    required ScenarioMatch? scenarioMatch,
    required bool hasGoodScenarioMatch,
    required RiskLevel baseHighestKeywordRisk,
    required double totalPatternScore,
    required ScoringConfig config,
  }) {
    final finalLevel = aggregated.finalLevel;
    final finalReason = aggregated.finalReason;
    final upgradedKeywords = _upgradeKeywordLevels(
      allMatchedKeywords,
      tier,
      finalLevel,
    );

    if (tier.hasTier3) {
      return GResult(
        riskLevel: RiskLevel.red,
        reason:
            'CẢNH BÁO: Yêu cầu thông tin nhạy cảm (${tier.tier3Matches.map((kw) => kw.keyword).join(', ')})',
        allMatchedKeywords: upgradedKeywords,
        confirmedSituation: hasGoodScenarioMatch
            ? scenarioMatch?.situationName
            : (tier.hasTier1 ? 'Chủ đề nhạy cảm' : null),
        matchedPatterns: matchedPatterns,
        mostLikelyScenario: scenarioMatch,
        sentenceMatch: null,
        riskScore: _buildRiskScore(
          upgradedKeywords,
          topTopic,
          scenarioMatch,
          contextScore,
          totalPatternScore,
          config.weights,
        ),
        alertEnabled: true,
      );
    }

    final reason = finalReason.isEmpty
        ? 'Không phát hiện dấu hiệu rủi ro'
        : finalReason;
    return GResult(
      riskLevel: finalLevel,
      reason: reason,
      allMatchedKeywords: upgradedKeywords,
      confirmedSituation: hasGoodScenarioMatch
          ? scenarioMatch?.situationName
          : (tier.hasTier1 ? 'Chủ đề nhạy cảm' : null),
      matchedPatterns: matchedPatterns,
      mostLikelyScenario: scenarioMatch,
      sentenceMatch: null,
      riskScore: _buildRiskScore(
        upgradedKeywords,
        topTopic,
        scenarioMatch,
        contextScore,
        totalPatternScore,
        config.weights,
      ),
      alertEnabled: finalLevel != RiskLevel.green,
    );
  }

  static Set<KeywordMatch> _upgradeKeywordLevels(
    Set<KeywordMatch> allMatchedKeywords,
    TierClassification tier,
    RiskLevel finalLevel,
  ) {
    return allMatchedKeywords.map((kw) {
      var newLevel = kw.level;
      if (tier.tier3Matches.contains(kw) && finalLevel == RiskLevel.red) {
        newLevel = RiskLevel.red;
      } else if (tier.tier2Matches.contains(kw) &&
          finalLevel.index >= RiskLevel.orange.index &&
          newLevel.index < RiskLevel.orange.index) {
        newLevel = RiskLevel.orange;
      } else if (tier.tier1Matches.contains(kw) &&
          finalLevel.index >= RiskLevel.yellow.index &&
          newLevel.index < RiskLevel.yellow.index) {
        newLevel = RiskLevel.yellow;
      }
      return newLevel != kw.level ? kw.copyWith(level: newLevel) : kw;
    }).toSet();
  }

  static RiskScore _buildRiskScore(
    Set<KeywordMatch> upgradedKeywords,
    String? topTopic,
    ScenarioMatch? scenarioMatch,
    double contextScore,
    double totalPatternScore,
    ScoringWeights weights,
  ) {
    final highestKeywordRisk = _highestRisk(upgradedKeywords);
    final keywordFinalScore = switch (highestKeywordRisk) {
      RiskLevel.red => 1.0,
      RiskLevel.orange => 0.7,
      RiskLevel.yellow => 0.4,
      RiskLevel.green => 0.0,
    };
    final topicScoreValue = topTopic != null ? 1.0 : 0.0;
    final scenarioScoreValue = scenarioMatch?.similarityScore ?? 0.0;
    final weightedFinalScore =
        (weights.keyword * keywordFinalScore +
                weights.topic * topicScoreValue +
                weights.pattern * totalPatternScore +
                weights.scenario * scenarioScoreValue +
                weights.context * contextScore)
            .clamp(0.0, 1.0);

    return RiskScore(
      keywordScore: keywordFinalScore,
      topicScore: topicScoreValue,
      patternScore: totalPatternScore,
      scenarioScore: scenarioScoreValue,
      contextScore: contextScore,
      finalScore: weightedFinalScore,
    );
  }

  static bool _hasCorroboratingEvidence({
    required List<MatchedPattern> matchedPatterns,
    required ScenarioMatch? scenarioMatch,
    required ScoringConfig config,
    required RiskLevel baseHighestKeywordRisk,
    required int tier1Count,
    required int tier2Count,
  }) {
    return matchedPatterns.isNotEmpty ||
        (scenarioMatch != null &&
            scenarioMatch.similarityScore >=
                config.scenarioAlertThreshold * 0.8) ||
        baseHighestKeywordRisk.index >= RiskLevel.orange.index ||
        (tier1Count >= 3 && tier2Count >= 3);
  }

  static RiskLevel _highestRisk(Iterable<KeywordMatch> matches) {
    var highest = RiskLevel.green;
    for (final match in matches) {
      if (match.level.index > highest.index) highest = match.level;
    }
    return highest;
  }

  static String _normalizeTierText(String text) {
    return TextNormalizer.normalize(
      text,
      applySlang: false,
      noiseMode: NoiseMode.space,
    );
  }

  static bool _matchesWholeWord(String token, String target) {
    if (target.isEmpty) return false;
    var searchFrom = 0;
    while (searchFrom < token.length) {
      final idx = token.indexOf(target, searchFrom);
      if (idx < 0) return false;
      final leftBoundary = idx == 0 || token[idx - 1].trim().isEmpty;
      final end = idx + target.length;
      final rightBoundary = end == token.length || token[end].trim().isEmpty;
      if (leftBoundary && rightBoundary) return true;
      searchFrom = idx + 1;
    }
    return false;
  }
}
