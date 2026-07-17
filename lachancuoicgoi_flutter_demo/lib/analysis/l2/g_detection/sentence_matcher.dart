import '../../../core/risk_level.dart';
import 'g_flash.dart';
import 'g_models.dart';

class SentenceMatcher {
  SentenceMatcher(this.model);

  final RiskModelSentences model;
  final _safeSentenceTrie = _SentenceTrieNode();
  final Map<RiskLevel, _SentenceTrieNode> _threatSentenceTrieByLevel =
      <RiskLevel, _SentenceTrieNode>{};
  bool _initialized = false;

  static const int _maxSkipTokens = 1;

  void _ensureInitialized() {
    if (_initialized) return;

    for (final levelData in model.riskLevels ?? const <RiskSentenceLevel>[]) {
      final level = RiskLevel.fromInt(levelData.level);
      if (level == RiskLevel.green) {
        for (final sentence in levelData.sentences ?? const <String>[]) {
          final tokens = GFlash.tokenize(sentence);
          if (tokens.isNotEmpty) {
            _insertIntoTrie(_safeSentenceTrie, tokens, sentence);
          }
        }
      } else {
        final trie = _threatSentenceTrieByLevel.putIfAbsent(
          level,
          _SentenceTrieNode.new,
        );
        final threatSentences =
            levelData.threats?.values.expand((items) => items) ??
            const <String>[];
        for (final sentence in threatSentences) {
          final tokens = GFlash.tokenize(sentence);
          if (tokens.isNotEmpty) {
            _insertIntoTrie(trie, tokens, sentence);
          }
        }
      }
    }

    _initialized = true;
  }

  void _insertIntoTrie(
    _SentenceTrieNode root,
    List<String> tokens,
    String originalSentence,
  ) {
    var node = root;
    for (final token in tokens) {
      node = node.children.putIfAbsent(token, _SentenceTrieNode.new);
    }
    node.sentence = originalSentence;
  }

  SentenceMatch? match(List<String> transcriptTokens) {
    _ensureInitialized();
    if (transcriptTokens.isEmpty) return null;

    final safeSentence = _searchInTrieFuzzy(
      _safeSentenceTrie,
      transcriptTokens,
    );
    if (safeSentence != null) {
      return SentenceMatch(sentence: safeSentence, level: 0, isSafe: true);
    }

    const riskLevels = <RiskLevel>[
      RiskLevel.red,
      RiskLevel.orange,
      RiskLevel.yellow,
    ];
    for (final level in riskLevels) {
      final trie = _threatSentenceTrieByLevel[level];
      if (trie == null) continue;
      final sentence = _searchInTrieFuzzy(trie, transcriptTokens);
      if (sentence != null) {
        return SentenceMatch(
          sentence: sentence,
          level: level.level,
          isSafe: false,
        );
      }
    }

    return null;
  }

  String? _searchInTrieFuzzy(_SentenceTrieNode root, List<String> tokens) {
    String? longestMatch;
    for (var startIdx = 0; startIdx < tokens.length; startIdx++) {
      final result = _searchRecursive(root, tokens, startIdx, 0);
      if (result != null &&
          (longestMatch == null || result.length > longestMatch.length)) {
        longestMatch = result;
      }
    }
    return longestMatch;
  }

  String? _searchRecursive(
    _SentenceTrieNode node,
    List<String> tokens,
    int idx,
    int skipsUsed,
  ) {
    var bestMatch = node.sentence;
    if (idx >= tokens.length) return bestMatch;

    final child = node.children[tokens[idx]];
    if (child != null) {
      final childResult = _searchRecursive(child, tokens, idx + 1, skipsUsed);
      if (childResult != null &&
          (bestMatch == null || childResult.length > bestMatch.length)) {
        bestMatch = childResult;
      }
    }

    if (skipsUsed < _maxSkipTokens && idx + 1 < tokens.length) {
      final nextChild = node.children[tokens[idx + 1]];
      if (nextChild != null) {
        final skipResult = _searchRecursive(
          nextChild,
          tokens,
          idx + 2,
          skipsUsed + 1,
        );
        if (skipResult != null &&
            (bestMatch == null || skipResult.length > bestMatch.length)) {
          bestMatch = skipResult;
        }
      }
    }

    return bestMatch;
  }
}

class _SentenceTrieNode {
  final Map<String, _SentenceTrieNode> children = <String, _SentenceTrieNode>{};
  String? sentence;
}
