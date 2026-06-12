import '../../../core/risk_level.dart';
import '../../analysis_result.dart';

class GResult {
  const GResult({
    required this.riskLevel,
    required this.reason,
    this.allMatchedKeywords = const <KeywordMatch>{},
    this.confirmedSituation,
    this.matchedPatterns = const <MatchedPattern>[],
    this.riskScore,
    this.sentenceMatch,
    this.mostLikelyScenario,
    this.alertEnabled = false,
  });

  final RiskLevel riskLevel;
  final String reason;
  final Set<KeywordMatch> allMatchedKeywords;
  final String? confirmedSituation;
  final List<MatchedPattern> matchedPatterns;
  final RiskScore? riskScore;
  final SentenceMatch? sentenceMatch;
  final ScenarioMatch? mostLikelyScenario;
  final bool alertEnabled;
}

class RiskScore {
  const RiskScore({
    required this.keywordScore,
    required this.topicScore,
    required this.patternScore,
    required this.contextScore,
    this.sentenceScore = 0,
    this.scenarioScore = 0,
    required this.finalScore,
  });

  final double keywordScore;
  final double topicScore;
  final double patternScore;
  final double contextScore;
  final double sentenceScore;
  final double scenarioScore;
  final double finalScore;
}

class SituationMatchResult {
  const SituationMatchResult({
    this.confirmedSituationName,
    this.allMatchedSituations = const <String?, double>{},
  });

  final String? confirmedSituationName;
  final Map<String?, double> allMatchedSituations;
}

class SentenceMatch {
  const SentenceMatch({
    required this.sentence,
    required this.level,
    this.isSafe = false,
  });

  final String sentence;
  final int level;
  final bool isSafe;
}

class ScenarioMatch {
  const ScenarioMatch({
    required this.scenarioId,
    required this.situationName,
    required this.similarityScore,
    this.group,
    this.level = 0,
  });

  final int scenarioId;
  final String situationName;
  final double similarityScore;
  final String? group;
  final int level;
}

class KeywordTrieData {
  const KeywordTrieData({
    required this.riskLevel,
    required this.category,
    required this.originalKeyword,
  });

  final RiskLevel riskLevel;
  final String category;
  final String originalKeyword;
}

class TrieNode {
  final Map<String, TrieNode> children = <String, TrieNode>{};
  KeywordTrieData? keywordData;
}

class RiskModelVocabulary {
  const RiskModelVocabulary({this.riskLevels});

  final List<RiskLevelData>? riskLevels;

  factory RiskModelVocabulary.fromJson(Map<String, Object?> json) {
    return RiskModelVocabulary(
      riskLevels: _readList(json['riskLevels'], RiskLevelData.fromJson),
    );
  }
}

class RiskLevelData {
  const RiskLevelData({required this.level, this.keywords, this.threats});

  final int level;
  final List<String>? keywords;
  final Map<String, List<String>>? threats;

  factory RiskLevelData.fromJson(Map<String, Object?> json) {
    final rawThreats = json['threats'];
    return RiskLevelData(
      level: (json['level'] as num?)?.toInt() ?? 0,
      keywords: _readStringList(json['keywords']),
      threats: rawThreats is Map
          ? rawThreats.map(
              (key, value) => MapEntry(
                key.toString(),
                _readStringList(value) ?? const <String>[],
              ),
            )
          : null,
    );
  }
}

class AiCheckModel {
  const AiCheckModel({this.situations});

  final List<AiCheckSituation>? situations;

  factory AiCheckModel.fromJson(Map<String, Object?> json) {
    return AiCheckModel(
      situations: _readList(json['situations'], AiCheckSituation.fromJson),
    );
  }
}

class AiCheckSituation {
  const AiCheckSituation({
    required this.name,
    this.triggerPhrases,
    this.requiredContext,
    this.riskLevel,
  });

  final String name;
  final List<String>? triggerPhrases;
  final List<String>? requiredContext;
  final String? riskLevel;

  factory AiCheckSituation.fromJson(Map<String, Object?> json) {
    return AiCheckSituation(
      name: json['name'] as String? ?? '',
      triggerPhrases: _readStringList(json['trigger_phrases']),
      requiredContext: _readStringList(json['required_context']),
      riskLevel: json['risk_level'] as String?,
    );
  }
}

class TierConfig {
  const TierConfig({this.tier1Topics, this.tier2Urgency, this.tier3Pii});

  final List<String>? tier1Topics;
  final List<String>? tier2Urgency;
  final List<String>? tier3Pii;

  factory TierConfig.fromJson(Map<String, Object?> json) {
    return TierConfig(
      tier1Topics: _readStringList(json['tier1_topics']),
      tier2Urgency: _readStringList(json['tier2_urgency']),
      tier3Pii: _readStringList(json['tier3_pii']),
    );
  }
}

class ScoringConfig {
  const ScoringConfig({
    this.topicConfirmationThreshold = 3,
    this.scenarioSimilarityThreshold = 0.3,
    this.scenarioAlertThreshold = 0.6,
    this.highKeywordThreshold = 0.5,
    this.riskLevelThresholds = const RiskThresholds(),
    this.weights = const ScoringWeights(),
  });

  final int topicConfirmationThreshold;
  final double scenarioSimilarityThreshold;
  final double scenarioAlertThreshold;
  final double highKeywordThreshold;
  final RiskThresholds riskLevelThresholds;
  final ScoringWeights weights;

  factory ScoringConfig.fromJson(Map<String, Object?> json) {
    return ScoringConfig(
      topicConfirmationThreshold:
          (json['topicConfirmationThreshold'] as num?)?.toInt() ?? 3,
      scenarioSimilarityThreshold:
          (json['scenarioSimilarityThreshold'] as num?)?.toDouble() ?? 0.3,
      scenarioAlertThreshold:
          (json['scenario_alert_threshold'] as num?)?.toDouble() ?? 0.6,
      highKeywordThreshold:
          (json['high_keyword_threshold'] as num?)?.toDouble() ?? 0.5,
      riskLevelThresholds: json['riskLevelThresholds'] is Map
          ? RiskThresholds.fromJson(
              (json['riskLevelThresholds'] as Map).cast<String, Object?>(),
            )
          : const RiskThresholds(),
      weights: json['weights'] is Map
          ? ScoringWeights.fromJson(
              (json['weights'] as Map).cast<String, Object?>(),
            )
          : const ScoringWeights(),
    );
  }
}

class RiskThresholds {
  const RiskThresholds({
    this.red = 0.70,
    this.orange = 0.50,
    this.yellow = 0.30,
  });

  final double red;
  final double orange;
  final double yellow;

  factory RiskThresholds.fromJson(Map<String, Object?> json) {
    return RiskThresholds(
      red: (json['red'] as num?)?.toDouble() ?? 0.70,
      orange: (json['orange'] as num?)?.toDouble() ?? 0.50,
      yellow: (json['yellow'] as num?)?.toDouble() ?? 0.30,
    );
  }
}

class ScoringWeights {
  const ScoringWeights({
    this.keyword = 0.20,
    this.topic = 0.15,
    this.pattern = 0.25,
    this.scenario = 0.25,
    this.context = 0.10,
    this.sentiment = 0.05,
  });

  final double keyword;
  final double topic;
  final double pattern;
  final double scenario;
  final double context;
  final double sentiment;

  factory ScoringWeights.fromJson(Map<String, Object?> json) {
    return ScoringWeights(
      keyword: (json['keyword'] as num?)?.toDouble() ?? 0.20,
      topic: (json['topic'] as num?)?.toDouble() ?? 0.15,
      pattern: (json['pattern'] as num?)?.toDouble() ?? 0.25,
      scenario: (json['scenario'] as num?)?.toDouble() ?? 0.25,
      context: (json['context'] as num?)?.toDouble() ?? 0.10,
      sentiment: (json['sentiment'] as num?)?.toDouble() ?? 0.05,
    );
  }
}

class RiskModelSentences {
  const RiskModelSentences({this.riskLevels});

  final List<RiskSentenceLevel>? riskLevels;

  factory RiskModelSentences.fromJson(Map<String, Object?> json) {
    return RiskModelSentences(
      riskLevels: _readList(json['riskLevels'], RiskSentenceLevel.fromJson),
    );
  }
}

class RiskSentenceLevel {
  const RiskSentenceLevel({
    required this.level,
    this.vietnameseName,
    this.sentences,
    this.threats,
  });

  final int level;
  final String? vietnameseName;
  final List<String>? sentences;
  final Map<String, List<String>>? threats;

  factory RiskSentenceLevel.fromJson(Map<String, Object?> json) {
    final rawThreats = json['threats'];
    return RiskSentenceLevel(
      level: (json['level'] as num?)?.toInt() ?? 0,
      vietnameseName: json['vietnameseName'] as String?,
      sentences: _readStringList(json['sentences']),
      threats: rawThreats is Map
          ? rawThreats.map(
              (key, value) => MapEntry(
                key.toString(),
                _readStringList(value) ?? const <String>[],
              ),
            )
          : null,
    );
  }
}

class ScamPattern {
  const ScamPattern({
    required this.id,
    required this.description,
    required this.template,
    this.riskBonus = 0.5,
    this.minGap = 0,
    this.maxGap = 5,
  });

  final String id;
  final String description;
  final List<PatternElement> template;
  final double riskBonus;
  final int minGap;
  final int maxGap;
}

sealed class PatternElement {
  const PatternElement();

  factory PatternElement.fromJson(Map<String, Object?> json) {
    final type = (json['type'] as String? ?? '').toLowerCase();
    final value = json['value'] as String? ?? '';
    return switch (type) {
      'keyword' => PatternKeyword(value),
      'category' => PatternCategory(value),
      'wildcard' => const PatternWildcard(),
      _ => PatternKeyword(value),
    };
  }
}

class PatternKeyword extends PatternElement {
  const PatternKeyword(this.value);

  final String value;
}

class PatternCategory extends PatternElement {
  const PatternCategory(this.categoryName);

  final String categoryName;
}

class PatternWildcard extends PatternElement {
  const PatternWildcard();
}

class MatchedPattern {
  const MatchedPattern({
    required this.patternId,
    required this.matchedElements,
    required this.score,
  });

  final String patternId;
  final List<String> matchedElements;
  final double score;
}

class PatternConfigDTO {
  const PatternConfigDTO({this.patterns});

  final List<ScamPatternDTO>? patterns;

  factory PatternConfigDTO.fromJson(Map<String, Object?> json) {
    return PatternConfigDTO(
      patterns: _readList(json['patterns'], ScamPatternDTO.fromJson),
    );
  }
}

class ScamPatternDTO {
  const ScamPatternDTO({
    required this.id,
    this.description,
    this.riskBonus,
    this.minGap,
    this.maxGap,
    this.template,
  });

  final String id;
  final String? description;
  final double? riskBonus;
  final int? minGap;
  final int? maxGap;
  final List<PatternElement>? template;

  factory ScamPatternDTO.fromJson(Map<String, Object?> json) {
    return ScamPatternDTO(
      id: json['id']?.toString() ?? '',
      description: json['description'] as String?,
      riskBonus: (json['risk_bonus'] as num?)?.toDouble(),
      minGap: (json['min_gap'] as num?)?.toInt(),
      maxGap: (json['max_gap'] as num?)?.toInt(),
      template: _readList(json['template'], PatternElement.fromJson),
    );
  }

  ScamPattern toDomain() {
    return ScamPattern(
      id: id,
      description: description ?? '',
      template: template ?? const <PatternElement>[],
      riskBonus: riskBonus ?? 0.5,
      minGap: minGap ?? 0,
      maxGap: maxGap ?? 5,
    );
  }
}

class RiskScenariosMaster {
  const RiskScenariosMaster({
    this.title,
    this.version,
    this.description,
    this.totalScenarios,
    this.scenarios,
  });

  final String? title;
  final String? version;
  final String? description;
  final int? totalScenarios;
  final List<MasterScenario>? scenarios;

  factory RiskScenariosMaster.fromJson(Map<String, Object?> json) {
    return RiskScenariosMaster(
      title: json['title'] as String?,
      version: json['version'] as String?,
      description: json['description'] as String?,
      totalScenarios: (json['total_scenarios'] as num?)?.toInt(),
      scenarios: _readList(json['scenarios'], MasterScenario.fromJson),
    );
  }
}

class MasterScenario {
  const MasterScenario({
    required this.id,
    this.source,
    this.originalId,
    required this.name,
    this.description,
    required this.riskLevel,
    this.riskLevelName,
    this.riskColor,
    this.category,
    this.subCategory,
    this.triggerPhrases,
    this.requiredContext,
    this.dialogueSamples,
    this.redFlags,
    this.l2AnalysisHints,
  });

  final String id;
  final String? source;
  final String? originalId;
  final String name;
  final String? description;
  final int riskLevel;
  final String? riskLevelName;
  final String? riskColor;
  final String? category;
  final String? subCategory;
  final List<String>? triggerPhrases;
  final List<String>? requiredContext;
  final List<String>? dialogueSamples;
  final List<String>? redFlags;
  final L2AnalysisHints? l2AnalysisHints;

  factory MasterScenario.fromJson(Map<String, Object?> json) {
    return MasterScenario(
      id: json['id']?.toString() ?? '',
      source: json['source'] as String?,
      originalId: json['original_id']?.toString(),
      name: json['name'] as String? ?? '',
      description: json['description'] as String?,
      riskLevel: (json['risk_level'] as num?)?.toInt() ?? 0,
      riskLevelName: json['risk_level_name'] as String?,
      riskColor: json['risk_color'] as String?,
      category: json['category'] as String?,
      subCategory: json['sub_category'] as String?,
      triggerPhrases: _readStringList(json['trigger_phrases']),
      requiredContext: _readStringList(json['required_context']),
      dialogueSamples: _readStringList(json['dialogue_samples']),
      redFlags: _readStringList(json['red_flags']),
      l2AnalysisHints: json['l2_analysis_hints'] is Map
          ? L2AnalysisHints.fromJson(
              (json['l2_analysis_hints'] as Map).cast<String, Object?>(),
            )
          : null,
    );
  }
}

class L2AnalysisHints {
  const L2AnalysisHints({
    this.urgencyLevel,
    this.authorityClaim,
    this.financialRequest,
    this.informationRequest,
    this.psychologicalTactics,
  });

  final String? urgencyLevel;
  final bool? authorityClaim;
  final bool? financialRequest;
  final List<String>? informationRequest;
  final List<String>? psychologicalTactics;

  factory L2AnalysisHints.fromJson(Map<String, Object?> json) {
    return L2AnalysisHints(
      urgencyLevel: json['urgency_level'] as String?,
      authorityClaim: json['authority_claim'] as bool?,
      financialRequest: json['financial_request'] as bool?,
      informationRequest: _readStringList(json['information_request']),
      psychologicalTactics: _readStringList(json['psychological_tactics']),
    );
  }
}

List<T>? _readList<T>(
  Object? raw,
  T Function(Map<String, Object?> json) parse,
) {
  if (raw is! List) return null;
  return raw
      .whereType<Map>()
      .map((item) => parse(item.cast<String, Object?>()))
      .toList();
}

List<String>? _readStringList(Object? raw) {
  if (raw is! List) return null;
  return raw.map((item) => item.toString()).toList();
}
