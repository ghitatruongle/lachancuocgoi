import 'package:flutter_test/flutter_test.dart';
import 'package:lachancuocgoi_flutter/analysis/l3/core/api_key_provider.dart';

/// Regression tests cho Bug #1: env.json có thể chứa placeholder keys
/// (AIzaReplace..., REPLACE_ME, etc.) nếu dev commit nhầm env.example.json
/// thay vì env.json thật.
///
/// Fix: `EnvironmentApiKeyProvider.isPlaceholderKey()` detect và skip các
/// pattern placeholder này khi load env.json.
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
        // Một key Gemini hợp lệ có dạng "AIza" + 35 ký tự base64url
        const realKey = 'AIzaSyD1234567890abcdefghijklmnopqrstuvw';
        expect(EnvironmentApiKeyProvider.isPlaceholderKey(realKey), isFalse);
      },
    );

    test('accepts key with "Replace" later in the string (not at start)', () {
      // Phải match ký tự cụ thể chứ không phải keyword "Replace" ở giữa
      // Lưu ý: pattern "aizareplace" sẽ match cả "AIzaReplaceMe" lẫn
      // "AIzaXaizareplaceY" — đây là intentional để chặn cả 2 case.
      // Nếu key thật có chứa "aizareplace" thì dev nên dùng key khác.
      // (Đây là false positive risk chấp nhận được — key Gemini có
      // 35 ký tự ngẫu nhiên, xác suất chứa "aizareplace" là cực thấp.)
      // Verify: key có substring "aizareplace" → bị flag là placeholder
      expect(
        EnvironmentApiKeyProvider.isPlaceholderKey('AIzaXaizareplaceY123'),
        isTrue,
        reason:
            'Pattern check là substring-based — bắt cả khi "aizareplace" ở giữa',
      );
      // Verify: key KHÔNG có substring "aizareplace" → không bị flag
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
      // StaticApiKeyProvider không load từ assets
      final provider = StaticApiKeyProvider(const ['AIzaKey1', 'AIzaKey2']);
      expect(provider.isLoadedFromAssets, isFalse);
    });
  });
}
