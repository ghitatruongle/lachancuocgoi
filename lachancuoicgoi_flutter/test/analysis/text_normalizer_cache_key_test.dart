import 'package:flutter_test/flutter_test.dart';
import 'package:lachancuocgoi_flutter/analysis/common/text_normalizer.dart';

void main() {
  group('TextNormalizer.normalizeForCache', () {
    test('preserves Vietnamese diacritics ( Regression B3)', () {
      expect(
        TextNormalizer.normalizeForCache('Chuyển tiền'),
        equals('chuyển tiền'),
      );
      expect(
        TextNormalizer.normalizeForCache('đã'),
        isNot(equals(TextNormalizer.normalizeForCache('đang'))),
      );
      expect(TextNormalizer.normalizeForCache('lừa đảo'), equals('lừa đảo'));
    });

    test('lowercases and strips punctuation/whitespace noise', () {
      expect(
        TextNormalizer.normalizeForCache('Xin chào!!! Anh yêu cầu MÃ OTP???'),
        equals('xin chào anh yêu cầu mã otp'),
      );
      expect(
        TextNormalizer.normalizeForCache('  đa   khoảng cách  '),
        equals('đa khoảng cách'),
      );
    });

    test('preserves digits and numbers', () {
      expect(
        TextNormalizer.normalizeForCache('tài khoản 123456'),
        equals('tài khoản 123456'),
      );
    });

    test('handles empty and all-special-char input', () {
      expect(TextNormalizer.normalizeForCache(''), equals(''));
      expect(TextNormalizer.normalizeForCache('!!! ??? ---'), equals(''));
    });

    test('distinct diacritic-only words produce distinct keys', () {
      final keys = <String>{
        TextNormalizer.normalizeForCache('đã'),
        TextNormalizer.normalizeForCache('đang'),
        TextNormalizer.normalizeForCache('đến'),
        TextNormalizer.normalizeForCache('đó'),
        TextNormalizer.normalizeForCache('được'),
      };

      expect(keys.length, equals(5));
    });
  });
}
