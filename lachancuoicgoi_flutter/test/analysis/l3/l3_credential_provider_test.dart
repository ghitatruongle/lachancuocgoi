import 'package:flutter_test/flutter_test.dart';
import 'package:lachancuocgoi_flutter/analysis/l3/core/l3_credential_provider.dart';

void main() {
  group('StaticEnvCredentialProvider', () {
    test('returns unavailable when no keys', () async {
      final provider = StaticEnvCredentialProvider(keys: const <String>[]);
      final cred = await provider.nextCredential();
      expect(cred, isNotNull);
      expect(cred!.source, L3CredentialSource.unavailable);
      expect(cred.value, isEmpty);
    });

    test('rotates bundled env keys', () async {
      final provider = StaticEnvCredentialProvider(
        keys: const <String>[
          'AIzaSyTestKey0000000000000000000001',
          'AIzaSyTestKey0000000000000000000002',
        ],
      );
      final a = await provider.nextCredential();
      final b = await provider.nextCredential();
      final c = await provider.nextCredential();
      expect(a!.source, L3CredentialSource.bundledEnv);
      expect(b!.source, L3CredentialSource.bundledEnv);
      expect(a.value, 'AIzaSyTestKey0000000000000000000001');
      expect(b.value, 'AIzaSyTestKey0000000000000000000002');
      expect(c!.value, 'AIzaSyTestKey0000000000000000000001');
    });
  });

  group('BackendTokenCredentialProvider (dormant)', () {
    test('caches until expiry', () async {
      var fetches = 0;
      final provider = BackendTokenCredentialProvider(
        fetch: () async {
          fetches++;
          return L3Credential(
            value: 'ephemeral-token-$fetches',
            source: L3CredentialSource.backend,
            expiresAt: DateTime.now().toUtc().add(const Duration(minutes: 5)),
          );
        },
      );
      final first = await provider.nextCredential();
      final second = await provider.nextCredential();
      expect(first!.value, second!.value);
      expect(fetches, 1);
    });

    test('refetches after reportInvalid', () async {
      var fetches = 0;
      final provider = BackendTokenCredentialProvider(
        fetch: () async {
          fetches++;
          return L3Credential(
            value: 'token-$fetches',
            source: L3CredentialSource.backend,
            expiresAt: DateTime.now().toUtc().add(const Duration(minutes: 5)),
          );
        },
      );
      final first = await provider.nextCredential();
      await provider.reportInvalid(first!);
      final second = await provider.nextCredential();
      expect(second!.value, isNot(first.value));
      expect(fetches, 2);
    });
  });
}
