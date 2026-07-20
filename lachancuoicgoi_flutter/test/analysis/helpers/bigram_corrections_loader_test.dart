// Unit tests for BigramCorrectionsLoader (Wave 3 refactor).
//
// Verifies that the extracted helper preserves the original behavior of
// L1Analyzer._loadBigramCorrections.

import 'package:flutter_test/flutter_test.dart';
import 'package:lachancuocgoi_flutter/analysis/l1/helpers/bigram_corrections_loader.dart';

void main() {
  group('BigramCorrectionsLoader', () {
    test('loads valid corrections from JSON', () {
      const json = '''
        {
          "corrections": [
            {"from": ["chuyển", "khoản"], "to": ["chuyển", "khoản"]},
            {"from": ["nộp", "phạt"], "to": ["nộp", "phạt"]}
          ]
        }
      ''';

      final corrections = <String, List<TokenCorrection>>{};
      BigramCorrectionsLoader.loadFromJson(json, corrections, null);

      expect(corrections.length, 2);
      expect(corrections['chuyển']!.length, 1);
      expect(corrections['chuyển']!.first.from, ['chuyển', 'khoản']);
      expect(corrections['nộp']!.length, 1);
    });

    test('sorts corrections by length (longest first)', () {
      const json = '''
        {
          "corrections": [
            {"from": ["a"], "to": ["x"]},
            {"from": ["a", "b", "c"], "to": ["y"]},
            {"from": ["a", "b"], "to": ["z"]}
          ]
        }
      ''';

      final corrections = <String, List<TokenCorrection>>{};
      BigramCorrectionsLoader.loadFromJson(json, corrections, null);

      expect(corrections['a']!.length, 3);
      // Sorted longest first
      expect(corrections['a']![0].from.length, 3);
      expect(corrections['a']![1].from.length, 2);
      expect(corrections['a']![2].from.length, 1);
    });

    test('handles empty JSON gracefully', () {
      final corrections = <String, List<TokenCorrection>>{};
      BigramCorrectionsLoader.loadFromJson('{}', corrections, null);
      expect(corrections.isEmpty, true);
    });

    test('handles invalid JSON without crashing', () {
      final corrections = <String, List<TokenCorrection>>{};
      BigramCorrectionsLoader.loadFromJson('not json', corrections, null);
      expect(corrections.isEmpty, true);
    });

    test('skips entries with empty from or to lists', () {
      const json = '''
        {
          "corrections": [
            {"from": [], "to": ["x"]},
            {"from": ["a"], "to": []},
            {"from": ["b"], "to": ["c"]}
          ]
        }
      ''';

      final corrections = <String, List<TokenCorrection>>{};
      BigramCorrectionsLoader.loadFromJson(json, corrections, null);

      expect(corrections.length, 1);
      expect(corrections.containsKey('b'), true);
    });
  });
}
