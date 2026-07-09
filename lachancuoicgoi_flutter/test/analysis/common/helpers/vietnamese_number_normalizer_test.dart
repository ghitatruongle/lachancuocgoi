// Unit tests for VietnameseNumberNormalizer (Wave 3 refactor).

import 'package:flutter_test/flutter_test.dart';
import 'package:lachancuocgoi_flutter/analysis/common/helpers/vietnamese_number_normalizer.dart';

void main() {
  group('VietnameseNumberNormalizer', () {
    test('converts simple hundreds', () {
      expect(VietnameseNumberNormalizer.normalize('mot tram'), '100');
      expect(VietnameseNumberNormalizer.normalize('hai tram ba'), '203');
    });

    test('converts thousands', () {
      expect(VietnameseNumberNormalizer.normalize('mot nghin'), '1000');
      expect(VietnameseNumberNormalizer.normalize('hai nghin'), '2000');
    });

    test('converts millions', () {
      expect(VietnameseNumberNormalizer.normalize('mot trieu'), '1000000');
      expect(VietnameseNumberNormalizer.normalize('hai trieu'), '2000000');
    });

    test('converts billions', () {
      expect(VietnameseNumberNormalizer.normalize('mot ty'), '1000000000');
    });

    test('returns original text for non-number words', () {
      expect(VietnameseNumberNormalizer.normalize('xin chào'), 'xin chào');
    });

    test('handles mixed text with numbers and words', () {
      expect(
        VietnameseNumberNormalizer.normalize('chuyển mot tram nghin'),
        'chuyển 100000',
      );
    });
  });
}