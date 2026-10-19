import 'package:flutter_test/flutter_test.dart';
import 'package:lachancuocgoi_flutter/analysis/l3/core/pii_stripper.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('PII Stripper Zero Leakage Fuzzing Test Suite', () {
    test(
      'Redacts Vietnamese Mobile Phone Numbers (+84, 03x, 05x, 07x, 08x, 09x)',
      () {
        const inputs = [
          'SĐT của tôi là 0912345678',
          'Gọi lại số 0389998877 ngay',
          'Zalo số +84905123456 nhé',
          'Liên hệ qua số 0771234567',
          'Hotline 0868112233',
        ];

        for (final text in inputs) {
          final result = PIIStripper.redactPII(text);
          expect(
            result.redactedText,
            contains('[SO_DIEN_THOAI_'),
            reason: 'Failed to redact phone in: $text',
          );
          expect(result.tokensMap.isNotEmpty, isTrue);

          final restored = PIIStripper.restorePII(
            result.redactedText,
            result.tokensMap,
          );
          expect(
            restored,
            equals(text),
            reason: 'Restoration failed for: $text',
          );
        }
      },
    );

    test('Redacts Bank Account Numbers and Credit Cards', () {
      const text =
          'Chuyển tiền vào tài khoản STK 19031234567890 ngân hàng VCB hoặc số thẻ 4123456789012345';
      final result = PIIStripper.redactPII(text);

      expect(result.redactedText, contains('[SO_TAI_KHOAN_1]'));
      expect(result.redactedText, contains('[SO_THE_1]'));

      final restored = PIIStripper.restorePII(
        result.redactedText,
        result.tokensMap,
      );
      expect(restored, equals(text));
    });

    test('Redacts CCCD / CMND 12-digit National IDs and OTPs', () {
      const text = 'Số CCCD 079123456789 nhập mã OTP 654321';
      final result = PIIStripper.redactPII(text);

      expect(result.redactedText, contains('[CCCD_1]'));
      expect(result.redactedText, contains('[MA_OTP_1]'));

      final restored = PIIStripper.restorePII(
        result.redactedText,
        result.tokensMap,
      );
      expect(restored, equals(text));
    });

    test('Complex Multi-PII Conversation Redaction Round-trip', () {
      const text =
          'Tôi tên là Nguyễn Văn An, sinh ngày 15/06/1990, địa chỉ 123 Đường Nguyễn Trãi, SĐT 0987654321, email an.nguyen@example.com';
      final result = PIIStripper.redactPII(text);

      expect(result.redactedText, isNot(contains('0987654321')));
      expect(result.redactedText, isNot(contains('an.nguyen@example.com')));
      expect(result.tokensMap.length, greaterThanOrEqualTo(3));

      final restored = PIIStripper.restorePII(
        result.redactedText,
        result.tokensMap,
      );
      expect(restored, equals(text));
    });
  });
}
