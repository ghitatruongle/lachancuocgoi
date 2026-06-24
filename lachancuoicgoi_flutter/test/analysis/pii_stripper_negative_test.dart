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

    test('prevents memory leak by capping tokensMap at 200 entries', () {
      // Generate a string with 210 unique phone numbers.
      // E.g., "0900000001, 0900000002, ..."
      final buffer = StringBuffer();
      for (int i = 1; i <= 210; i++) {
        final numStr = i.toString().padLeft(7, '0');
        buffer.write('09$numStr ');
      }

      final res = PIIStripper.redactPII(buffer.toString());

      // Check that tokensMap length is capped at 200
      expect(res.tokensMap.length, lessThanOrEqualTo(200));
      expect(res.tokensMap.length, equals(200));

      // The first few numbers (1 to 10) should have been evicted to make room.
      expect(res.tokensMap.values, isNot(contains('090000001')));
      expect(res.tokensMap.values, isNot(contains('090000010')));
      // The last few numbers should be present
      expect(res.tokensMap.values, contains('090000200'));
      expect(res.tokensMap.values, contains('090000210'));
    });
  });
}
