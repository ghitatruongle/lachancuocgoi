import '../../../core/risk_level.dart';
import '../../analysis_result.dart';
import '../../common/text_normalizer.dart';
import 'g_models.dart';

class GThinking {
  GThinking._();

  static Set<String> _tier1Topics = const <String>{};
  static Set<String> _tier2Urgency = const <String>{};
  static Set<String> _tier3Pii = const <String>{};

  static void loadTierConfig({
    required Set<String> tier1,
    required Set<String> tier2,
    required Set<String> tier3,
  }) {
    _tier1Topics = tier1.map(_normalizeTierText).toSet();
    _tier2Urgency = tier2.map(_normalizeTierText).toSet();
    _tier3Pii = tier3.map(_normalizeTierText).toSet();
  }

  static bool get isTierConfigLoaded =>
      _tier1Topics.isNotEmpty ||
      _tier2Urgency.isNotEmpty ||
      _tier3Pii.isNotEmpty;

  static GResult analyze({
    required Set<KeywordMatch> allMatchedKeywords,
    List<MatchedPattern> matchedPatterns = const <MatchedPattern>[],
    required String? topTopic,
    double contextScore = 0,
    ScenarioMatch? scenarioMatch,
    SentenceMatch? sentenceMatch,
    ScoringConfig config = const ScoringConfig(),
  }) {
    if (sentenceMatch != null && !sentenceMatch.isSafe) {
      final level = RiskLevel.fromInt(sentenceMatch.level);
      return GResult(
        riskLevel: level,
        reason: "Phát hiện câu thoại nguy hiểm: '${sentenceMatch.sentence}'",
        allMatchedKeywords: allMatchedKeywords,
        sentenceMatch: sentenceMatch,
        confirmedSituation: topTopic,
        matchedPatterns: matchedPatterns,
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

    if (sentenceMatch != null && sentenceMatch.isSafe) {
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

    final tier3Matches = allMatchedKeywords
        .where(
          (kw) => _tier3Pii.any(
            (pii) => _matchesWholeWord(_normalizeTierText(kw.keyword), pii),
          ),
        )
        .toList();
    final tier2Matches = allMatchedKeywords
        .where(
          (kw) => _tier2Urgency.any(
            (urgent) =>
                _matchesWholeWord(_normalizeTierText(kw.keyword), urgent),
          ),
        )
        .toList();
    final tier1Matches = allMatchedKeywords
        .where(
          (kw) => _tier1Topics.any(
            (topic) => _matchesWholeWord(_normalizeTierText(kw.keyword), topic),
          ),
        )
        .toList();

    final hasTier3 = tier3Matches.isNotEmpty;
    final hasTier2 = tier2Matches.isNotEmpty;
    final hasTier1 = tier1Matches.isNotEmpty;
    final tier1Count = tier1Matches.length;
    final tier2Count = tier2Matches.length;
    final baseHighestKeywordRisk = _highestRisk(allMatchedKeywords);
    final totalPatternScore = matchedPatterns
        .fold<double>(0, (sum, pattern) => sum + pattern.score)
        .clamp(0.0, 1.0);
    final strongestPatternScore = matchedPatterns.fold<double>(
      0,
      (max, pattern) => pattern.score > max ? pattern.score : max,
    );

    var tieredLevel = RiskLevel.green;
    var tieredReason = '';
    if (hasTier3) {
      tieredLevel = RiskLevel.red;
      tieredReason =
          'CẢNH BÁO: Yêu cầu thông tin nhạy cảm / Lệnh chuyển tiền (Tầng 3)';
    } else if (hasTier1 && hasTier2 && tier1Count >= 2 && tier2Count >= 2) {
      tieredLevel = RiskLevel.red;
      tieredReason =
          'CẢNH BÁO: Kịch bản lừa đảo điển hình ($tier1Count chủ đề + $tier2Count ép buộc)';
    } else if (hasTier1 && hasTier2) {
      tieredLevel = RiskLevel.orange;
      tieredReason = 'Cảnh báo: Chủ đề nhạy cảm + Thúc ép (Tầng 2)';
    } else if (hasTier1 && contextScore >= 0.3) {
      tieredLevel = RiskLevel.orange;
      tieredReason = 'Cảnh báo: Tập trung từ khóa nhạy cảm ở đầu cuộc gọi';
    } else if (hasTier1) {
      tieredLevel = RiskLevel.yellow;
      tieredReason = 'Chú ý: Đang nhắc đến chủ đề nhạy cảm (Tầng 1)';
    }

    final hasGoodScenarioMatch =
        scenarioMatch != null &&
        scenarioMatch.similarityScore >= config.scenarioAlertThreshold;
    var finalLevel = tieredLevel;
    var finalReason = tieredReason;

    if (hasGoodScenarioMatch) {
      final scenarioLevel = RiskLevel.fromInt(scenarioMatch.level);
      if (scenarioLevel.index > finalLevel.index) {
        final isCharity =
            scenarioMatch.group == 'CHARITY_DONATION' ||
            scenarioMatch.situationName.toLowerCase().contains('chữ thập đỏ');
        if (isCharity && !hasTier2 && !hasTier3) {
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

    if (hasTier3) {
      finalLevel = RiskLevel.red;
      finalReason =
          'CẢNH BÁO: Yêu cầu thông tin nhạy cảm (${tier3Matches.map((kw) => kw.keyword).join(', ')})';
    }
    if (hasTier1 &&
        hasTier2 &&
        tier1Count >= 2 &&
        tier2Count >= 2 &&
        finalLevel.index < RiskLevel.red.index) {
      finalLevel = RiskLevel.red;
      finalReason =
          'CẢNH BÁO: Kịch bản lừa đảo điển hình xác nhận (${tier1Count}T1 + ${tier2Count}T2)';
    }
    if (hasTier1 &&
        hasGoodScenarioMatch &&
        scenarioMatch.level >= 3 &&
        finalLevel.index < RiskLevel.red.index) {
      finalLevel = RiskLevel.red;
      finalReason =
          'CẢNH BÁO: Kịch bản nguy hiểm xác nhận - ${scenarioMatch.situationName}';
    }

    final updatedKeywords = allMatchedKeywords.map((kw) {
      var newLevel = kw.level;
      if (tier3Matches.contains(kw) && finalLevel == RiskLevel.red) {
        newLevel = RiskLevel.red;
      } else if (tier2Matches.contains(kw) &&
          finalLevel.index >= RiskLevel.orange.index &&
          newLevel.index < RiskLevel.orange.index) {
        newLevel = RiskLevel.orange;
      } else if (tier1Matches.contains(kw) &&
          finalLevel.index >= RiskLevel.yellow.index &&
          newLevel.index < RiskLevel.yellow.index) {
        newLevel = RiskLevel.yellow;
      }
      return newLevel != kw.level ? kw.copyWith(level: newLevel) : kw;
    }).toSet();

    final highestKeywordRisk = _highestRisk(updatedKeywords);
    final keywordFinalScore = switch (highestKeywordRisk) {
      RiskLevel.red => 1.0,
      RiskLevel.orange => 0.7,
      RiskLevel.yellow => 0.4,
      RiskLevel.green => 0.0,
    };
    final topicScoreValue = topTopic != null ? 1.0 : 0.0;
    final scenarioScoreValue = scenarioMatch?.similarityScore ?? 0.0;
    final weights = config.weights;
    final weightedFinalScore =
        (weights.keyword * keywordFinalScore +
                weights.topic * topicScoreValue +
                weights.pattern * totalPatternScore +
                weights.scenario * scenarioScoreValue +
                weights.context * contextScore)
            .clamp(0.0, 1.0);

    return GResult(
      riskLevel: finalLevel,
      reason: finalReason.isEmpty
          ? 'Không phát hiện dấu hiệu rủi ro'
          : finalReason,
      allMatchedKeywords: updatedKeywords,
      confirmedSituation: hasGoodScenarioMatch
          ? scenarioMatch.situationName
          : (hasTier1 ? 'Chủ đề nhạy cảm' : null),
      matchedPatterns: matchedPatterns,
      mostLikelyScenario: scenarioMatch,
      sentenceMatch: sentenceMatch,
      riskScore: RiskScore(
        keywordScore: keywordFinalScore,
        topicScore: topicScoreValue,
        patternScore: totalPatternScore,
        scenarioScore: scenarioScoreValue,
        contextScore: contextScore,
        finalScore: weightedFinalScore,
      ),
      alertEnabled: finalLevel != RiskLevel.green,
    );
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
    final idx = token.indexOf(target);
    if (idx < 0) return false;
    final leftBoundary = idx == 0 || token[idx - 1].trim().isEmpty;
    final end = idx + target.length;
    final rightBoundary = end == token.length || token[end].trim().isEmpty;
    return leftBoundary && rightBoundary;
  }
}
