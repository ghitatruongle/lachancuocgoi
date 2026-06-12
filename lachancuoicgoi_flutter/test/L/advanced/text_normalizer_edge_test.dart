import 'package:flutter_test/flutter_test.dart';
import 'package:lachancuocgoi_flutter/analysis/common/text_normalizer.dart';

void main() {
  group('TextNormalizer - edge cases', () {
    setUp(() {
      // Reset slang config between tests
      TextNormalizer.loadSlangConfig({});
    });

    group('normalize', () {
      test('empty string returns empty', () {
        expect(TextNormalizer.normalize(''), '');
      });

      test('string with only spaces returns empty', () {
        expect(TextNormalizer.normalize('     '), '');
        expect(TextNormalizer.normalize('  \n\t  '), '');
      });

      test('string with only special characters returns empty', () {
        expect(TextNormalizer.normalize('!@#\$%^&*()'), '');
        expect(TextNormalizer.normalize('...---...'), '');
        expect(TextNormalizer.normalize('???!!!'), '');
      });

      test('very long string does not crash', () {
        final longString = 'xin chao ' * 2000; // ~18000 chars
        expect(longString.length, greaterThan(10000));

        final result = TextNormalizer.normalize(longString);
        expect(result, isNotEmpty);
        expect(result, contains('xin chao'));
      });

      test('Vietnamese with all diacritics normalizes correctly', () {
        // Full Vietnamese diacritics coverage
        const text = 'à á ạả ã â ầ ấ ậẩ ẫ ă ằ ắ ặẳ ẵ';
        final result = TextNormalizer.normalize(text);
        expect(result, contains('a'));
        // Should not contain any diacritics
        expect(result, isNot(contains('à')));
        expect(result, isNot(contains('á')));
        expect(result, isNot(contains('ầ')));
      });

      test('Vietnamese diacritics for all vowel groups', () {
        // è é ẹẻ ẽ ê ề ế ệể ễ  (11 characters)
        const eText = 'è é ẹẻ ẽ ê ề ế ệể ễ';
        final eResult = TextNormalizer.normalize(eText);
        expect(eResult.replaceAll(' ', ''), 'eeeeeeeeeee');

        // ì í ịỉ ĩ
        const iText = 'ì í ịỉ ĩ';
        final iResult = TextNormalizer.normalize(iText);
        expect(iResult.replaceAll(' ', ''), 'iiiii');

        // ò ó ọỏ õ ô ồ ố ộổ ỗ ơ ờ ớ ợở ỡ  (17 characters)
        const oText = 'ò ó ọỏ õ ô ồ ố ộổ ỗ ơ ờ ớ ợở ỡ';
        final oResult = TextNormalizer.normalize(oText);
        expect(oResult.replaceAll(' ', ''), 'ooooooooooooooooo');

        // ù ú ụủ ũ ư ừ ứ ựử ữ  (11 characters)
        const uText = 'ù ú ụủ ũ ư ừ ứ ựử ữ';
        final uResult = TextNormalizer.normalize(uText);
        expect(uResult.replaceAll(' ', ''), 'uuuuuuuuuuu');

        // ỳ ý ỵỷ ỹ
        const yText = 'ỳ ý ỵỷ ỹ';
        final yResult = TextNormalizer.normalize(yText);
        expect(yResult.replaceAll(' ', ''), 'yyyyy');

        // đ
        const dText = 'đ';
        final dResult = TextNormalizer.normalize(dText);
        expect(dResult, 'd');
      });

      test('leetspeak number substitutions work correctly', () {
        // 0->o, 1->i, 3->e, 4->a, 5->s, 7->t, 8->b
        expect(TextNormalizer.normalize('h4ck3r'), 'hacker');
        expect(TextNormalizer.normalize('l0l'), 'lol');
        expect(TextNormalizer.normalize('8a7'), 'bat');
        expect(TextNormalizer.normalize('53cr37'), 'secret');
        expect(TextNormalizer.normalize('1337'), 'ieet'); // 1→i, 3→e, 3→e, 7→t
      });

      test('mixed Vietnamese/English/numbers normalizes correctly', () {
        const text = 'Héllo 4nh 0123-456-789';
        final result = TextNormalizer.normalize(text);
        expect(result, contains('hell'));
        expect(result, contains('anh'));
        // 0→o, 1→i, 2 stays as digit, 3→e; digits survive noise removal
        expect(result, contains('oi2e'));
      });

      test('slang replacement with overlapping patterns', () {
        TextNormalizer.loadSlangConfig({
          'ck': 'chuyen khoan',
          'stk': 'so tai khoan',
        });

        final result = TextNormalizer.normalize('gui ck vao stk');
        expect(result, contains('chuyen khoan'));
        expect(result, contains('so tai khoan'));
      });

      test('slang replacement with overlapping keys prefers longer match', () {
        TextNormalizer.loadSlangConfig({
          'otp': 'ma otp',
          'ot': 'something else',
        });

        final result = TextNormalizer.normalize('doc otp di');
        expect(result, contains('ma otp'));
        // 'ot' should not corrupt 'otp' since 'otp' is longer and sorted first
      });

      test('NoiseMode.remove strips special chars', () {
        final result = TextNormalizer.normalize(
          'hello, world! test.',
          noiseMode: NoiseMode.remove,
        );
        expect(result, 'hello world test');
      });

      test('NoiseMode.space replaces special chars with spaces', () {
        final result = TextNormalizer.normalize(
          'hello,world!test.',
          noiseMode: NoiseMode.space,
        );
        expect(result, contains('hello'));
        expect(result, contains('world'));
        expect(result, contains('test'));
        // Special chars replaced by spaces, then collapsed
        expect(result, 'hello world test');
      });

      test('applySlang=false skips slang replacement', () {
        TextNormalizer.loadSlangConfig({'ck': 'chuyen khoan'});

        final result = TextNormalizer.normalize('gui ck di', applySlang: false);
        expect(result, contains('ck'));
        expect(result, isNot(contains('chuyen khoan')));
      });

      test('lowercase conversion', () {
        expect(TextNormalizer.normalize('HELLO WORLD'), 'hello world');
        expect(TextNormalizer.normalize('MiXeD CaSe'), 'mixed case');
      });

      test('multiple spaces between words are collapsed', () {
        expect(
          TextNormalizer.normalize('hello     world'),
          'hello world',
        );
        expect(
          TextNormalizer.normalize('  a   b   c  '),
          'a b c',
        );
      });

      test('combining marks are stripped', () {
        // Unicode combining marks (e.g., combining acute accent)
        const text = 'e\u0301'; // e + combining acute accent
        final result = TextNormalizer.normalize(text);
        expect(result, 'e');
      });
    });

    group('tokenize', () {
      test('empty string returns empty list', () {
        expect(TextNormalizer.tokenize(''), isEmpty);
      });

      test('whitespace-only string returns empty list', () {
        expect(TextNormalizer.tokenize('   '), isEmpty);
        expect(TextNormalizer.tokenize('  \n\t  '), isEmpty);
      });

      test('special-characters-only returns empty list', () {
        expect(TextNormalizer.tokenize('!@#\$%'), isEmpty);
      });

      test('single word returns single token', () {
        expect(TextNormalizer.tokenize('hello'), ['hello']);
      });

      test('multiple spaces between words handled correctly', () {
        final tokens = TextNormalizer.tokenize('hello     world   test');
        expect(tokens, ['hello', 'world', 'test']);
      });

      test('tokenize with Vietnamese diacritics', () {
        final tokens = TextNormalizer.tokenize('Xin chào các bạn');
        expect(tokens, ['xin', 'chao', 'cac', 'ban']);
      });

      test('tokenize with numbers mixed in', () {
        final tokens = TextNormalizer.tokenize('so 123 ma 456');
        // 1→i, 2 stays, 3→e; 4→a, 5→s, 6 stays
        expect(tokens, ['so', 'i2e', 'ma', 'as6']);
      });

      test('tokenize applies slang by default', () {
        TextNormalizer.loadSlangConfig({'ck': 'chuyen khoan'});

        final tokens = TextNormalizer.tokenize('gui ck di');
        // 'ck' -> 'chuyen khoan' -> tokenized as ['chuyen', 'khoan']
        expect(tokens, contains('chuyen'));
        expect(tokens, contains('khoan'));
      });

      test('tokenize with applySlang=false preserves slang tokens', () {
        TextNormalizer.loadSlangConfig({'ck': 'chuyen khoan'});

        final tokens = TextNormalizer.tokenize('gui ck di', applySlang: false);
        expect(tokens, ['gui', 'ck', 'di']);
      });

      test('very long string tokenizes without crash', () {
        final longString = List.filled(2000, 'word').join(' ');
        final tokens = TextNormalizer.tokenize(longString);
        expect(tokens.length, 2000);
      });

      test(
        'tokenize with NoiseMode.space preserves word boundaries',
        () {
          final tokens = TextNormalizer.tokenize(
            'hello-world_test',
            noiseMode: NoiseMode.space,
          );
          expect(tokens, ['hello', 'world', 'test']);
        },
      );
    });

    group('loadSlangConfig', () {
      test('clears previous config when loading new one', () {
        TextNormalizer.loadSlangConfig({'ck': 'chuyen khoan'});
        expect(
          TextNormalizer.normalize('ck'),
          contains('chuyen'),
        );

        // Load empty config should clear
        TextNormalizer.loadSlangConfig({});
        expect(TextNormalizer.normalize('ck'), 'ck');
      });

      test('handles empty map gracefully', () {
        TextNormalizer.loadSlangConfig({});
        expect(TextNormalizer.normalize('test'), 'test');
      });

      test('normalizes both keys and values', () {
        TextNormalizer.loadSlangConfig({'CK': 'Chuyển Khoản'});

        final result = TextNormalizer.normalize('gui ck di');
        expect(result, contains('chuyen'));
        expect(result, contains('khoan'));
      });
    });
  });
}
