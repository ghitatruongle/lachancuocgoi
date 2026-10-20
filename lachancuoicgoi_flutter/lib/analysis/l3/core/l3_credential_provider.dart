import 'api_key_format.dart';
import 'api_key_provider.dart';

enum L3CredentialSource { bundledEnv, backend, unavailable }

class L3Credential {
  const L3Credential({
    required this.value,
    required this.source,
    this.expiresAt,
  });

  final String value;
  final L3CredentialSource source;
  final DateTime? expiresAt;

  bool get isExpired {
    final exp = expiresAt;
    if (exp == null) return false;
    return DateTime.now().toUtc().isAfter(exp);
  }
}

abstract interface class L3CredentialProvider {
  Future<L3Credential?> nextCredential();

  Future<void> reportInvalid(L3Credential credential);
}

class StaticEnvCredentialProvider implements L3CredentialProvider {
  StaticEnvCredentialProvider({required List<String> keys})
    : _keys = keys
          .map((k) => k.trim())
          .where((k) => k.isNotEmpty && isSupportedGeminiKey(k))
          .toList(growable: false);

  factory StaticEnvCredentialProvider.fromApiKeyProvider(
    ApiKeyProvider provider,
  ) {
    return StaticEnvCredentialProvider(keys: provider.getApiKeys());
  }

  final List<String> _keys;
  int _index = 0;

  int get keyCount => _keys.length;

  @override
  Future<L3Credential?> nextCredential() async {
    if (_keys.isEmpty) {
      return const L3Credential(
        value: '',
        source: L3CredentialSource.unavailable,
      );
    }
    final value = _keys[_index % _keys.length];
    _index++;
    return L3Credential(value: value, source: L3CredentialSource.bundledEnv);
  }

  @override
  Future<void> reportInvalid(L3Credential credential) async {}
}

class BackendTokenCredentialProvider implements L3CredentialProvider {
  BackendTokenCredentialProvider({required this.fetch});

  final Future<L3Credential> Function() fetch;
  L3Credential? _cached;

  @override
  Future<L3Credential?> nextCredential() async {
    final cached = _cached;
    if (cached != null &&
        cached.source == L3CredentialSource.backend &&
        !cached.isExpired &&
        cached.value.isNotEmpty) {
      return cached;
    }
    final fresh = await fetch();
    _cached = fresh;
    return fresh;
  }

  @override
  Future<void> reportInvalid(L3Credential credential) async {
    if (_cached?.value == credential.value) {
      _cached = null;
    }
  }
}
