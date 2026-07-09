import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lachancuocgoi_flutter/data/vocabulary_repository.dart';

/// A fake AssetBundle that returns pre-configured responses.
class FakeAssetBundle extends AssetBundle {
  final Map<String, String> _assets;

  FakeAssetBundle(this._assets);

  @override
  Future<String> loadString(String key, {bool cache = true}) async {
    if (_assets.containsKey(key)) return _assets[key]!;
    throw Exception('Asset not found: $key');
  }

  @override
  Future<ByteData> load(String key) async {
    throw UnimplementedError();
  }
}

void main() {
  group('VocabularyRepository.loadJsonMap', () {
    test('parses valid JSON object', () async {
      final bundle = FakeAssetBundle({
        'test.json': '{"key": "value", "num": 42}',
      });
      final repo = VocabularyRepository(assetBundle: bundle);
      final result = await repo.loadJsonMap('test.json');
      expect(result['key'], 'value');
      expect(result['num'], 42);
    });

    test('throws FormatException when root is an array', () async {
      final bundle = FakeAssetBundle({
        'test.json': '[1, 2, 3]',
      });
      final repo = VocabularyRepository(assetBundle: bundle);
      expect(
        () => repo.loadJsonMap('test.json'),
        throwsA(isA<FormatException>()),
      );
    });

    test('throws FormatException when root is a string', () async {
      final bundle = FakeAssetBundle({
        'test.json': '"hello"',
      });
      final repo = VocabularyRepository(assetBundle: bundle);
      expect(
        () => repo.loadJsonMap('test.json'),
        throwsA(isA<FormatException>()),
      );
    });

    test('handles Map (not Map<String, dynamic>) via cast', () async {
      // jsonDecode returns Map<String, dynamic> normally, but test the cast path
      final bundle = FakeAssetBundle({
        'test.json': '{"nested": {"inner": true}}',
      });
      final repo = VocabularyRepository(assetBundle: bundle);
      final result = await repo.loadJsonMap('test.json');
      expect(result['nested'], isA<Map>());
    });
  });

  group('VocabularyRepository.getSituationSentences', () {
    test('extracts from direct situations list', () async {
      final bundle = FakeAssetBundle({
        'assets/risk_model_sentences.json': jsonEncode({
          'situations': ['sentence 1', 'sentence 2'],
        }),
      });
      final repo = VocabularyRepository(assetBundle: bundle);
      final result = await repo.getSituationSentences();
      expect(result, ['sentence 1', 'sentence 2']);
    });

    test('extracts from riskLevels structure', () async {
      final bundle = FakeAssetBundle({
        'assets/risk_model_sentences.json': jsonEncode({
          'riskLevels': [
            {
              'sentences': ['s1', 's2'],
              'threats': {
                'bank': ['t1'],
              },
            },
          ],
        }),
      });
      final repo = VocabularyRepository(assetBundle: bundle);
      final result = await repo.getSituationSentences();
      expect(result, containsAll(['s1', 's2', 't1']));
    });

    test('returns empty for empty situations list', () async {
      final bundle = FakeAssetBundle({
        'assets/risk_model_sentences.json': jsonEncode(<String, dynamic>{'situations': <String>[]}),
      });
      final repo = VocabularyRepository(assetBundle: bundle);
      expect(await repo.getSituationSentences(), isEmpty);
    });

    test('filters non-string elements in situations', () async {
      final bundle = FakeAssetBundle({
        'assets/risk_model_sentences.json': jsonEncode({
          'situations': ['valid', 123, null, 'also valid'],
        }),
      });
      final repo = VocabularyRepository(assetBundle: bundle);
      final result = await repo.getSituationSentences();
      expect(result, ['valid', 'also valid']);
    });

    test('returns empty when riskLevels is not a list', () async {
      final bundle = FakeAssetBundle({
        'assets/risk_model_sentences.json': jsonEncode({
          'riskLevels': 'not a list',
        }),
      });
      final repo = VocabularyRepository(assetBundle: bundle);
      expect(await repo.getSituationSentences(), isEmpty);
    });

    test('handles riskLevels with missing sentences and threats', () async {
      final bundle = FakeAssetBundle({
        'assets/risk_model_sentences.json': jsonEncode({
          'riskLevels': [
            {'other': 'data'},
          ],
        }),
      });
      final repo = VocabularyRepository(assetBundle: bundle);
      expect(await repo.getSituationSentences(), isEmpty);
    });

    test('skips non-list values in threats map', () async {
      final bundle = FakeAssetBundle({
        'assets/risk_model_sentences.json': jsonEncode({
          'riskLevels': [
            {
              'threats': {
                'valid': ['t1'],
                'invalid': 'not a list',
              },
            },
          ],
        }),
      });
      final repo = VocabularyRepository(assetBundle: bundle);
      final result = await repo.getSituationSentences();
      expect(result, ['t1']);
    });

    test('returns empty when missing both situations and riskLevels', () async {
      final bundle = FakeAssetBundle({
        'assets/risk_model_sentences.json': jsonEncode({'other': 'data'}),
      });
      final repo = VocabularyRepository(assetBundle: bundle);
      expect(await repo.getSituationSentences(), isEmpty);
    });

    test('returns empty on asset load failure', () async {
      final bundle = FakeAssetBundle({}); // No assets configured
      final repo = VocabularyRepository(assetBundle: bundle);
      expect(await repo.getSituationSentences(), isEmpty);
    });

    test('merges sentences from multiple risk levels', () async {
      final bundle = FakeAssetBundle({
        'assets/risk_model_sentences.json': jsonEncode({
          'riskLevels': [
            {
              'sentences': ['a'],
              'threats': {'x': ['b']},
            },
            {
              'sentences': ['c'],
              'threats': {'y': ['d']},
            },
          ],
        }),
      });
      final repo = VocabularyRepository(assetBundle: bundle);
      final result = await repo.getSituationSentences();
      expect(result, ['a', 'b', 'c', 'd']);
    });
  });

  group('VocabularyRepository.getVocabularyTokens', () {
    test('splits by newline and trims', () async {
      final bundle = FakeAssetBundle({
        'assets/vocab.txt': 'token1\ntoken2\ntoken3',
      });
      final repo = VocabularyRepository(assetBundle: bundle);
      final result = await repo.getVocabularyTokens();
      expect(result, ['token1', 'token2', 'token3']);
    });

    test('handles CRLF line endings', () async {
      final bundle = FakeAssetBundle({
        'assets/vocab.txt': 'a\r\nb\r\nc',
      });
      final repo = VocabularyRepository(assetBundle: bundle);
      final result = await repo.getVocabularyTokens();
      expect(result, ['a', 'b', 'c']);
    });

    test('filters empty lines', () async {
      final bundle = FakeAssetBundle({
        'assets/vocab.txt': 'a\n\nb\n\nc',
      });
      final repo = VocabularyRepository(assetBundle: bundle);
      final result = await repo.getVocabularyTokens();
      expect(result, ['a', 'b', 'c']);
    });

    test('trims whitespace from each line', () async {
      final bundle = FakeAssetBundle({
        'assets/vocab.txt': '  a  \n  b  ',
      });
      final repo = VocabularyRepository(assetBundle: bundle);
      final result = await repo.getVocabularyTokens();
      expect(result, ['a', 'b']);
    });

    test('returns empty list for empty file', () async {
      final bundle = FakeAssetBundle({
        'assets/vocab.txt': '',
      });
      final repo = VocabularyRepository(assetBundle: bundle);
      final result = await repo.getVocabularyTokens();
      expect(result, isEmpty);
    });

    test('returns single token for single-line file', () async {
      final bundle = FakeAssetBundle({
        'assets/vocab.txt': 'only_one',
      });
      final repo = VocabularyRepository(assetBundle: bundle);
      final result = await repo.getVocabularyTokens();
      expect(result, ['only_one']);
    });
  });

  group('VocabularyRepository.loadString', () {
    test('delegates to AssetBundle.loadString()', () async {
      final bundle = FakeAssetBundle({
        'custom/path.txt': 'hello',
      });
      final repo = VocabularyRepository(assetBundle: bundle);
      final result = await repo.loadString('custom/path.txt');
      expect(result, 'hello');
    });
  });
}
