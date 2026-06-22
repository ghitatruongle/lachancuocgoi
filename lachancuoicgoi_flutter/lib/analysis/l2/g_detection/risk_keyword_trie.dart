import 'dart:async';
import 'dart:collection';

import 'package:flutter/foundation.dart' show debugPrint;

import '../../../core/risk_level.dart';
import '../../analysis_result.dart';
import 'g_flash.dart';
import 'g_models.dart';

/// Aho-Corasick trie for risk-keyword matching + topic classification.
///
/// Extracted from `GDetectionEngine` (Sprint 3). Owns the trie data structure,
/// transition cache, topic map, and all keyword-extraction / topic-voting
/// logic. The engine constructs this collaborator and delegates `build` and
/// `extractKeywords`/`classifyTopics` to it.
class RiskKeywordTrie {
  RiskKeywordTrie();

  static const int topicConfirmationThreshold = 3;

  TrieNode _root = TrieNode();
  final Map<String, List<String>> _keywordToTopicsMap =
      <String, List<String>>{};

  /// Trie transition cache: maps (nodeIdentity, token) → next node.
  final Map<int, Map<String, TrieNode>> _trieTransitionCache = {};

  bool _isBuilt = false;

  bool get isBuilt => _isBuilt;
  bool get isEmpty => _root.children.isEmpty;

  /// Builds the trie from the vocabulary JSON and the topic-map JSON.
  /// [loadJson] must return a decoded `Map<String, Object?>` for the given
  /// file name — the caller (engine) supplies this so the trie has no asset
  /// dependency of its own.
  Future<void> build({
    required Future<Map<String, Object?>> Function(String fileName) loadJson,
    required String vocabularyFile,
    required String aiCheckFile,
  }) async {
    await _buildTrie(loadJson, vocabularyFile);
    await _buildTopicMap(loadJson, aiCheckFile);
    _isBuilt = true;
  }

  /// Walks the trie over [tokens] collecting ALL matches in a single O(n)
  /// pass via Aho-Corasick failure/dictionary links.
  ///
  /// Phase 7: trước đây nested loop O(tokens × max_keyword_length) + yield mỗi
  /// 200 tokens để tránh jank. Giờ O(n) tuyến tính → không cần yield (single
  /// pass rất nhanh ngay cả với transcript 2000+ tokens). Matches bao gồm cả
  /// overlapping/contained keywords nhờ dictionary-link chain walk.
  Future<Set<KeywordMatch>> extractKeywords(List<String> tokens) async {
    final matches = <KeywordMatch>{};
    var current = _root;

    // Early termination: if we find enough RED-level keywords (>=3),
    // stop scanning and return immediately.
    const earlyTermRedThreshold = 3;
    var redCount = 0;

    for (var i = 0; i < tokens.length; i++) {
      final token = tokens[i];

      // Trie transition cache: avoid re-walking failure links for
      // the same (state, token) pair.
      final nodeId = identityHashCode(current);
      final cachedTransitions = _trieTransitionCache[nodeId];
      if (cachedTransitions != null && cachedTransitions.containsKey(token)) {
        current = cachedTransitions[token]!;
      } else {
        // Walk failure links to find next state.
        final prevState = current;
        while (current != _root && !current.children.containsKey(token)) {
          current = current.failureLink ?? _root;
        }
        final child = current.children[token];
        current = child ?? _root;

        // Cache the transition for future use.
        _trieTransitionCache.putIfAbsent(
          identityHashCode(prevState),
          () => {},
        )[token] = current;
      }

      // Emit all keywords ending at position i (via dictionary-link chain).
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

      // Early termination: enough RED evidence found, skip remaining tokens.
      if (redCount >= earlyTermRedThreshold) {
        break;
      }
    }

    return matches;
  }

  /// Classifies the dominant topic from the matched keywords. Returns the
  /// topic name whose confirmation count meets [topicConfirmationThreshold],
  /// or `null` if no topic is confident enough.
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

  /// Resets the transition cache (but keeps the built trie and topic map).
  void resetCache() {
    _trieTransitionCache.clear();
  }

  /// Releases all internal state for GC.
  void dispose() {
    _root = TrieNode();
    _keywordToTopicsMap.clear();
    _trieTransitionCache.clear();
    _isBuilt = false;
  }

  // ─── Private: trie construction ─────────────────────────────────────

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
    } on Object catch (e) {
      debugPrint('[RiskKeywordTrie] Failed to build trie from $fileName: $e');
    }
    // Phase 7: build Aho-Corasick failure/dictionary links ONCE.
    _buildAhoCorasickLinks(_root);
  }

  /// Build Aho-Corasick failure + dictionary links cho trie (BFS).
  void _buildAhoCorasickLinks(TrieNode root) {
    // Queue from dart:collection gives O(1) removeFirst; using a List +
    // removeAt(0) here was O(n) per pop, making link construction O(n²)
    // in the total node count.
    final queue = Queue<TrieNode>();
    // Root's direct children: failure → root, dictionary → self (nếu có data).
    for (final child in root.children.values) {
      child.failureLink = root;
      child.dictionaryLink = child.keywordData != null ? child : null;
      queue.add(child);
    }
    // BFS theo độ sâu.
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

  // ─── Private: topic map construction ────────────────────────────────

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
    } on Object catch (e) {
      debugPrint('[RiskKeywordTrie] Failed to load $fileName: $e');
    }
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
