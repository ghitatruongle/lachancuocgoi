import 'package:flutter_test/flutter_test.dart';
import 'package:lachancuocgoi_flutter/analysis/l3/core/api_key_obfuscator.dart';

void main() {
  group('ApiKeyObfuscator — encode/decode round-trip', () {
    test('encode then decode returns original key', () {
      const raw = 'pQq';
      final encoded = ApiKeyObfuscator.encode(raw);
      final decoded = ApiKeyObfuscator.decode(encoded);
      expect(decoded, raw);
    });

    test('round-trip preserves exact case and characters', () {
      const raw = 'AIzaSyTestKeyWithMixedCase123!@#';
      final encoded = ApiKeyObfuscator.encode(raw);
      final decoded = ApiKeyObfuscator.decode(encoded);
      expect(decoded, raw);
    });

    test('round-trip works with minimum-length key (AIza + 4 chars)', () {
      const raw = 'AIzaAAAA';
      final encoded = ApiKeyObfuscator.encode(raw);
      final decoded = ApiKeyObfuscator.decode(encoded);
      expect(decoded, raw);
    });

    test('round-trip works with very long key (200 chars)', () {
      final raw = 'AIza${'x' * 196}';
      final encoded = ApiKeyObfuscator.encode(raw);
      final decoded = ApiKeyObfuscator.decode(encoded);
      expect(decoded, raw);
    });
  });

  group('ApiKeyObfuscator — legacy single-byte XOR compatibility', () {
    test('decode legacy-encoded key (single-byte XOR 0x42)', () {
      // Encode with legacy XOR manually: each byte ^ 0x42
      const raw = 'AIzaTestLegacyKey';
      final bytes = List<int>.generate(
        raw.codeUnits.length,
        (i) => raw.codeUnitAt(i) ^ 0x42,
      );
      final legacyEncoded = String.fromCharCodes(
        // Valid base64 of the XOR'd bytes
        _base64Encode(bytes).codeUnits,
      );

      // Since the obfuscator tries multi-byte first, then falls back
      // to legacy, this should work
      final decoded = ApiKeyObfuscator.decode(legacyEncoded);
      // The multi-byte XOR likely won't produce 'AIza', so it should
      // fall back to legacy XOR and decode correctly
      expect(decoded, raw);
    });
  });

  group('ApiKeyObfuscator — decode failure cases', () {
    test('returns null for invalid base64', () {
      expect(ApiKeyObfuscator.decode('not-base64!!!'), isNull);
    });

    test('returns null for empty string', () {
      expect(ApiKeyObfuscator.decode(''), isNull);
    });

    test('returns null for random byte sequence that decodes but not AIza', () {
      // Base64-encode 16 random bytes — valid base64 but not a valid key
      final randomBytes = <int>[
        1,
        2,
        3,
        4,
        5,
        6,
        7,
        8,
        9,
        10,
        11,
        12,
        13,
        14,
        15,
        16,
      ];
      final base64Str = String.fromCharCodes(
        _base64Encode(randomBytes).codeUnits,
      );
      expect(ApiKeyObfuscator.decode(base64Str), isNull);
    });

    test('returns null for all-zero bytes', () {
      final zeroBytes = List<int>.filled(32, 0);
      final base64Str = String.fromCharCodes(
        _base64Encode(zeroBytes).codeUnits,
      );
      expect(ApiKeyObfuscator.decode(base64Str), isNull);
    });

    test('returns null for partial key that does not start with AIza', () {
      // A valid base64 string that decodes to something NOT starting with AIza
      const nonAiza = 'AIzbTestKeyButWrong';
      final encoded = ApiKeyObfuscator.encode(nonAiza);
      // This encodes then decodes, but decode expects 'AIza' prefix
      // Actually encode uses multi-byte XOR, decode tries multi-byte first
      // Since the encoded bytes XOR'd with multi-byte key produce 'AIzb...' not 'AIza',
      // multi-byte will fail, then legacy will also fail => null
      // Wait — this would fail because the encoded key decodes to 'AIzb...'
      // Since that doesn't start with 'AIza', both XOR methods fail => null
      final decoded = ApiKeyObfuscator.decode(encoded);
      expect(decoded, isNull);
    });
  });

  group('ApiKeyObfuscator — encode edge cases', () {
    test('encode does not start with AIza (obfuscated)', () {
      const raw = 'AIzaSyRealKey123456789';
      final encoded = ApiKeyObfuscator.encode(raw);
      // Encoded output should NOT start with 'AIza'
      expect(encoded.startsWith('AIza'), isFalse);
      // Should look like random base64
      expect(encoded, isNot(contains('AIza')));
    });

    test('encode outputs valid base64', () {
      const raw = 'AIzaSyBase64CheckKey';
      final encoded = ApiKeyObfuscator.encode(raw);
      // Attempt to decode with base64 (not XOR) should succeed syntactically
      expect(() => _base64Decode(encoded), returnsNormally);
    });

    test('encode with empty string returns empty', () {
      expect(ApiKeyObfuscator.encode(''), '');
    });
  });

  group('ApiKeyObfuscator — encode uniqueness', () {
    test('different keys produce different obfuscated strings', () {
      final encoded1 = ApiKeyObfuscator.encode('AIzaKeyOne');
      final encoded2 = ApiKeyObfuscator.encode('AIzaKeyTwo');
      expect(encoded1, isNot(equals(encoded2)));
    });

    test('same key always produces same obfuscated string (deterministic)', () {
      const raw = 'AIzaDeterministicKey';
      final encoded1 = ApiKeyObfuscator.encode(raw);
      final encoded2 = ApiKeyObfuscator.encode(raw);
      expect(encoded1, encoded2);
    });
  });
}

// Helper: base64 operations used by legacy XOR test
String _base64Encode(List<int> bytes) {
  const chars =
      'ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/';
  final result = StringBuffer();
  for (var i = 0; i < bytes.length; i += 3) {
    final b0 = bytes[i];
    final b1 = i + 1 < bytes.length ? bytes[i + 1] : 0;
    final b2 = i + 2 < bytes.length ? bytes[i + 2] : 0;
    final triple = (b0 << 16) | (b1 << 8) | b2;
    result.write(chars[(triple >> 18) & 0x3F]);
    result.write(chars[(triple >> 12) & 0x3F]);
    if (i + 1 < bytes.length) {
      result.write(chars[(triple >> 6) & 0x3F]);
    } else {
      result.write('=');
    }
    if (i + 2 < bytes.length) {
      result.write(chars[triple & 0x3F]);
    } else {
      result.write('=');
    }
  }
  return result.toString();
}

List<int> _base64Decode(String str) {
  const chars =
      'ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/';
  final clean = str.replaceAll('=', '');
  final result = <int>[];
  for (var i = 0; i < clean.length; i += 4) {
    final c0 = chars.indexOf(clean[i]);
    final c1 = i + 1 < clean.length ? chars.indexOf(clean[i + 1]) : 0;
    final c2 = i + 2 < clean.length ? chars.indexOf(clean[i + 2]) : 0;
    final c3 = i + 3 < clean.length ? chars.indexOf(clean[i + 3]) : 0;
    final triple = (c0 << 18) | (c1 << 12) | (c2 << 6) | c3;
    result.add((triple >> 16) & 0xFF);
    if (i + 2 < clean.length) result.add((triple >> 8) & 0xFF);
    if (i + 3 < clean.length) result.add(triple & 0xFF);
  }
  return result;
}
