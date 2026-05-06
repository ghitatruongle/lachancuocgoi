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
    if ((a.length - b.length).abs() > maxDistance) {
      return maxDistance + 1;
    }

    final dp = List.generate(
      a.length + 1,
      (_) => List<int>.filled(b.length + 1, 0),
    );

    for (var i = 0; i <= a.length; i++) {
      dp[i][0] = i;
    }
    for (var j = 0; j <= b.length; j++) {
      dp[0][j] = j;
    }

    for (var i = 1; i <= a.length; i++) {
      var rowMin = maxDistance + 1;
      for (var j = 1; j <= b.length; j++) {
        final cost = a.codeUnitAt(i - 1) == b.codeUnitAt(j - 1) ? 0 : 1;
        var value = _min3(
          dp[i - 1][j] + 1,
          dp[i][j - 1] + 1,
          dp[i - 1][j - 1] + cost,
        );

        if (i > 1 &&
            j > 1 &&
            a.codeUnitAt(i - 1) == b.codeUnitAt(j - 2) &&
            a.codeUnitAt(i - 2) == b.codeUnitAt(j - 1)) {
          value = value < dp[i - 2][j - 2] + 1 ? value : dp[i - 2][j - 2] + 1;
        }

        dp[i][j] = value;
        if (value < rowMin) rowMin = value;
      }
      if (rowMin > maxDistance) return maxDistance + 1;
    }

    return dp[a.length][b.length];
  }

  static String? findClosest(
    String token,
    Iterable<String> candidates, {
    int maxDistance = 2,
  }) {
    String? best;
    var bestDistance = maxDistance + 1;

    for (final candidate in candidates) {
      final distance = damerauLevenshtein(
        token,
        candidate,
        maxDistance: maxDistance,
      );
      if (distance < bestDistance) {
        best = candidate;
        bestDistance = distance;
      }
    }

    return bestDistance <= maxDistance ? best : null;
  }

  static int _min3(int a, int b, int c) {
    final minAB = a < b ? a : b;
    return minAB < c ? minAB : c;
  }
}
