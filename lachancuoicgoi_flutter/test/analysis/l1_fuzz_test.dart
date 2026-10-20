import 'dart:math';
import 'package:flutter_test/flutter_test.dart';
import 'package:lachancuocgoi_flutter/analysis/l1/flat_trie.dart';
import 'package:lachancuocgoi_flutter/analysis/l3/core/pii_stripper.dart';

void main() {
  group('L1 Fuzz Testing', () {
    final rand = Random(42);

    String generateRandomString(int maxLength) {
      const chars =
          'abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789 áàảãạâấầẩẫậăắằẳẵặéèẻẽẹêếềểễệíìỉĩịóòỏõọôốồổỗộơớờởỡợúùủũụưứừửữựýỳỷỹỵđĐ ,.!?;\n\t';
      final length = rand.nextInt(maxLength) + 1;
      return List.generate(
        length,
        (_) => chars[rand.nextInt(chars.length)],
      ).join();
    }

    test('PIIStripper redact and restore fuzzing (1000 iterations)', () {
      for (int i = 0; i < 1000; i++) {
        final rawText = generateRandomString(150);

        final res = PIIStripper.redactPII(rawText);

        final restored = PIIStripper.restorePII(
          res.redactedText,
          res.tokensMap,
        );

        expect(restored, equals(rawText));
      }
    });

    test('FlatTrie building and matching fuzzing (500 iterations)', () {
      for (int i = 0; i < 500; i++) {
        final trie = FlatTrie(initialCapacity: 10);

        final keywordsCount = rand.nextInt(20) + 1;
        final List<String> keywords = [];
        for (int k = 0; k < keywordsCount; k++) {
          final word = generateRandomString(15).trim();
          if (word.isNotEmpty) {
            keywords.add(word);

            final nodeId = trie.createNode();
            trie.packMetadata(
              level: rand.nextInt(4),
              category: 'fuzz-cat',
              keyword: word,
              nodeId: nodeId,
            );
          }
        }

        expect(trie.nodesCount, greaterThan(0));

        for (int n = 0; n < trie.nodesCount; n++) {
          final level = trie.getRiskLevel(n);
          final cat = trie.getCategoryName(n);
          expect(level, isNotNull);
          expect(cat, isNotNull);
        }
      }
    });
  });
}
