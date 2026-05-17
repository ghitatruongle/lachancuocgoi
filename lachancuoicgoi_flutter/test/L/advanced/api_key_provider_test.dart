import 'package:flutter_test/flutter_test.dart';
import 'package:lachancuocgoi_flutter/analysis/l3/core/api_key_obfuscator.dart';
import 'package:lachancuocgoi_flutter/analysis/l3/core/api_key_provider.dart';

void main() {
  group('StaticApiKeyProvider', () {
    test('returns unmodifiable list', () {
      final provider = StaticApiKeyProvider(const ['AIzaKey1', 'AIzaKey2']);
      expect(() => provider.getApiKeys().add('AIzaKey3'), throws);
    });

    test('filters empty keys', () {
      final provider = StaticApiKeyProvider(['AIzaKey1', '', '  ', 'AIzaKey2']);
      expect(provider.getApiKeys(), ['AIzaKey1', 'AIzaKey2']);
      expect(provider.getKeyCount(), 2);
    });

    test('trims whitespace from keys', () {
      final provider = StaticApiKeyProvider(['  AIzaKey1  ', '\tAIzaKey2\n']);
      expect(provider.getApiKeys(), ['AIzaKey1', 'AIzaKey2']);
    });

    test('returns empty list for no keys', () {
      final provider = StaticApiKeyProvider(const <String>[]);
      expect(provider.getApiKeys(), isEmpty);
      expect(provider.getKeyCount(), 0);
    });

    test('getKeyCount matches list length', () {
      final provider = StaticApiKeyProvider(const ['K1', 'K2', 'K3']);
      expect(provider.getKeyCount(), 3);
    });
  });

  group('EnvironmentApiKeyProvider — plain keys', () {
    test('parses comma-separated plain keys', () {
      final provider = EnvironmentApiKeyProvider(
        commaSeparatedKeys: 'AIzaKey1, AIzaKey2, AIzaKey3',
      );
      expect(provider.getApiKeys(), ['AIzaKey1', 'AIzaKey2', 'AIzaKey3']);
      expect(provider.getKeyCount(), 3);
    });

    test('filters empty entries in comma-separated', () {
      final provider = EnvironmentApiKeyProvider(
        commaSeparatedKeys: 'AIzaKey1, , , AIzaKey2',
      );
      expect(provider.getApiKeys(), ['AIzaKey1', 'AIzaKey2']);
    });

    test('deduplicates identical keys', () {
      final provider = EnvironmentApiKeyProvider(
        commaSeparatedKeys: 'AIzaKey1, AIzaKey1, AIzaKey2',
      );
      expect(provider.getApiKeys(), ['AIzaKey1', 'AIzaKey2']);
    });

    test('rejects keys that do not start with AIza (plain text)', () {
      final provider = EnvironmentApiKeyProvider(
        commaSeparatedKeys: 'InvalidKey, AIzaValidKey',
      );
      expect(provider.getApiKeys(), ['AIzaValidKey']);
    });

    test('empty string returns empty list', () {
      final provider = EnvironmentApiKeyProvider(
        commaSeparatedKeys: '',
        singleKey: '',
      );
      expect(provider.getApiKeys(), isEmpty);
    });
  });

  group('EnvironmentApiKeyProvider — obfuscated keys', () {
    test('decodes obfuscated keys', () {
      final obfuscated = ApiKeyObfuscator.encode('AIzaObfuscatedKey123');
      final provider = EnvironmentApiKeyProvider(
        commaSeparatedKeys: obfuscated,
      );
      expect(provider.getApiKeys(), ['AIzaObfuscatedKey123']);
    });

    test('mixes obfuscated and plain keys', () {
      final obfuscated = ApiKeyObfuscator.encode('AIzaHiddenKey');
      final provider = EnvironmentApiKeyProvider(
        commaSeparatedKeys: '$obfuscated, AIzaPlainKey',
      );
      expect(provider.getApiKeys(), ['AIzaHiddenKey', 'AIzaPlainKey']);
    });

    test('deduplicates when same key appears obfuscated and plain', () {
      final obfuscated = ApiKeyObfuscator.encode('AIzaDuplicateKey');
      final provider = EnvironmentApiKeyProvider(
        commaSeparatedKeys: '$obfuscated, AIzaDuplicateKey',
      );
      expect(provider.getApiKeys(), ['AIzaDuplicateKey']);
    });

    test('filters out obfuscated keys that decode to invalid format', () {
      // Create a key that after obfuscation+decode doesn't start with AIza
      final provider = EnvironmentApiKeyProvider(
        commaSeparatedKeys: 'not-valid-base64!!!, AIzaValidKey',
      );
      // 'not-valid-base64!!!' will be decoded by _validateAndDecode
      // It won't start with 'AIza', so ApiKeyObfuscator.decode is called
      // But not-valid-base64!!! is not valid base64, decode returns null
      // So it gets filtered out
      expect(provider.getApiKeys(), ['AIzaValidKey']);
    });
  });

  group('EnvironmentApiKeyProvider — singleKey fallback', () {
    test('uses singleKey when commaSeparatedKeys is empty', () {
      final provider = EnvironmentApiKeyProvider(
        commaSeparatedKeys: '',
        singleKey: 'AIzaSingleKey',
      );
      expect(provider.getApiKeys(), ['AIzaSingleKey']);
    });

    test('merges singleKey with commaSeparatedKeys (no duplicate)', () {
      final provider = EnvironmentApiKeyProvider(
        commaSeparatedKeys: 'AIzaKey1',
        singleKey: 'AIzaKey2',
      );
      expect(provider.getApiKeys(), ['AIzaKey1', 'AIzaKey2']);
    });

    test('deduplicates singleKey when already in commaSeparatedKeys', () {
      final provider = EnvironmentApiKeyProvider(
        commaSeparatedKeys: 'AIzaSharedKey, AIzaKey2',
        singleKey: 'AIzaSharedKey',
      );
      expect(provider.getApiKeys(), ['AIzaSharedKey', 'AIzaKey2']);
    });

    test('does not add empty singleKey', () {
      final provider = EnvironmentApiKeyProvider(
        commaSeparatedKeys: 'AIzaKey1',
        singleKey: '',
      );
      expect(provider.getApiKeys(), ['AIzaKey1']);
    });

    test('decodes obfuscated singleKey', () {
      final obfuscated = ApiKeyObfuscator.encode('AIzaSingleObfuscated');
      final provider = EnvironmentApiKeyProvider(
        commaSeparatedKeys: '',
        singleKey: obfuscated,
      );
      expect(provider.getApiKeys(), ['AIzaSingleObfuscated']);
    });

    test('rejects invalid singleKey (not AIza)', () {
      final provider = EnvironmentApiKeyProvider(
        commaSeparatedKeys: 'AIzaKey1',
        singleKey: 'InvalidPlainKey',
      );
      expect(provider.getApiKeys(), ['AIzaKey1']);
    });
  });

  group('EnvironmentApiKeyProvider — edge cases', () {
    test('trims whitespace from all entries', () {
      final provider = EnvironmentApiKeyProvider(
        commaSeparatedKeys: '  AIzaKey1  ,  AIzaKey2  ',
      );
      expect(provider.getApiKeys(), ['AIzaKey1', 'AIzaKey2']);
    });

    test('handles trailing comma gracefully', () {
      final provider = EnvironmentApiKeyProvider(
        commaSeparatedKeys: 'AIzaKey1, AIzaKey2, ',
      );
      expect(provider.getApiKeys(), ['AIzaKey1', 'AIzaKey2']);
    });

    test('handles leading comma gracefully', () {
      final provider = EnvironmentApiKeyProvider(
        commaSeparatedKeys: ', AIzaKey1, AIzaKey2',
      );
      expect(provider.getApiKeys(), ['AIzaKey1', 'AIzaKey2']);
    });

    test('handles multiple valid keys with some invalid', () {
      final provider = EnvironmentApiKeyProvider(
        commaSeparatedKeys: 'Invalid1, AIzaValid1, Bad2, AIzaValid2',
      );
      expect(provider.getApiKeys(), ['AIzaValid1', 'AIzaValid2']);
    });

    test('many keys (stress test 100 keys)', () {
      final keys = List.generate(100, (i) => 'AIzaStressKey$i').join(', ');
      final provider = EnvironmentApiKeyProvider(commaSeparatedKeys: keys);
      expect(provider.getKeyCount(), 100);
    });
  });

  // Edge-case: key obfuscated that produces 'AIza' in wrong position
  // This is already handled by the implementation which checks startsWith
  group('EnvironmentApiKeyProvider — validation edge cases', () {
    test('key that starts with AIza after decoding is accepted', () {
      // Encode a valid-looking key to ensure round-trip works
      final obfuscated = ApiKeyObfuscator.encode('AIzaEdgeCaseKey999');
      final provider = EnvironmentApiKeyProvider(
        commaSeparatedKeys: obfuscated,
      );
      expect(provider.getApiKeys(), ['AIzaEdgeCaseKey999']);
    });
  });
}
