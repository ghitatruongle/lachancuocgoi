import 'package:flutter_test/flutter_test.dart';
import 'package:lachancuocgoi_flutter/analysis/common/fuzzy_matcher.dart';

void main() {
  group('FuzzyMatcher — levenshtein basic', () {
    test('identical strings have distance 0', () {
      expect(FuzzyMatcher.levenshtein('hello', 'hello'), 0);
    });

    test('empty strings have distance 0', () {
      expect(FuzzyMatcher.levenshtein('', ''), 0);
    });

    test('one insertion: distance 1', () {
      expect(FuzzyMatcher.levenshtein('cat', 'cats'), 1);
    });

    test('one deletion: distance 1', () {
      expect(FuzzyMatcher.levenshtein('cats', 'cat'), 1);
    });

    test('one substitution: distance 1', () {
      expect(FuzzyMatcher.levenshtein('cat', 'bat'), 1);
    });

    test('completely different strings exceed maxDistance', () {
      expect(
        FuzzyMatcher.levenshtein('abcde', 'vwxyz', maxDistance: 2),
        greaterThan(2),
      );
    });
  });

  group('FuzzyMatcher — levenshtein early termination', () {
    test('short circuits when length diff > maxDistance', () {
      // Length diff = 4 > maxDistance = 2
      final result = FuzzyMatcher.levenshtein('ab', 'abcdef', maxDistance: 2);
      expect(result, greaterThan(2));
    });

    test('early termination on row minimum check', () {
      // Very different long strings should terminate early when rowMin > maxDistance
      final result = FuzzyMatcher.levenshtein(
        'aaaaaaaaaa',
        'bbbbbbbbbb',
        maxDistance: 2,
      );
      expect(result, greaterThan(2));
    });

    test('exact match with maxDistance=0 returns 0', () {
      expect(FuzzyMatcher.levenshtein('exact', 'exact', maxDistance: 0), 0);
    });

    test('one char diff with maxDistance=0 returns >0', () {
      expect(
        FuzzyMatcher.levenshtein('exact', 'exact!', maxDistance: 0),
        greaterThan(0),
      );
    });
  });

  group('FuzzyMatcher — damerauLevenshtein transposition', () {
    test('transposition of adjacent chars: distance 1', () {
      expect(FuzzyMatcher.damerauLevenshtein('ab', 'ba'), 1);
    });

    test('transposition in longer string', () {
      expect(FuzzyMatcher.damerauLevenshtein('hello', 'ehllo'), 1);
    });

    test('levenshtein counts transposition as 2, damerau as 1', () {
      // 'ab' -> 'ba': Levenshtein counts 2 (delete b, insert b)
      // Damerau-Levenshtein counts 1 (transposition)
      expect(FuzzyMatcher.levenshtein('ab', 'ba'), 2);
      expect(FuzzyMatcher.damerauLevenshtein('ab', 'ba'), 1);
    });

    test('non-adjacent swap is not a transposition', () {
      // 'abc' -> 'cba': not a simple adjacent transposition
      expect(FuzzyMatcher.damerauLevenshtein('abc', 'cba'), 2);
    });

    test('transposition with other edits', () {
      // 'abcd' -> 'acbd' (transpose bc) + delete? No, just transposition
      expect(FuzzyMatcher.damerauLevenshtein('abcd', 'acbd'), 1);
    });
  });

  group('FuzzyMatcher — damerauLevenshtein edge cases', () {
    test('identical strings return 0', () {
      expect(FuzzyMatcher.damerauLevenshtein('abc', 'abc'), 0);
    });

    test('empty vs non-empty returns length', () {
      expect(FuzzyMatcher.damerauLevenshtein('', 'abc'), 3);
    });

    test('non-empty vs empty returns length', () {
      expect(FuzzyMatcher.damerauLevenshtein('abc', ''), 3);
    });

    test('both empty returns 0', () {
      expect(FuzzyMatcher.damerauLevenshtein('', ''), 0);
    });

    test('early exit when length diff > maxDistance', () {
      final result = FuzzyMatcher.damerauLevenshtein(
        'a',
        'abcdef',
        maxDistance: 2,
      );
      expect(result, greaterThan(2));
    });

    test('same length but completely different chars', () {
      expect(FuzzyMatcher.damerauLevenshtein('abc', 'xyz', maxDistance: 3), 3);
    });

    test('Unicode characters work correctly', () {
      // Vietnamese characters
      expect(FuzzyMatcher.damerauLevenshtein('điện', 'điện'), 0);
    });

    test('mixed ASCII and Unicode', () {
      // Single character diff
      expect(FuzzyMatcher.damerauLevenshtein('công an', 'cong an'), 1);
    });
  });

  group('FuzzyMatcher — findClosest', () {
    test('exact match returns the candidate', () {
      final result = FuzzyMatcher.findClosest('hello', {'hello', 'world'});
      expect(result, 'hello');
    });

    test('fuzzy match within distance returns best candidate', () {
      final result = FuzzyMatcher.findClosest('helo', {
        'hello',
        'world',
      }, maxDistance: 2);
      expect(result, 'hello');
    });

    test('no match within distance returns null', () {
      final result = FuzzyMatcher.findClosest('xyzabc', {
        'hello',
        'world',
      }, maxDistance: 2);
      expect(result, isNull);
    });

    test('empty candidates returns null', () {
      final result = FuzzyMatcher.findClosest('hello', const <String>{});
      expect(result, isNull);
    });

    test('prefers closer match over farther one', () {
      final result = FuzzyMatcher.findClosest('helo', {
        'hello',
        'hxxxxxx',
      }, maxDistance: 3);
      expect(result, 'hello');
    });

    test('case sensitivity matters', () {
      final result = FuzzyMatcher.findClosest('Hello', {'hello', 'world'});
      expect(result, 'hello');
    });

    test('large candidate set does not crash', () {
      final candidates = List<String>.generate(
        1000,
        (i) => 'candidate_${i}_text',
      ).toSet();
      final result = FuzzyMatcher.findClosest(
        'candidate_500_tex',
        candidates,
        maxDistance: 2,
      );
      expect(result, 'candidate_500_text');
    });
  });

  group('FuzzyMatcher — edge cases and stress', () {
    test('very long strings within maxDistance', () {
      // 100 chars that differ by 1
      final a = 'a' * 50 + 'b' * 50;
      final b = 'a' * 50 + 'c' * 50;
      final dist = FuzzyMatcher.damerauLevenshtein(a, b, maxDistance: 50);
      expect(dist, 50);
    });

    test('very long strings far beyond maxDistance', () {
      final a = 'a' * 100;
      final b = 'b' * 100;
      final dist = FuzzyMatcher.damerauLevenshtein(a, b, maxDistance: 10);
      expect(dist, greaterThan(10));
    });

    test('findClosest with empty token', () {
      final result = FuzzyMatcher.findClosest('', {
        'a',
        'bb',
        'ccc',
      }, maxDistance: 2);
      // Empty string has distance = candidate.length
      expect(result, 'a'); // distance 1 from 'a'
    });

    test('findClosest with single character token', () {
      final result = FuzzyMatcher.findClosest('x', {
        'y',
        'z',
        'xy',
      }, maxDistance: 1);
      expect(result, 'y'); // distance 1
    });

    test('maxDistance=0 only allows exact matches', () {
      final result = FuzzyMatcher.findClosest('hello', {
        'hello',
        'hell',
      }, maxDistance: 0);
      expect(result, 'hello');
    });

    test('maxDistance=0 with no exact match returns null', () {
      final result = FuzzyMatcher.findClosest('hello', {
        'hell',
      }, maxDistance: 0);
      expect(result, isNull);
    });
  });
}
