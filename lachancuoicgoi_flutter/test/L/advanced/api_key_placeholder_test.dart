import 'package:flutter_test/flutter_test.dart';
import 'package:lachancuocgoi_flutter/analysis/l3/core/api_key_provider.dart';

void main() {
  group('Bug #1: Placeholder key detection', () {
    test('detects AIzaReplace... as placeholder', () {
      expect(
        EnvironmentApiKeyProvider.isPlaceholderKey('AIzaReplaceWithYourKey'),
        isTrue,
      );
    });

    test('detects AIzaYour... as placeholder', () {
      expect(
        EnvironmentApiKeyProvider.isPlaceholderKey('AIzaYourApiKeyHere'),
        isTrue,
      );
    });

    test('detects AIzaExample... as placeholder', () {
      expect(
        EnvironmentApiKeyProvider.isPlaceholderKey('AIzaExampleKey123'),
        isTrue,
      );
    });

    test('detects REPLACE_ME as placeholder', () {
      expect(
        EnvironmentApiKeyProvider.isPlaceholderKey('REPLACE_ME_WITH_KEY'),
        isTrue,
      );
    });

    test('detects YOUR_API_KEY as placeholder', () {
      expect(
        EnvironmentApiKeyProvider.isPlaceholderKey('YOUR_API_KEY_HERE'),
        isTrue,
      );
    });

    test('detects PLACEHOLDER as placeholder', () {
      expect(
        EnvironmentApiKeyProvider.isPlaceholderKey('this_is_a_placeholder'),
        isTrue,
      );
    });

    test('case-insensitive detection', () {
      expect(
        EnvironmentApiKeyProvider.isPlaceholderKey('aizareplace_anything'),
        isTrue,
        reason: 'Should detect regardless of case',
      );
      expect(
        EnvironmentApiKeyProvider.isPlaceholderKey('REPLACE_ME_NOW'),
        isTrue,
      );
      expect(
        EnvironmentApiKeyProvider.isPlaceholderKey('replace_me_lower'),
        isTrue,
      );
    });

    test(
      'accepts real-looking Gemini key (starts with AIza, not placeholder)',
      () {
        const realKey = 'AIzaSyD1234567890abcdefghijklmnopqrstuvw';
        expect(EnvironmentApiKeyProvider.isPlaceholderKey(realKey), isFalse);
      },
    );

    test('accepts key with "Replace" later in the string (not at start)', () {
      expect(
        EnvironmentApiKeyProvider.isPlaceholderKey('AIzaXaizareplaceY123'),
        isTrue,
        reason:
            'Pattern check là substring-based — bắt cả khi "aizareplace" ở giữa',
      );

      expect(
        EnvironmentApiKeyProvider.isPlaceholderKey('AIzaSyXReplacY123'),
        isFalse,
        reason:
            'Key không chứa "aizareplace" → không bị flag (chỉ "replac" thôi)',
      );
    });
  });

  group('Bug #1: isLoadedFromAssets flag', () {
    test('defaults to false (provider chưa load)', () {
      final provider = EnvironmentApiKeyProvider(
        commaSeparatedKeys: 'AIzaValidKey',
      );
      expect(provider.isLoadedFromAssets, isFalse);
    });

    test('StaticApiKeyProvider luôn trả về false', () {
      final provider = StaticApiKeyProvider(const ['AIzaKey1', 'AIzaKey2']);
      expect(provider.isLoadedFromAssets, isFalse);
    });
  });
}
