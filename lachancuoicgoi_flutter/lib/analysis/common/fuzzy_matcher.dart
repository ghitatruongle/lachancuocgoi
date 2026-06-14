class FuzzyMatcher {
  FuzzyMatcher._();

  static int levenshtein(
    String a,
    String b, {
    int maxDistance = 2,
  }) {
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

  static int damerauLevenshtein(
    String a,
    String b, {
    int maxDistance = 2,
  }) {
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
        var value = _min3(
          r1[j] + 1,
          r2[j - 1] + 1,
          r1[j - 1] + cost,
        );

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

  static int _min3(int a, int b, int c) {
    final minAB = a < b ? a : b;
    return minAB < c ? minAB : c;
  }
}
