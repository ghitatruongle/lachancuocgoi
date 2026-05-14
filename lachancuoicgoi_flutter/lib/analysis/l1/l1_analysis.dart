import 'dart:async';
import 'dart:convert';

import 'package:flutter/services.dart';

import '../../core/risk_level.dart';
import '../analysis_level.dart';
import '../analysis_result.dart';
import '../analyzer.dart';
import '../common/fuzzy_matcher.dart';
import '../common/text_normalizer.dart';
import '../health_check.dart';
import 'l1_result.dart';

class FlatTrie {
  FlatTrie({int initialCapacity = 2000})
    : childrenMaps = List<Map<String, int>?>.filled(
        initialCapacity,
        null,
        growable: true,
      ),
      nodeMetadata = List<int>.filled(initialCapacity, 0, growable: true),
      nodeOriginalKeywords = List<String?>.filled(
        initialCapacity,
        null,
        growable: true,
      ),
      failureLinks = List<int>.filled(initialCapacity, rootId, growable: true),
      dictionaryLinks = List<int>.filled(
        initialCapacity,
        rootId,
        growable: true,
      ) {
    childrenMaps[rootId] = <String, int>{};
  }

  static const int rootId = 0;
  static const int maskRiskLevel = 0xFF;
  static const int shiftCategory = 8;
  static const int maskCategory = 0xFF << shiftCategory;
  static const int flagIsMatch = 1 << 31;

  List<Map<String, int>?> childrenMaps;
  List<int> nodeMetadata;
  List<String?> nodeOriginalKeywords;
  List<int> failureLinks;
  List<int> dictionaryLinks;

  final Map<String, int> _categoryToId = {};
  final List<String> _idToCategory = [];
  int nodesCount = 1;

  void ensureCapacity(int minCapacity) {
    while (minCapacity > childrenMaps.length) {
      final oldSize = childrenMaps.length;
      final newSize = oldSize * 2;
      childrenMaps.addAll(
        List<Map<String, int>?>.filled(newSize - oldSize, null),
      );
      nodeMetadata.addAll(List<int>.filled(newSize - oldSize, 0));
      nodeOriginalKeywords.addAll(
        List<String?>.filled(newSize - oldSize, null),
      );
      failureLinks.addAll(List<int>.filled(newSize - oldSize, rootId));
      dictionaryLinks.addAll(List<int>.filled(newSize - oldSize, rootId));
    }
  }

  int createNode() {
    ensureCapacity(nodesCount + 1);
    final id = nodesCount++;
    childrenMaps[id] = <String, int>{};
    nodeMetadata[id] = 0;
    failureLinks[id] = rootId;
    dictionaryLinks[id] = rootId;
    return id;
  }

  int? getChildId(int parentId, String token) {
    return childrenMaps[parentId]?[token];
  }

  void setChildId(int parentId, String token, int childId) {
    childrenMaps[parentId] ??= <String, int>{};
    childrenMaps[parentId]![token] = childId;
  }

  void packMetadata({
    required int level,
    required String category,
    required String keyword,
    required int nodeId,
  }) {
    final categoryId = _categoryToId.putIfAbsent(category, () {
      final id = _idToCategory.length;
      _idToCategory.add(category);
      return id;
    });

    nodeMetadata[nodeId] =
        flagIsMatch | (categoryId << shiftCategory) | (level & maskRiskLevel);
    nodeOriginalKeywords[nodeId] = keyword;
  }

  int getRiskLevel(int nodeId) => nodeMetadata[nodeId] & maskRiskLevel;

  int getCategoryId(int nodeId) {
    return (nodeMetadata[nodeId] & maskCategory) >> shiftCategory;
  }

  String getCategoryName(int nodeId) {
    final id = getCategoryId(nodeId);
    if (id < 0 || id >= _idToCategory.length) return 'Unknown';
    return _idToCategory[id];
  }

  bool isMatchNode(int nodeId) {
    return (nodeMetadata[nodeId] & flagIsMatch) != 0;
  }
}

class L1Analyzer implements Analyzer {
  L1Analyzer({
    AssetBundle? assetBundle,
    FutureOr<String> Function()? vocabularyProvider,
    FutureOr<String> Function()? bigramCorrectionsProvider,
  }) : _assetBundle = assetBundle ?? rootBundle,
       _vocabularyProvider = vocabularyProvider,
       _bigramCorrectionsProvider = bigramCorrectionsProvider;

  final AssetBundle _assetBundle;
  FutureOr<String> Function()? _vocabularyProvider;
  FutureOr<String> Function()? _bigramCorrectionsProvider;

  @override
  AnalysisLevel get level => AnalysisLevel.l1;

  FlatTrie _trie = FlatTrie();
  final List<String> _singleTokenKeywords = [];
  final List<_TokenCorrection> _corrections = [];

  final bool _fuzzyEnabled = true;
  final int _fuzzyMaxDistance = 1;
  final int _fuzzyMinLength = 5;

  bool _hasInitialized = false;
  Future<void>? _initializingFuture;

  int _currentSessionStateId = FlatTrie.rootId;
  int _processedWordCount = 0;
  String _lastFullTranscript = '';
  int _processedTextLength = 0;
  AnalysisResult _lastResult = const AnalysisResult(
    overallRiskLevel: RiskLevel.green,
    matches: [],
    analysisLevel: AnalysisLevel.l1,
    alertEnabled: false,
  );

  void setVocabularyProvider(FutureOr<String> Function() provider) {
    _vocabularyProvider = provider;
    _resetInitialization();
  }

  void setBigramCorrectionsProvider(FutureOr<String> Function() provider) {
    _bigramCorrectionsProvider = provider;
    _resetInitialization();
  }

  @override
  Future<void> initialize() => _initializeIfNeeded();

  @override
  bool get isReady => _hasInitialized;

  @override
  void resetSession() {
    _currentSessionStateId = FlatTrie.rootId;
    _processedWordCount = 0;
    _lastFullTranscript = '';
    _processedTextLength = 0;
    _lastResult = const AnalysisResult(
      overallRiskLevel: RiskLevel.green,
      matches: [],
      analysisLevel: AnalysisLevel.l1,
      alertEnabled: false,
    );
  }

  @override
  int get processedTextLength => _processedTextLength;

  @override
  void syncProcessedTextLength(int length) {
    _processedTextLength = length < 0 ? 0 : length;
  }

  @override
  AnalysisResult get lastResult => _lastResult;

  @override
  HealthReport healthCheck() {
    final hasKeywords = _trie.nodesCount > 1;
    final hasCorrections = _corrections.isNotEmpty;

    if (!hasKeywords) {
      return const HealthReport(
        status: HealthStatus.down,
        component: 'L1',
        message: 'Trie rỗng. Keywords JSON có thể bị lỗi hoặc chưa load.',
      );
    }
    if (!hasCorrections) {
      return HealthReport(
        status: HealthStatus.degraded,
        component: 'L1',
        message:
            'Trie OK (${_trie.nodesCount} nodes) nhưng không có bigram corrections.',
      );
    }
    return HealthReport(
      status: HealthStatus.healthy,
      component: 'L1',
      message:
          'Trie OK (${_trie.nodesCount} nodes, ${_corrections.length} corrections). Fuzzy=$_fuzzyEnabled',
    );
  }

  Future<AnalysisResult> analyze(String text) async {
    await _initializeIfNeeded();
    final rawTokens = _tokenize(text);
    final tokens = applyBigramCorrections(rawTokens);
    final matches = _findMatchesLinear(tokens);
    return L1ResultParser.parse(matches, tokens.length);
  }

  Future<AnalysisResult> analyzeStream(String fullTranscript) async {
    await _initializeIfNeeded();

    if (fullTranscript.length < _lastFullTranscript.length ||
        !_isTailAppend(fullTranscript)) {
      _currentSessionStateId = FlatTrie.rootId;
      _processedWordCount = 0;
    }

    final rawTokens = _tokenize(fullTranscript);
    final allTokens = applyBigramCorrections(rawTokens);
    if (allTokens.length <= _processedWordCount) {
      _lastFullTranscript = fullTranscript;
      _processedTextLength = fullTranscript.length;
      return _lastResult;
    }

    final newTokens = allTokens.sublist(_processedWordCount);
    final matches = <KeywordMatch>{};
    final unmatchedTokens = <_UnmatchedToken>[];

    for (var index = 0; index < newTokens.length; index++) {
      final token = newTokens[index];
      final wordIndex = _processedWordCount + index;

      while (_currentSessionStateId != FlatTrie.rootId &&
          _trie.getChildId(_currentSessionStateId, token) == null) {
        _currentSessionStateId = _trie.failureLinks[_currentSessionStateId];
      }
      _currentSessionStateId =
          _trie.getChildId(_currentSessionStateId, token) ?? FlatTrie.rootId;

      final found = _collectMatchesAtState(
        stateId: _currentSessionStateId,
        matches: matches,
        wordIndex: wordIndex,
      );
      if (!found) {
        unmatchedTokens.add(_UnmatchedToken(token, wordIndex));
      }
    }

    if (_fuzzyEnabled &&
        unmatchedTokens.isNotEmpty &&
        _singleTokenKeywords.isNotEmpty) {
      for (final unmatched in unmatchedTokens) {
        if (unmatched.token.length < _fuzzyMinLength) continue;
        final fuzzyMatch = FuzzyMatcher.findClosest(
          unmatched.token,
          _singleTokenKeywords,
          maxDistance: _fuzzyMaxDistance,
        );
        if (fuzzyMatch == null) continue;
        final nodeId = _findExactMatchNode(fuzzyMatch);
        if (nodeId == null || !_trie.isMatchNode(nodeId)) continue;

        matches.add(
          KeywordMatch(
            keyword: _trie.nodeOriginalKeywords[nodeId] ?? '',
            level: RiskLevel.fromInt(_trie.getRiskLevel(nodeId)),
            category: _trie.getCategoryName(nodeId),
            startIndex: unmatched.wordIndex,
            endIndex: unmatched.wordIndex,
            isFuzzy: true,
          ),
        );
      }
    }

    _processedWordCount = allTokens.length;
    _lastFullTranscript = fullTranscript;
    _processedTextLength = fullTranscript.length;
    _lastResult = L1ResultParser.parse(matches, allTokens.length);
    return _lastResult;
  }

  List<String> applyBigramCorrections(List<String> tokens) {
    if (tokens.length < 2 || _corrections.isEmpty) return tokens;

    final result = <String>[];
    var index = 0;
    while (index < tokens.length) {
      _TokenCorrection? matchedCorrection;
      for (final correction in _corrections) {
        if (_matchesCorrection(tokens, index, correction.from)) {
          matchedCorrection = correction;
          break;
        }
      }

      if (matchedCorrection != null) {
        result.addAll(matchedCorrection.to);
        index += matchedCorrection.from.length;
      } else {
        result.add(tokens[index]);
        index++;
      }
    }
    return result;
  }

  Future<void> _initializeIfNeeded() {
    if (_hasInitialized) return Future<void>.value();
    return _initializingFuture ??= _doInitialize();
  }

  Future<void> _doInitialize() async {
    _trie = FlatTrie();
    _singleTokenKeywords.clear();
    _corrections.clear();
    await _buildTrie();
    await _loadBigramCorrections();
    _computeAhoCorasickLinks();
    _hasInitialized = true;
  }

  void _resetInitialization() {
    _hasInitialized = false;
    _initializingFuture = null;
    resetSession();
  }

  Future<void> _buildTrie() async {
    final jsonText = await _loadString(
      'assets/risk_model_vocabulary.json',
      _vocabularyProvider,
    );
    final decoded = jsonDecode(jsonText);
    if (decoded is! Map<String, dynamic>) return;

    final riskLevels = decoded['riskLevels'];
    if (riskLevels is! List) return;

    for (final rawLevel in riskLevels) {
      if (rawLevel is! Map) continue;
      final levelValue = (rawLevel['level'] as num?)?.toInt() ?? 0;
      if (levelValue <= RiskLevel.green.index) continue;

      final threats = rawLevel['threats'];
      if (threats is Map) {
        for (final entry in threats.entries) {
          final category = entry.key.toString();
          final keywords = entry.value;
          if (keywords is! List) continue;
          for (final keyword in keywords) {
            _insertKeyword(keyword.toString(), levelValue, category);
          }
        }
      }

      final keywords = rawLevel['keywords'];
      if (keywords is List) {
        for (final keyword in keywords) {
          _insertKeyword(keyword.toString(), levelValue, 'Chung');
        }
      }
    }
  }

  Future<void> _loadBigramCorrections() async {
    try {
      final jsonText = await _loadString(
        'assets/bigram_corrections.json',
        _bigramCorrectionsProvider,
      );
      final decoded = jsonDecode(jsonText);
      if (decoded is! Map<String, dynamic>) return;

      final corrections = decoded['corrections'];
      if (corrections is! List) return;

      for (final rawEntry in corrections) {
        if (rawEntry is! Map) continue;
        final from = _readTokenList(rawEntry['from']);
        final to = _readTokenList(rawEntry['to']);
        if (from.isEmpty || to.isEmpty) continue;
        _corrections.add(_TokenCorrection(from, to));
      }
      _corrections.sort((a, b) => b.from.length.compareTo(a.from.length));
    } catch (_) {
      _corrections.clear();
    }
  }

  void _insertKeyword(String keyword, int levelValue, String category) {
    final tokens = _tokenize(keyword);
    if (tokens.isEmpty) return;

    if (tokens.length == 1) {
      _singleTokenKeywords.add(tokens.first);
    }

    var currentNodeId = FlatTrie.rootId;
    for (final token in tokens) {
      final existingChildId = _trie.getChildId(currentNodeId, token);
      if (existingChildId != null) {
        currentNodeId = existingChildId;
      } else {
        final nextNodeId = _trie.createNode();
        _trie.setChildId(currentNodeId, token, nextNodeId);
        currentNodeId = nextNodeId;
      }
    }

    _trie.packMetadata(
      level: levelValue,
      category: category,
      keyword: keyword,
      nodeId: currentNodeId,
    );
  }

  void _computeAhoCorasickLinks() {
    final queue = <int>[];
    _trie.childrenMaps[FlatTrie.rootId]?.forEach((_, childId) {
      _trie.failureLinks[childId] = FlatTrie.rootId;
      queue.add(childId);
    });

    var head = 0;
    while (head < queue.length) {
      final currentId = queue[head++];
      _trie.childrenMaps[currentId]?.forEach((token, childId) {
        var failureId = _trie.failureLinks[currentId];
        while (failureId != FlatTrie.rootId &&
            _trie.getChildId(failureId, token) == null) {
          failureId = _trie.failureLinks[failureId];
        }

        _trie.failureLinks[childId] =
            _trie.getChildId(failureId, token) ?? FlatTrie.rootId;

        final linkedFailureId = _trie.failureLinks[childId];
        _trie.dictionaryLinks[childId] = _trie.isMatchNode(linkedFailureId)
            ? linkedFailureId
            : _trie.dictionaryLinks[linkedFailureId];
        queue.add(childId);
      });
    }
  }

  Set<KeywordMatch> _findMatchesLinear(List<String> tokens) {
    if (tokens.isEmpty) return <KeywordMatch>{};

    final matches = <KeywordMatch>{};
    final unmatchedTokens = <String>[];
    var currentStateId = FlatTrie.rootId;

    for (final token in tokens) {
      while (currentStateId != FlatTrie.rootId &&
          _trie.getChildId(currentStateId, token) == null) {
        currentStateId = _trie.failureLinks[currentStateId];
      }
      currentStateId =
          _trie.getChildId(currentStateId, token) ?? FlatTrie.rootId;

      final found = _collectMatchesAtState(
        stateId: currentStateId,
        matches: matches,
      );
      if (!found) unmatchedTokens.add(token);
    }

    if (_fuzzyEnabled &&
        unmatchedTokens.isNotEmpty &&
        _singleTokenKeywords.isNotEmpty) {
      for (final token in unmatchedTokens) {
        if (token.length < _fuzzyMinLength) continue;
        final fuzzyMatch = FuzzyMatcher.findClosest(
          token,
          _singleTokenKeywords,
          maxDistance: _fuzzyMaxDistance,
        );
        if (fuzzyMatch == null) continue;
        final nodeId = _findExactMatchNode(fuzzyMatch);
        if (nodeId == null || !_trie.isMatchNode(nodeId)) continue;
        matches.add(
          KeywordMatch(
            keyword: _trie.nodeOriginalKeywords[nodeId] ?? '',
            level: RiskLevel.fromInt(_trie.getRiskLevel(nodeId)),
            category: _trie.getCategoryName(nodeId),
            isFuzzy: true,
          ),
        );
      }
    }

    return matches;
  }

  bool _collectMatchesAtState({
    required int stateId,
    required Set<KeywordMatch> matches,
    int? wordIndex,
  }) {
    var found = false;
    var tempStateId = stateId;
    final visitedDictNodes = <int>{};

    while (tempStateId != FlatTrie.rootId &&
        visitedDictNodes.add(tempStateId)) {
      if (_trie.isMatchNode(tempStateId)) {
        final keyword = _trie.nodeOriginalKeywords[tempStateId] ?? '';
        final keywordTokenCount = _tokenize(keyword).length;
        final endIndex = wordIndex ?? -1;
        final startIndex = wordIndex == null
            ? -1
            : wordIndex - (keywordTokenCount <= 0 ? 1 : keywordTokenCount) + 1;

        matches.add(
          KeywordMatch(
            keyword: keyword,
            level: RiskLevel.fromInt(_trie.getRiskLevel(tempStateId)),
            category: _trie.getCategoryName(tempStateId),
            startIndex: startIndex,
            endIndex: endIndex,
          ),
        );
        found = true;
      }
      tempStateId = _trie.dictionaryLinks[tempStateId];
    }

    return found;
  }

  int? _findExactMatchNode(String token) {
    final childId = _trie.getChildId(FlatTrie.rootId, token);
    if (childId == null) return null;
    return _trie.isMatchNode(childId) ? childId : null;
  }

  bool _matchesCorrection(List<String> tokens, int start, List<String> from) {
    if (start + from.length > tokens.length) return false;
    for (var offset = 0; offset < from.length; offset++) {
      if (tokens[start + offset] != from[offset]) return false;
    }
    return true;
  }

  bool _isTailAppend(String fullTranscript) {
    return fullTranscript.startsWith(_lastFullTranscript);
  }

  List<String> _tokenize(String text) {
    return TextNormalizer.tokenize(
      text,
      applySlang: false,
      noiseMode: NoiseMode.remove,
    );
  }

  List<String> _readTokenList(Object? rawValue) {
    if (rawValue is! List) return const [];
    return rawValue
        .map(
          (item) => TextNormalizer.normalize(
            item.toString(),
            applySlang: false,
            noiseMode: NoiseMode.remove,
          ),
        )
        .where((token) => token.isNotEmpty)
        .toList();
  }

  Future<String> _loadString(
    String assetKey,
    FutureOr<String> Function()? provider,
  ) async {
    if (provider != null) {
      return Future<String>.value(provider());
    }
    return _assetBundle.loadString(assetKey);
  }

  void dispose() {
    // Clean up resources if needed
  }
}

class _TokenCorrection {
  const _TokenCorrection(this.from, this.to);

  final List<String> from;
  final List<String> to;
}

class _UnmatchedToken {
  const _UnmatchedToken(this.token, this.wordIndex);

  final String token;
  final int wordIndex;
}
