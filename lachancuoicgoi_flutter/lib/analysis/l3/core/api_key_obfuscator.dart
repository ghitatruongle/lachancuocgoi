import 'dart:convert';
import 'dart:typed_data';

import 'api_key_format.dart';

class ApiKeyObfuscator {
  static const List<int> _xorKey = <int>[
    0x42,
    0x9A,
    0x3F,
    0xC7,
    0x58,
    0xE1,
    0x6B,
    0x24,
    0xD5,
    0x7E,
    0x19,
    0xA3,
    0x8C,
    0x4F,
    0x62,
    0xB0,
  ];

  static const int _legacySalt = 0x42;

  static String? decode(String obfuscated) {
    List<int> decodedBytes;
    try {
      decodedBytes = base64.decode(obfuscated);
    } on Object catch (_) {
      return null;
    }

    final primary = Uint8List(decodedBytes.length);
    for (var i = 0; i < decodedBytes.length; i++) {
      primary[i] = decodedBytes[i] ^ _xorKey[i % _xorKey.length];
    }
    try {
      final primaryResult = utf8.decode(primary);
      if (isSupportedGeminiKey(primaryResult)) return primaryResult;
    } on Object catch (_) {}

    final legacy = Uint8List(decodedBytes.length);
    for (var i = 0; i < decodedBytes.length; i++) {
      legacy[i] = decodedBytes[i] ^ _legacySalt;
    }
    try {
      final legacyResult = utf8.decode(legacy);
      if (isSupportedGeminiKey(legacyResult)) return legacyResult;
    } on Object catch (_) {}

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
