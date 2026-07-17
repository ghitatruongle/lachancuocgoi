class FuzzyMatcher {
  FuzzyMatcher._();

  static int levenshtein(String a, String b, {int maxDistance = 2}) {
    if ((a.length - b.length).abs() > maxDistance) {
      return maxDistance + 1;
    }

    var previous = List<int>.generate(b.length + 1, (index) => index);
    var current = List<int>.filled(b.length + 1, 0);

    for (var i = 1; i <= a.length; i++) {
      current[0] = i;
      var rowMin = current[0];
      for (var j = 1; j <= b.length; j++) {
        final cost = a.codeUnitAt(i - 1) == b.codeUnitAt(j - 1) ? 0 : 1;
        final value = _min3(
          previous[j] + 1,
          current[j - 1] + 1,
          previous[j - 1] + cost,
        );
        current[j] = value;
        if (value < rowMin) rowMin = value;
      }
      if (rowMin > maxDistance) return maxDistance + 1;
      final tmp = previous;
      previous = current;
      current = tmp;
    }

    return previous[b.length];
  }

  static int damerauLevenshtein(String a, String b, {int maxDistance = 2}) {
    if (a == b) return 0;
    if (a.isEmpty) return b.length.clamp(0, maxDistance + 1).toInt();
    if (b.isEmpty) return a.length.clamp(0, maxDistance + 1).toInt();
    if ((a.length - b.length).abs() > maxDistance) {
      return maxDistance + 1;
    }

    var r0 = List<int>.filled(b.length + 1, 0);
    var r1 = List<int>.generate(b.length + 1, (index) => index);
    var r2 = List<int>.filled(b.length + 1, 0);

    for (var i = 1; i <= a.length; i++) {
      r2[0] = i;
      for (var j = 1; j <= b.length; j++) {
        final cost = a.codeUnitAt(i - 1) == b.codeUnitAt(j - 1) ? 0 : 1;
        var value = _min3(r1[j] + 1, r2[j - 1] + 1, r1[j - 1] + cost);

        if (i > 1 &&
            j > 1 &&
            a.codeUnitAt(i - 1) == b.codeUnitAt(j - 2) &&
            a.codeUnitAt(i - 2) == b.codeUnitAt(j - 1)) {
          final transposition = r0[j - 2] + cost;
          value = value < transposition ? value : transposition;
        }

        r2[j] = value;
      }
      final temp = r0;
      r0 = r1;
      r1 = r2;
      r2 = temp;
    }

    return r1[b.length];
  }

  /// Original linear-scan fuzzy matching. O(n*m) where n=candidates, m=string
  /// length. For repeated queries against the same candidate set, prefer
  /// [findClosestIndexed] with a pre-built [BKTreeIndex].
  static String? findClosest(
    String token,
    Iterable<String> candidates, {
    int maxDistance = 2,
  }) {
    String? best;
    var bestDistance = maxDistance + 1;

    for (final candidate in candidates) {
      if ((token.length - candidate.length).abs() > maxDistance) continue;
      final distance = damerauLevenshtein(
        token,
        candidate,
        maxDistance: maxDistance,
      );
      if (distance < bestDistance) {
        best = candidate;
        bestDistance = distance;
        if (distance == 0) return candidate;
      }
    }

    return bestDistance <= maxDistance ? best : null;
  }

  /// BK-tree indexed fuzzy matching. O(log n) average per query after O(n log n)
  /// index build. Uses [BKTreeIndex] to prune search space via triangle
  /// inequality, then optionally pre-filters with trigram overlap.
  static String? findClosestIndexed(
    String token,
    BKTreeIndex index, {
    int maxDistance = 2,
  }) {
    return index.search(token, maxDistance: maxDistance);
  }

  static int _min3(int a, int b, int c) {
    final minAB = a < b ? a : b;
    return minAB < c ? minAB : c;
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// BK-Tree Index
// ═══════════════════════════════════════════════════════════════════════════

/// Burkhard-Keller tree for fast approximate string matching.
///
/// Build once from the candidate keyword set, then search repeatedly.
/// Each search prunes branches using the triangle inequality:
/// if d(query, node) = n, only children at distance n±maxDistance need
/// to be explored.
class BKTreeIndex {
  BKTreeIndex._({required this.root, required this.size});

  final BKNode? root;
  final int size;

  /// Trigram index for pre-filtering: maps trigram → set of candidate indices.
  final Map<String, Set<int>> _trigramIndex = {};
  final List<String> _allCandidates = [];

  /// Build a BK-tree from a collection of candidate strings.
  /// O(n * log n) average, O(n²) worst case (degenerate tree).
  factory BKTreeIndex.build(Iterable<String> candidates) {
    final list = candidates.toList();
    BKNode? root;
    final trigramIndex = <String, Set<int>>{};

    for (var i = 0; i < list.length; i++) {
      final word = list[i];
      // Insert into BK-tree
      root = _insertNode(root, word);
      // Build trigram index
      final trigrams = _extractTrigrams(word);
      for (final tri in trigrams) {
        trigramIndex.putIfAbsent(tri, () => <int>{}).add(i);
      }
    }

    return BKTreeIndex._(root: root, size: list.length)
      .._allCandidates.addAll(list)
      .._trigramIndex.addAll(trigramIndex);
  }

  /// Search for the closest string within [maxDistance] edit distance.
  /// Returns null if no candidate is within range.
  String? search(String query, {int maxDistance = 2}) {
    if (root == null) return null;

    String? best;
    var bestDist = maxDistance + 1;

    // Stack-based DFS to avoid recursion overhead
    final stack = <BKNode>[root!];

    while (stack.isNotEmpty) {
      final node = stack.removeLast();
      final dist = FuzzyMatcher.damerauLevenshtein(
        query,
        node.word,
        maxDistance: bestDist,
      );

      if (dist < bestDist) {
        best = node.word;
        bestDist = dist;
        if (dist == 0) return best;
      }

      // Triangle inequality: only explore children whose distance from
      // the current node is in [dist - maxDistance, dist + maxDistance].
      final lo = dist - maxDistance;
      final hi = dist + maxDistance;
      for (final entry in node.children.entries) {
        if (entry.key >= lo && entry.key <= hi) {
          stack.add(entry.value);
        }
      }
    }

    return bestDist <= maxDistance ? best : null;
  }

  /// Search with trigram pre-filtering for better performance on large sets.
  /// First filters candidates by trigram overlap, then does exact edit
  /// distance only on survivors.
  String? searchWithTrigramFilter(String query, {int maxDistance = 2}) {
    if (root == null || _allCandidates.isEmpty) return null;

    // For short queries (< 4 chars), trigram filtering is unreliable —
    // fall back to BK-tree search.
    final queryTrigrams = _extractTrigrams(query);
    if (queryTrigrams.length < 2) {
      return search(query, maxDistance: maxDistance);
    }

    // Count trigram hits per candidate
    final hitCounts = <int, int>{};
    for (final tri in queryTrigrams) {
      final candidates = _trigramIndex[tri];
      if (candidates != null) {
        for (final idx in candidates) {
          hitCounts[idx] = (hitCounts[idx] ?? 0) + 1;
        }
      }
    }

    // Minimum trigram overlap: if edit distance ≤ d, at least
    // max(0, |trigrams(query)| - d * 3) trigrams must match.
    final minOverlap = (queryTrigrams.length - maxDistance * 3).clamp(0, 999);

    // Filter candidates and do exact edit distance
    String? best;
    var bestDist = maxDistance + 1;

    for (final entry in hitCounts.entries) {
      if (entry.value < minOverlap) continue;
      final candidate = _allCandidates[entry.key];
      if ((query.length - candidate.length).abs() > maxDistance) continue;
      final dist = FuzzyMatcher.damerauLevenshtein(
        query,
        candidate,
        maxDistance: bestDist,
      );
      if (dist < bestDist) {
        best = candidate;
        bestDist = dist;
        if (dist == 0) return best;
      }
    }

    // Fallback: if trigram filter was too aggressive (all filtered out),
    // use BK-tree search as safety net.
    if (best == null && bestDist > maxDistance) {
      return search(query, maxDistance: maxDistance);
    }

    return bestDist <= maxDistance ? best : null;
  }

  static BKNode _insertNode(BKNode? node, String word) {
    if (node == null) return BKNode(word);
    final dist = FuzzyMatcher.levenshtein(word, node.word, maxDistance: 99);
    if (dist == 0) return node; // duplicate
    node.children[dist] = _insertNode(node.children[dist], word);
    return node;
  }

  static Set<String> _extractTrigrams(String word) {
    final trigrams = <String>{};
    if (word.length < 3) {
      trigrams.add(word);
      return trigrams;
    }
    for (var i = 0; i <= word.length - 3; i++) {
      trigrams.add(word.substring(i, i + 3));
    }
    return trigrams;
  }
}

class BKNode {
  BKNode(this.word);

  final String word;
  final Map<int, BKNode> children = {};
}
