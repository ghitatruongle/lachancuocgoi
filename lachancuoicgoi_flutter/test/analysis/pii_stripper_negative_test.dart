import 'package:flutter_test/flutter_test.dart';
import 'package:lachancuocgoi_flutter/analysis/l3/core/pii_stripper.dart';

void main() {
  group('PIIStripper Negative & Edge Case Tests', () {
    test('handles empty and whitespace-only input', () {
      final res1 = PIIStripper.redactPII('');
      expect(res1.redactedText, equals(''));
      expect(res1.tokensMap, isEmpty);

      final res2 = PIIStripper.redactPII('   \n  \t   ');
      expect(res2.redactedText, equals('   \n  \t   '));
      expect(res2.tokensMap, isEmpty);
    });

    test('handles weird unicode characters without crashing', () {
      final res = PIIStripper.redactPII(
        'Tên tôi là 𠜎𠜱𠝹𠱓𠱸𠲖𠳏 hoặc Nguyễn Văn A ☠️ 💣 👨‍💻',
      );
      expect(res.tokensMap.values, contains('Nguyễn Văn A'));
      expect(res.redactedText, contains('[TEN_NGUOI_1]'));
    });

    test('rejects numbers that look like CCCD or phone but are invalid', () {
      // Phone number: too short (7 digits)
      final shortPhone = PIIStripper.redactPII('Số điện thoại tôi là 0912345');
      expect(shortPhone.tokensMap, isEmpty);

      // Phone number: too long (13 digits)
      final longPhone = PIIStripper.redactPII(
        'Số điện thoại tôi là 09123456789012',
      );
      expect(longPhone.tokensMap, isEmpty);

      // CCCD: too short (5 digits)
      final shortCCCD = PIIStripper.redactPII('Mã CCCD của tôi là 12345');
      expect(shortCCCD.tokensMap, isEmpty);

      // CCCD: too long (20 digits)
      final longCCCD = PIIStripper.redactPII(
        'Mã CCCD của tôi là 12345678901234567890',
      );
      expect(longCCCD.tokensMap, isEmpty);
    });

    test('throws StateError when tokensMap exceeds 500 entries', () {
      // Generate a string with 510 unique phone numbers to exceed the new 500 limit.
      final buffer = StringBuffer();
      for (int i = 1; i <= 510; i++) {
        final numStr = i.toString().padLeft(7, '0');
        buffer.write('09$numStr ');
      }

      // BUG FIX (Bug #5): The old behavior silently evicted the oldest tokens,
      // causing placeholders like [SO_DIEN_THOAI_1] to leak into restored text.
      // The new behavior throws a clear StateError instead.
      expect(
        () => PIIStripper.redactPII(buffer.toString()),
        throwsA(isA<StateError>()),
      );
    });
  });
}
