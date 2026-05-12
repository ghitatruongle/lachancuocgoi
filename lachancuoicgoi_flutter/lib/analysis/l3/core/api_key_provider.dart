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
    final rawValues = <String>[
      ..._commaSeparatedKeys.split(','),
      if (_singleKey.trim().isNotEmpty) _singleKey,
    ];
    final seen = <String>{};
    final normalized = <String>[];
    for (final rawValue in rawValues) {
      final trimmed = rawValue.trim();
      if (trimmed.isEmpty) {
        continue;
      }
      final decoded = trimmed.startsWith('AIza')
          ? trimmed
          : ApiKeyObfuscator.decode(trimmed);
      if (decoded.isEmpty || !seen.add(decoded)) {
        continue;
      }
      normalized.add(decoded);
    }
    return normalized;
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
