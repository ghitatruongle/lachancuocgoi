import 'dart:convert';
import 'dart:typed_data';

class ApiKeyObfuscator {
  /// Multi-byte XOR key (16 bytes) thay vì single byte 0x42 trước đây.
  /// Mỗi byte của key được XOR với vị trí tương ứng (quay vòng).
  /// Điều này khiến việc dò tìm key qua frequency analysis khó hơn nhiều.
  static const List<int> _xorKey = <int>[
    0x42, 0x9A, 0x3F, 0xC7, 0x58, 0xE1, 0x6B, 0x24,
    0xD5, 0x7E, 0x19, 0xA3, 0x8C, 0x4F, 0x62, 0xB0,
  ];

  /// Legacy single-byte XOR salt (tương thích ngược với keys cũ).
  static const int _legacySalt = 0x42;

  static String? decode(String obfuscated) {
    List<int> decodedBytes;
    try {
      decodedBytes = base64.decode(obfuscated);
    } catch (_) {
      return null;
    }

    // Thử multi-byte XOR key trước
    final primary = Uint8List(decodedBytes.length);
    for (var i = 0; i < decodedBytes.length; i++) {
      primary[i] = decodedBytes[i] ^ _xorKey[i % _xorKey.length];
    }
    try {
      final primaryResult = utf8.decode(primary);
      if (primaryResult.startsWith('AIza')) return primaryResult;
    } catch (_) {
      // Invalid UTF-8 from multi-byte — fall through to legacy
    }

    // Fallback: thử legacy single-byte XOR (cho key cũ)
    final legacy = Uint8List(decodedBytes.length);
    for (var i = 0; i < decodedBytes.length; i++) {
      legacy[i] = decodedBytes[i] ^ _legacySalt;
    }
    try {
      final legacyResult = utf8.decode(legacy);
      if (legacyResult.startsWith('AIza')) return legacyResult;
    } catch (_) {
      // Invalid UTF-8 from legacy — not a valid key
    }

    // Cả 2 phương pháp đều không decode ra 'AIza' — key bị corrupt
    return null;
  }

  static String encode(String raw) {
    final rawBytes = utf8.encode(raw);
    final result = Uint8List(rawBytes.length);
    for (var i = 0; i < rawBytes.length; i++) {
      result[i] = rawBytes[i] ^ _xorKey[i % _xorKey.length];
    }
    return base64.encode(result);
  }
}
