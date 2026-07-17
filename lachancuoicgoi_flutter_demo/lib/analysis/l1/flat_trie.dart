/// Flat-array Aho-Corasick trie used by [L1Analyzer] for fast multi-pattern
/// keyword matching.
///
/// Nodes are stored in parallel arrays for cache efficiency:
/// - [childrenMaps]: token → child node id
/// - [nodeMetadata]: packed (riskLevel | category | isMatch flag)
/// - [failureLinks]: Aho-Corasick failure transitions
/// - [dictionaryLinks]: suffix links to dictionary (output) nodes
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
