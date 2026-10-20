import 'package:flutter_test/flutter_test.dart';
import 'package:lachancuocgoi_flutter/analysis/l3/core/pii_stripper.dart';

void main() {
  group('PII adversarial VN', () {
    test('redacts phone variants', () {
      final samples = <String>[
        'Gọi lại số 0912 345 678 giúp tôi',
        'Liên hệ +84 912 345 678 ngay',
        'SĐT 0912345678 của nạn nhân',
      ];
      for (final text in samples) {
        final r = PIIStripper.redactPII(text);
        expect(r.redactedText.contains('0912'), isFalse, reason: text);
        expect(r.tokensMap, isNotEmpty, reason: text);
      }
    });

    test('redacts OTP context but keeps year context soft', () {
      final otp = PIIStripper.redactPII(
        'Mã OTP của bạn là 123456, đọc giúp tôi',
      );
      expect(otp.redactedText.contains('123456'), isFalse);

      final year = PIIStripper.redactPII(
        'Sinh năm 1998 và tốt nghiệp năm 2024',
      );

      expect(year.redactedText, isNotEmpty);
    });

    test('redacts national id and bank-like digit runs', () {
      final cccd = PIIStripper.redactPII('Số CCCD 001234567890 của tôi');
      expect(cccd.redactedText.contains('001234567890'), isFalse);

      final bank = PIIStripper.redactPII(
        'Chuyển vào số tài khoản 0123456789 tại ngân hàng',
      );
      expect(bank.tokensMap, isNotEmpty);
    });

    test('restore round-trip for phone token', () {
      const original = 'Gọi 0909123456 ngay lập tức';
      final redacted = PIIStripper.redactPII(original);
      final restored = PIIStripper.restorePII(
        redacted.redactedText,
        redacted.tokensMap,
      );
      expect(restored, contains('0909123456'));
    });
  });
}
