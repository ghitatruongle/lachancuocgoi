import 'dart:async';
import 'dart:collection';

import '../../../core/risk_level.dart';
import '../../../core/lru_cache.dart';
import '../../analysis_result.dart';
import 'g_flash.dart';
import 'g_models.dart';

class RiskKeywordTrie {
  RiskKeywordTrie();

  static const int topicConfirmationThreshold = 3;

  TrieNode _root = TrieNode();
  final Map<String, List<String>> _keywordToTopicsMap =
      <String, List<String>>{};

  static const int maxTransitionCacheSize = 1000;
  final LruCache<int, Map<String, TrieNode>> _trieTransitionCache =
      LruCache<int, Map<String, TrieNode>>(maxSize: maxTransitionCacheSize);

  bool _isBuilt = false;

  bool get isBuilt => _isBuilt;
  bool get isEmpty => _root.children.isEmpty;

  Future<void> build({
    required Future<Map<String, Object?>> Function(String fileName) loadJson,
    required String vocabularyFile,
    required String aiCheckFile,
  }) async {
    await _buildTrie(loadJson, vocabularyFile);
    await _buildTopicMap(loadJson, aiCheckFile);
    _isBuilt = true;
  }

  Future<Set<KeywordMatch>> extractKeywords(List<String> tokens) async {
    final matches = <KeywordMatch>{};
    var current = _root;

    const earlyTermRedThreshold = 3;
    var redCount = 0;

    for (var i = 0; i < tokens.length; i++) {
      final token = tokens[i];

      final nodeId = identityHashCode(current);
      var cachedTransitions = _trieTransitionCache.get(nodeId);
      if (cachedTransitions != null && cachedTransitions.containsKey(token)) {
        current = cachedTransitions[token]!;
      } else {
        while (current != _root && !current.children.containsKey(token)) {
          current = current.failureLink ?? _root;
        }
        final child = current.children[token];
        current = child ?? _root;

        if (cachedTransitions == null) {
          cachedTransitions = <String, TrieNode>{};
          _trieTransitionCache.put(nodeId, cachedTransitions);
        }
        cachedTransitions[token] = current;
      }

      final child = current;
      var dictNode = child.dictionaryLink;
      while (dictNode != null && dictNode.keywordData != null) {
        final data = dictNode.keywordData!;
        final keywordTokens = GFlash.tokenize(data.originalKeyword);
        final keywordLen = keywordTokens.isEmpty ? 1 : keywordTokens.length;
        final startIndex = i - keywordLen + 1;
        matches.add(
          KeywordMatch(
            keyword: data.originalKeyword,
            level: data.riskLevel,
            category: data.category,
            startIndex: startIndex < 0 ? 0 : startIndex,
            endIndex: i,
          ),
        );
        if (data.riskLevel == RiskLevel.red) {
          redCount++;
        }
        final next = dictNode.failureLink?.dictionaryLink;
        if (next == dictNode) break;
        dictNode = next;
      }

      if (redCount >= earlyTermRedThreshold) {
        break;
      }
    }

    return matches;
  }

  String? classifyTopics(Set<KeywordMatch> foundKeywords) {
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
      if (entry.value < topicConfirmationThreshold) continue;
      if (bestEntry == null || entry.value > bestEntry.value) {
        bestEntry = entry;
      }
    }
    return bestEntry?.key;
  }

  void resetCache() {
    _trieTransitionCache.clear();
  }

  void dispose() {
    _root = TrieNode();
    _keywordToTopicsMap.clear();
    _trieTransitionCache.clear();
    _isBuilt = false;
  }

  void onMemoryPressure() {
    _trieTransitionCache.clear();
  }

  Future<void> _buildTrie(
    Future<Map<String, Object?>> Function(String fileName) loadJson,
    String fileName,
  ) async {
    _root = TrieNode();
    try {
      final model = RiskModelVocabulary.fromJson(await loadJson(fileName));
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

          var currentNode = _root;
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
    } on Object catch (_) {}

    _buildAhoCorasickLinks(_root);
  }

  void _buildAhoCorasickLinks(TrieNode root) {
    final queue = Queue<TrieNode>();

    for (final child in root.children.values) {
      child.failureLink = root;
      child.dictionaryLink = child.keywordData != null ? child : null;
      queue.add(child);
    }

    while (queue.isNotEmpty) {
      final current = queue.removeFirst();
      for (final entry in current.children.entries) {
        final token = entry.key;
        final child = entry.value;
        var fail = current.failureLink;
        while (fail != null && !fail.children.containsKey(token)) {
          fail = fail.failureLink;
        }
        child.failureLink = fail?.children[token] ?? root;
        if (child.failureLink == child) {
          child.failureLink = root;
        }
        child.dictionaryLink = child.keywordData != null
            ? child
            : child.failureLink?.dictionaryLink;
        queue.add(child);
      }
    }
  }

  Future<void> _buildTopicMap(
    Future<Map<String, Object?>> Function(String fileName) loadJson,
    String fileName,
  ) async {
    _keywordToTopicsMap.clear();
    try {
      final model = AiCheckModel.fromJson(await loadJson(fileName));
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
    } on Object catch (_) {}
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
}
