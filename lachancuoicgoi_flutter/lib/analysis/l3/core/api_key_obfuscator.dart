import 'dart:convert';
import 'dart:typed_data';

class ApiKeyObfuscator {
  static const int _salt = 0x42;

  static String decode(String obfuscated) {
    try {
      final decodedBytes = base64.decode(obfuscated);
      final result = Uint8List(decodedBytes.length);
      for (var index = 0; index < decodedBytes.length; index++) {
        result[index] = decodedBytes[index] ^ _salt;
      }
      return utf8.decode(result);
    } catch (_) {
      return obfuscated;
    }
  }

  static String encode(String raw) {
    final rawBytes = utf8.encode(raw);
    final result = Uint8List(rawBytes.length);
    for (var index = 0; index < rawBytes.length; index++) {
      result[index] = rawBytes[index] ^ _salt;
    }
    return base64.encode(result);
  }
}
