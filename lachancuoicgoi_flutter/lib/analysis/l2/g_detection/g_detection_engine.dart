import 'dart:async';
import 'dart:convert';

import 'package:flutter/services.dart';

import '../../../core/risk_level.dart';
import '../../analysis_result.dart';
import 'g_flash.dart';
import 'g_models.dart';
import 'g_pattern_matcher.dart';
import 'g_thinking.dart';
import 'scenario_matcher.dart';
import 'sentence_matcher.dart';

typedef GDetectionAssetProvider = FutureOr<String> Function(String fileName);

class GDetectionEngine {
  GDetectionEngine({
    AssetBundle? assetBundle,
    GDetectionAssetProvider? assetProvider,
  }) : _assetBundle = assetBundle ?? rootBundle,
       _assetProvider = assetProvider;

  static const String vocabularyFile = 'risk_model_vocabulary.json';
  static const String aiCheckFile = 'vocabulary_ai_check.json';
  static const String slangFile = 'slang_config.json';
  static const String patternsFile = 'phrase_patterns.json';
  static const String situationFile = 'risk_scenarios_master.json';
  static const String sentencesFile = 'risk_model_sentences.json';
  static const String scoringConfigFile = 'scoring_config.json';
  static const String tierConfigFile = 'tier_config.json';

  static const int _topicConfirmationThreshold = 3;

  final AssetBundle _assetBundle;
  GDetectionAssetProvider? _assetProvider;

  TrieNode _riskKeywordTrie = TrieNode();
  final Map<String, List<String>> _keywordToTopicsMap =
      <String, List<String>>{};
  List<ScamPattern> _scamPatterns = const <ScamPattern>[];
  ScenarioMatcher? _scenarioMatcher;
  SentenceMatcher? _sentenceMatcher;
  ScoringConfig _scoringConfig = const ScoringConfig();

  bool _isReady = false;
  Future<void>? _initializingFuture;

  bool get isReady => _isReady;

  void setAssetProvider(GDetectionAssetProvider provider) {
    _assetProvider = provider;
    _isReady = false;
    _initializingFuture = null;
  }

  Future<void> initialize() {
    if (_isReady) return Future<void>.value();
    return _initializingFuture ??= _doInitialize();
  }

  Future<void> _doInitialize() async {
    _isReady = false;

    // Batch 1: Config nhẹ (slang, scoring, tier) ~50ms
    await Future.wait<void>([
      _loadSlangMap(),
      _loadScoringConfig(),
      _loadTierConfig(),
    ]);
    await Future<void>.delayed(const Duration(milliseconds: 1));

    // Batch 2: Trie/TopicMap/Patterns/Sentences ~200-500ms
    await Future.wait<void>([
      _buildTrie().then((trie) => _riskKeywordTrie = trie),
      _buildTopicMap(),
      _loadPatterns(),
      _loadSituationMatcher(),
      _loadSentenceMatcher(),
    ]);

    _isReady = true;
  }

  Future<GResult> performFullAnalysis(String text) async {
    await initialize();

    if (!_isReady) {
      return const GResult(
        riskLevel: RiskLevel.green,
        reason: 'Hệ thống L2 đang khởi tạo.',
      );
    }

    final tokens = GFlash.tokenize(text);
    if (tokens.isEmpty) {
      return const GResult(
        riskLevel: RiskLevel.green,
        reason: 'Không có nội dung để phân tích.',
      );
    }

    final sentenceMatch = _sentenceMatcher?.match(tokens);
    if (sentenceMatch != null && !sentenceMatch.isSafe) {
      return GThinking.analyze(
        allMatchedKeywords: const <KeywordMatch>{},
        topTopic: null,
        sentenceMatch: sentenceMatch,
        config: _scoringConfig,
      );
    }

    final allMatchedKeywords = _extractKeywordsFromTrie(tokens);
    if (sentenceMatch != null && sentenceMatch.isSafe) {
      return GThinking.analyze(
        allMatchedKeywords: allMatchedKeywords,
        topTopic: null,
        sentenceMatch: sentenceMatch,
        config: _scoringConfig,
      );
    }

    final topTopic = _classifyAndScoreTopics(allMatchedKeywords);
    final matchedPatterns = GPatternMatcher.matchPatterns(
      tokens,
      _scamPatterns,
      allMatchedKeywords,
    );
    final contextScore = calculateContextScore(
      allMatchedKeywords,
      tokens.length,
    );
    final scenarioMatch = _scenarioMatcher?.match(tokens);

    return GThinking.analyze(
      allMatchedKeywords: allMatchedKeywords,
      matchedPatterns: matchedPatterns,
      topTopic: topTopic,
      contextScore: contextScore,
      scenarioMatch: scenarioMatch,
      sentenceMatch: null,
      config: _scoringConfig,
    );
  }

  Future<void> _loadSlangMap() async {
    try {
      final decoded = await _loadJsonMap(slangFile);
      final slangMap = decoded['slang_map'];
      if (slangMap is Map) {
        GFlash.loadSlangConfig(
          slangMap.map(
            (key, value) => MapEntry(key.toString(), value.toString()),
          ),
        );
      }
    } catch (_) {
      GFlash.loadSlangConfig(const <String, String>{});
    }
  }

  Future<void> _loadScoringConfig() async {
    try {
      _scoringConfig = ScoringConfig.fromJson(
        await _loadJsonMap(scoringConfigFile),
      );
    } catch (_) {
      _scoringConfig = const ScoringConfig();
    }
  }

  Future<void> _loadTierConfig() async {
    try {
      final config = TierConfig.fromJson(await _loadJsonMap(tierConfigFile));
      GThinking.loadTierConfig(
        tier1: (config.tier1Topics ?? const <String>[]).toSet(),
        tier2: (config.tier2Urgency ?? const <String>[]).toSet(),
        tier3: (config.tier3Pii ?? const <String>[]).toSet(),
      );
    } catch (_) {
      GThinking.loadTierConfig(
        tier1: const <String>{},
        tier2: const <String>{},
        tier3: const <String>{},
      );
    }
  }

  Future<TrieNode> _buildTrie() async {
    final root = TrieNode();
    try {
      final model = RiskModelVocabulary.fromJson(
        await _loadJsonMap(vocabularyFile),
      );
      for (final riskLevelData in model.riskLevels ?? const <RiskLevelData>[]) {
        final riskLevel = RiskLevel.fromInt(riskLevelData.level);
        final allKeywords = <String>[
          ...(riskLevelData.keywords ?? const <String>[]),
          ...(riskLevelData.threats?.values.expand((items) => items) ??
              const <String>[]),
        ];

        for (final keyword in allKeywords) {
          final processedTokens = GFlash.tokenize(keyword);
          if (processedTokens.isEmpty) continue;

          var currentNode = root;
          for (final token in processedTokens) {
            currentNode = currentNode.children.putIfAbsent(token, TrieNode.new);
          }
          currentNode.keywordData = KeywordTrieData(
            riskLevel: riskLevel,
            category: _categoryForKeyword(riskLevelData, keyword),
            originalKeyword: keyword,
          );
        }
      }
    } catch (_) {
      return root;
    }
    return root;
  }

  Future<void> _buildTopicMap() async {
    _keywordToTopicsMap.clear();
    try {
      final model = AiCheckModel.fromJson(await _loadJsonMap(aiCheckFile));
      for (final situation in model.situations ?? const <AiCheckSituation>[]) {
        final allKeywords = <String>[
          ...(situation.triggerPhrases ?? const <String>[]),
          ...(situation.requiredContext ?? const <String>[]),
        ];
        for (final keyword in allKeywords) {
          final tokenizedKeyword = GFlash.tokenize(keyword);
          if (tokenizedKeyword.isEmpty) continue;
          final key = tokenizedKeyword.join(' ');
          _keywordToTopicsMap
              .putIfAbsent(key, () => <String>[])
              .add(situation.name);
        }
      }
    } catch (_) {
      return;
    }
  }

  Future<void> _loadPatterns() async {
    try {
      final config = PatternConfigDTO.fromJson(
        await _loadJsonMap(patternsFile),
      );
      _scamPatterns =
          config.patterns?.map((pattern) => pattern.toDomain()).toList() ??
          const <ScamPattern>[];
    } catch (_) {
      _scamPatterns = const <ScamPattern>[];
    }
  }

  Future<void> _loadSituationMatcher() async {
    try {
      final masterModel = RiskScenariosMaster.fromJson(
        await _loadJsonMap(situationFile),
      );
      _scenarioMatcher = ScenarioMatcher(masterModel);
    } catch (_) {
      _scenarioMatcher = null;
    }
  }

  Future<void> _loadSentenceMatcher() async {
    try {
      final sentencesModel = RiskModelSentences.fromJson(
        await _loadJsonMap(sentencesFile),
      );
      _sentenceMatcher = SentenceMatcher(sentencesModel);
    } catch (_) {
      _sentenceMatcher = null;
    }
  }

  String? _classifyAndScoreTopics(Set<KeywordMatch> foundKeywords) {
    if (foundKeywords.isEmpty) return null;

    final topicScores = <String, int>{};
    for (final match in foundKeywords) {
      final tokenizedKeyword = GFlash.tokenize(match.keyword).join(' ');
      for (final topicName
          in _keywordToTopicsMap[tokenizedKeyword] ?? const <String>[]) {
        topicScores[topicName] = (topicScores[topicName] ?? 0) + 1;
      }
    }

    MapEntry<String, int>? bestEntry;
    for (final entry in topicScores.entries) {
      if (entry.value <= _topicConfirmationThreshold) continue;
      if (bestEntry == null || entry.value > bestEntry.value) {
        bestEntry = entry;
      }
    }
    return bestEntry?.key;
  }

  Set<KeywordMatch> _extractKeywordsFromTrie(List<String> tokens) {
    final matches = <KeywordMatch>{};

    for (var i = 0; i < tokens.length; i++) {
      var currentNode = _riskKeywordTrie;
      for (var j = i; j < tokens.length; j++) {
        final nextNode = currentNode.children[tokens[j]];
        if (nextNode == null) break;
        currentNode = nextNode;

        final data = currentNode.keywordData;
        if (data != null) {
          matches.add(
            KeywordMatch(
              keyword: data.originalKeyword,
              level: data.riskLevel,
              category: data.category,
              startIndex: i,
              endIndex: j,
            ),
          );
        }
      }
    }

    return matches;
  }

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
    return switch (relativePosition) {
      < 0.25 => 1.25,
      < 0.6 => 1.0,
      _ => 0.9,
    };
  }

  String _categoryForKeyword(RiskLevelData riskLevelData, String keyword) {
    final threats = riskLevelData.threats;
    if (threats != null) {
      for (final entry in threats.entries) {
        if (entry.value.contains(keyword)) return entry.key;
      }
    }
    return 'Chung';
  }

  Future<Map<String, Object?>> _loadJsonMap(String fileName) async {
    final text = await _loadString(fileName);
    final decoded = jsonDecode(text);
    if (decoded is! Map) {
      throw const FormatException('Expected JSON object');
    }
    return decoded.cast<String, Object?>();
  }

  Future<String> _loadString(String fileName) async {
    final provider = _assetProvider;
    if (provider != null) {
      return Future<String>.value(provider(fileName));
    }
    return _assetBundle.loadString('assets/$fileName');
  }
}
