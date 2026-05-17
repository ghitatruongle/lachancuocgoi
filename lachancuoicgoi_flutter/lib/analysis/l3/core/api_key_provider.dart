import 'api_key_obfuscator.dart';

abstract interface class ApiKeyProvider {
  List<String> getApiKeys();

  int getKeyCount();
}

class EnvironmentApiKeyProvider implements ApiKeyProvider {
  EnvironmentApiKeyProvider({
    String? commaSeparatedKeys,
    String? singleKey,
  })  : _commaSeparatedKeys = commaSeparatedKeys ??
            const String.fromEnvironment('GEMINI_API_KEYS'),
        _singleKey =
            singleKey ?? const String.fromEnvironment('GEMINI_API_KEY');

  final String _commaSeparatedKeys;
  final String _singleKey;

  late final List<String> _keys = _parseKeys();

  @override
  List<String> getApiKeys() => List<String>.unmodifiable(_keys);

  @override
  int getKeyCount() => _keys.length;

  List<String> _parseKeys() {
    final commaKeys = _commaSeparatedKeys
        .split(',')
        .map((k) => k.trim())
        .where((k) => k.isNotEmpty)
        .toList();

    final seen = <String>{};
    final normalized = <String>[];

    for (final rawValue in commaKeys) {
      final decoded = _validateAndDecode(rawValue);
      if (decoded != null && seen.add(decoded)) {
        normalized.add(decoded);
      }
    }

    // Thêm singleKey nếu chưa có trong comma list
    final singleKey = _singleKey.trim();
    if (singleKey.isNotEmpty) {
      final decoded = _validateAndDecode(singleKey);
      if (decoded != null && seen.add(decoded)) {
        normalized.add(decoded);
      }
    }

    return normalized;
  }

  /// Decode key và validate format hợp lệ (phải bắt đầu bằng 'AIza').
  /// Trả về null nếu key không hợp lệ.
  String? _validateAndDecode(String raw) {
    if (raw.isEmpty) return null;
    if (raw.startsWith('AIza')) return raw;
    final decoded = ApiKeyObfuscator.decode(raw);      if (decoded == null || decoded.isEmpty || !decoded.startsWith('AIza')) return null;
      return decoded;
  }
}

class StaticApiKeyProvider implements ApiKeyProvider {
  StaticApiKeyProvider(List<String> keys)
      : _keys = List<String>.unmodifiable(
          keys.map((key) => key.trim()).where((key) => key.isNotEmpty),
        );

  final List<String> _keys;

  @override
  List<String> getApiKeys() => _keys;

  @override
  int getKeyCount() => _keys.length;
}
