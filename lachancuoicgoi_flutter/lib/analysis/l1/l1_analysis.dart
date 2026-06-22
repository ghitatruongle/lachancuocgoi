import 'dart:async';
import 'dart:convert';

import '../../core/risk_level.dart';
import '../../core/logger.dart';
import '../../core/asset_loader.dart';
import '../analysis_config.dart';
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
    this.config = const L1Config(),
    AssetLoader? assetLoader,
    AppLogger? logger,
    FutureOr<String> Function()? vocabularyProvider,
    FutureOr<String> Function()? bigramCorrectionsProvider,
    FutureOr<String> Function()? criticalKeywordsProvider,
  }) : _assetLoader = assetLoader,
       _logger = logger,
       _vocabularyProvider = vocabularyProvider,
       _bigramCorrectionsProvider = bigramCorrectionsProvider,
       _criticalKeywordsProvider = criticalKeywordsProvider;

  final AssetLoader? _assetLoader;
  final AppLogger? _logger;
  FutureOr<String> Function()? _vocabularyProvider;
  FutureOr<String> Function()? _bigramCorrectionsProvider;
  final FutureOr<String> Function()? _criticalKeywordsProvider;

  /// Critical keywords loaded from JSON asset (or fallback defaults).
  Set<String> _criticalKeywords = const {};

  @override
  AnalysisLevel get level => AnalysisLevel.l1;

  FlatTrie _trie = FlatTrie();
  final Map<String, List<_TokenCorrection>> _corrections = {};
  final Map<String, KeywordMatch> _singleTokenFuzzyCandidates = {};

  final L1Config config;

  bool _hasInitialized = false;
  Future<void>? _initializingFuture;

  List<String> _cachedCorrectedTokens = [];
  List<int> _stateHistory = [FlatTrie.rootId];
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
    _cachedCorrectedTokens.clear();
    _stateHistory = [FlatTrie.rootId];
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
    final correctionCount = _corrections.values.fold<int>(
      0,
      (sum, list) => sum + list.length,
    );
    return HealthReport(
      status: HealthStatus.healthy,
      component: 'L1',
      message:
          'Trie OK (${_trie.nodesCount} nodes, $correctionCount corrections).',
    );
  }

  Future<AnalysisResult> analyze(String text) async {
    await _initializeIfNeeded();
    final rawTokens = _tokenize(text);
    final tokens = applyBigramCorrections(rawTokens);
    final matches = await _findMatchesLinear(tokens);
    final filteredMatches = _filterSafeMatches(matches, tokens);
    final denseMatches = _applyRiskDensity(filteredMatches, tokens.length);
    return L1ResultParser.parse(denseMatches, tokens.length, _criticalKeywords);
  }

  Future<AnalysisResult> analyzeStream(String fullTranscript) async {
    await _initializeIfNeeded();

    if (fullTranscript.length < _lastFullTranscript.length ||
        !_isTailAppend(fullTranscript)) {
      _cachedCorrectedTokens.clear();
      _stateHistory = [FlatTrie.rootId];
      _lastFullTranscript = '';
    }

    final rawTokens = _tokenize(fullTranscript);
    final fullCorrected = applyBigramCorrections(rawTokens);

    int commonLen = 0;
    while (commonLen < _cachedCorrectedTokens.length &&
        commonLen < fullCorrected.length &&
        _cachedCorrectedTokens[commonLen] == fullCorrected[commonLen]) {
      commonLen++;
    }

    if (commonLen == fullCorrected.length &&
        commonLen == _cachedCorrectedTokens.length) {
      _lastFullTranscript = fullTranscript;
      _processedTextLength = fullTranscript.length;
      return _lastResult;
    }

    if (commonLen < _cachedCorrectedTokens.length) {
      _cachedCorrectedTokens.removeRange(
        commonLen,
        _cachedCorrectedTokens.length,
      );
      _stateHistory.removeRange(commonLen + 1, _stateHistory.length);
    }

    int currentState = _stateHistory.last;
    final matches = <KeywordMatch>{};
    final unmatchedTokens = <_UnmatchedToken>[];

    for (var index = commonLen; index < fullCorrected.length; index++) {
      final token = fullCorrected[index];

      while (currentState != FlatTrie.rootId &&
          _trie.getChildId(currentState, token) == null) {
        currentState = _trie.failureLinks[currentState];
      }
      currentState = _trie.getChildId(currentState, token) ?? FlatTrie.rootId;
      _stateHistory.add(currentState);

      final found = _collectMatchesAtState(
        stateId: currentState,
        matches: matches,
        wordIndex: index,
      );
      if (!found) {
        unmatchedTokens.add(_UnmatchedToken(token, index));
      }
    }

    _cachedCorrectedTokens = fullCorrected;
    _lastFullTranscript = fullTranscript;
    _processedTextLength = fullTranscript.length;

    _addFuzzyMatches(unmatchedTokens, matches);
    final filteredMatches = _filterSafeMatches(matches, fullCorrected);
    final denseMatches = _applyRiskDensity(
      filteredMatches,
      fullCorrected.length,
    );
    _lastResult = L1ResultParser.parse(
      denseMatches,
      fullCorrected.length,
      _criticalKeywords,
    );
    return _lastResult;
  }

  List<String> applyBigramCorrections(List<String> tokens) {
    if (tokens.length < 2 || _corrections.isEmpty) return tokens;

    final result = <String>[];
    var index = 0;
    while (index < tokens.length) {
      _TokenCorrection? matchedCorrection;
      final currentWord = tokens[index];
      final possibleCorrections = _corrections[currentWord];

      if (possibleCorrections != null) {
        for (final correction in possibleCorrections) {
          if (_matchesCorrection(tokens, index, correction.from)) {
            matchedCorrection = correction;
            break;
          }
        }
      }

      if (matchedCorrection != null) {
        result.addAll(matchedCorrection.to);
        index += matchedCorrection.from.length;
      } else {
        result.add(currentWord);
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
    await _buildTrie();
    // Yield to event loop — prevents 48 skipped frames during first analysis.
    await Future<void>.delayed(Duration.zero);
    await _loadBigramCorrections();
    await Future<void>.delayed(Duration.zero);
    await _loadCriticalKeywords();
    await Future<void>.delayed(Duration.zero);
    await _computeAhoCorasickLinks();
    _hasInitialized = true;
  }

  void _resetInitialization() {
    _hasInitialized = false;
    _initializingFuture = null;
    _questionPatterns = null;
    resetSession();
  }

  Future<void> _buildTrie() async {
    _singleTokenFuzzyCandidates.clear();
    try {
      final jsonText = await _loadString(
        'assets/risk_model_vocabulary.json',
        _vocabularyProvider,
      );
      final decoded = jsonDecode(jsonText);
      if (decoded is! Map<String, dynamic>) {
        _buildFallbackTrie();
        return;
      }

      final riskLevels = decoded['riskLevels'];
      if (riskLevels is! List) {
        _buildFallbackTrie();
        return;
      }

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
    } catch (e) {
      _logger?.warning('Failed to build trie: $e. Using fallback keywords.');
      _buildFallbackTrie();
    }
  }

  void _buildFallbackTrie() {
    _insertKeyword('lừa đảo', 3, 'Chung');
    _insertKeyword('chuyển tiền', 2, 'Chung');
    _insertKeyword('mã otp', 3, 'Chung');
    _insertKeyword('công an', 2, 'Chung');
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

        final firstWord = from.first;
        _corrections
            .putIfAbsent(firstWord, () => [])
            .add(_TokenCorrection(from, to));
      }
      for (final list in _corrections.values) {
        list.sort((a, b) => b.from.length.compareTo(a.from.length));
      }
    } catch (e) {
      _logger?.warning('Failed to load bigram corrections: $e');
      _corrections.clear();
    }
  }

  /// Load critical keywords from JSON asset (config-driven).
  /// Falls back to [L1ResultParser.defaultCriticalKeywords] on failure.
  Future<void> _loadCriticalKeywords() async {
    try {
      final jsonText = await _loadString(
        'assets/l1_critical_keywords.json',
        _criticalKeywordsProvider,
      );
      final decoded = jsonDecode(jsonText);
      if (decoded is! Map<String, dynamic>) return;

      final keywords = decoded['criticalKeywords'];
      if (keywords is List) {
        _criticalKeywords = keywords
            .whereType<String>()
            .map((k) => k.toLowerCase().trim())
            .where((k) => k.isNotEmpty)
            .toSet();
        _logger?.info('Loaded ${_criticalKeywords.length} critical keywords from JSON.');
      }
    } catch (e) {
      _logger?.warning('Failed to load critical keywords: $e. Using defaults.');
      _criticalKeywords = L1ResultParser.defaultCriticalKeywords;
    }
  }

  void _insertKeyword(String keyword, int levelValue, String category) {
    final tokens = _tokenize(keyword);
    if (tokens.isEmpty) return;
    if (tokens.length == 1 && tokens.single.length >= config.fuzzyMinLength) {
      _singleTokenFuzzyCandidates[tokens.single] = KeywordMatch(
        keyword: keyword,
        level: RiskLevel.fromInt(levelValue),
        category: category,
      );
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

  Future<void> _computeAhoCorasickLinks() async {
    final queue = <int>[];
    _trie.childrenMaps[FlatTrie.rootId]?.forEach((_, childId) {
      _trie.failureLinks[childId] = FlatTrie.rootId;
      queue.add(childId);
    });

    var head = 0;
    var processed = 0;
    const yieldInterval = 200; // yield every 200 nodes

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

      processed++;
      if (processed % yieldInterval == 0) {
        await Future<void>.delayed(Duration.zero); // yield to event loop
      }
    }
  }

  Future<Set<KeywordMatch>> _findMatchesLinear(List<String> tokens) async {
    if (tokens.isEmpty) return <KeywordMatch>{};

    final matches = <KeywordMatch>{};
    final unmatchedTokens = <_UnmatchedToken>[];
    var currentStateId = FlatTrie.rootId;
    const yieldInterval = 200;

    for (var wordIndex = 0; wordIndex < tokens.length; wordIndex++) {
      final token = tokens[wordIndex];

      while (currentStateId != FlatTrie.rootId &&
          _trie.getChildId(currentStateId, token) == null) {
        currentStateId = _trie.failureLinks[currentStateId];
      }
      currentStateId =
          _trie.getChildId(currentStateId, token) ?? FlatTrie.rootId;

      final found = _collectMatchesAtState(
        stateId: currentStateId,
        matches: matches,
        wordIndex: wordIndex,
      );
      if (!found) unmatchedTokens.add(_UnmatchedToken(token, wordIndex));

      // Yield every N tokens to avoid blocking the UI on long transcripts.
      if (wordIndex > 0 && wordIndex % yieldInterval == 0) {
        // Await a micro-task yield to unblock the event loop for
        // UI frames and stream events while scanning a long transcript.
        await Future<void>.delayed(Duration.zero);
      }
    }

    _addFuzzyMatches(unmatchedTokens, matches);
    return matches;
  }

  void _addFuzzyMatches(
    List<_UnmatchedToken> unmatchedTokens,
    Set<KeywordMatch> matches,
  ) {
    if (!config.fuzzyEnabled || _singleTokenFuzzyCandidates.isEmpty) return;

    for (final unmatched in unmatchedTokens) {
      if (unmatched.token.length < config.fuzzyMinLength) continue;
      final closest = FuzzyMatcher.findClosest(
        unmatched.token,
        _singleTokenFuzzyCandidates.keys,
        maxDistance: config.fuzzyMaxDistance,
      );
      if (closest == null) continue;
      final candidate = _singleTokenFuzzyCandidates[closest];
      if (candidate == null || candidate.level == RiskLevel.green) continue;
      matches.add(
        candidate.copyWith(
          startIndex: unmatched.wordIndex,
          endIndex: unmatched.wordIndex,
          isFuzzy: true,
        ),
      );
    }
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
      applySlang: true,
      noiseMode: NoiseMode.space,
    );
  }

  List<String> _readTokenList(Object? rawValue) {
    if (rawValue is! List) return const [];
    return rawValue
        .map(
          (item) => TextNormalizer.normalize(
            item.toString(),
            applySlang: true,
            noiseMode: NoiseMode.space,
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
      // Must await — provider returns FutureOr<String>, and wrapping a
      // Future in Future.value() creates a nested future, causing
      // jsonDecode to receive a Future object instead of a String.
      final result = await provider();
      return result;
    }
    if (_assetLoader == null) {
      throw StateError('AssetLoader is null. Phải cung cấp AssetLoader hoặc provider cho $assetKey.');
    }
    return _assetLoader.loadString(assetKey);
  }

  @override
  void dispose() {
    // Release session-scoped state first (token history, Aho-Corasick state).
    resetSession();
    // Release the large static structures so they can be GC'd when the
    // analyzer is torn down. Previously dispose() only cleared _fuzzyCache,
    // leaving the trie (potentially thousands of nodes) + bigram corrections
    // map + initialization future reachable.
    _corrections.clear();
    _singleTokenFuzzyCandidates.clear();
    _trie = FlatTrie();
    _questionPatterns = null;
    _hasInitialized = false;
    _initializingFuture = null;
  }

  // ── Cached compiled question patterns (built once per config) ────────
  List<RegExp>? _questionPatterns;

  List<RegExp> _getQuestionPatterns() {
    return _questionPatterns ??= config.questionContextPatterns
        .map((p) => RegExp(p, caseSensitive: false))
        .toList();
  }

  Set<KeywordMatch> _filterSafeMatches(
    Set<KeywordMatch> matches,
    List<String> tokens,
  ) {
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
    final questionPatterns = _getQuestionPatterns();

    // Pre-compute full transcript text for global safe context check (Rule 6).
    // If safe indicators appear multiple times across the transcript,
    // the entire conversation is likely safe.
    final fullText = TextNormalizer.normalize(
      tokens.join(' '),
      applySlang: true,
    );
    var globalSafeCount = 0;
    for (final safe in generalSafePhrases) {
      // Count occurrences of each safe phrase in the full transcript.
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

      // Get context around the match (configurable window size)
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

      // Rule 1: Negation preceding the keyword using Regex
      final normalizedPrefix = TextNormalizer.normalize(
        prefixText,
        applySlang: true,
      );
      if (negationRegex.hasMatch(normalizedPrefix)) {
        shouldFilter = true;
      }

      // Rule 2: Safe beneficiary succeeding a financial keyword
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

      // Rule 3: General safe context (nói đùa, troll, ví dụ…) anywhere in the wider context window
      if (!shouldFilter) {
        for (final safe in generalSafePhrases) {
          if (wholeContextText.contains(safe)) {
            shouldFilter = true;
            break;
          }
        }
      }

      // Rule 4: Question context — speaker is asking a question, not describing a scam.
      // E.g. "cho hỏi làm thế nào để chuyển tiền" is informational.
      // Only check prefix (question words typically precede the keyword).
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

      // Rule 5: Family context in suffix — mentioning family terms AFTER a
      // financial keyword suggests legitimate personal transfer, not scam.
      // Only checks suffix to avoid false positives from broader context.
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

      // Rule 6: Repeated safe sender — if safe indicators appear 2+ times
      // across the full transcript, the conversation is pervasively safe.
      // This catches cases where safe context is spread across the call
      // (e.g., "nói đùa thôi" at start + "ví dụ" later) beyond any single
      // match's local window.
      if (!shouldFilter && globalSafeCount >= 2) {
        shouldFilter = true;
      }

      if (!shouldFilter) {
        filtered.add(match);
      } else {
        _logger?.debug(
          'Negative lookahead filtered match: "${match.keyword}" at [${match.startIndex}, ${match.endIndex}]',
        );
      }
    }

    return filtered;
  }

  Set<KeywordMatch> _applyRiskDensity(
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
            break; // Since sorted, we can break early
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

  Set<KeywordMatch> applyRiskDensityForTesting(
    Set<KeywordMatch> matches,
    int totalTokens,
  ) {
    return _applyRiskDensity(matches, totalTokens);
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
