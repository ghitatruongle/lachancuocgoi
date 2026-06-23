/// Result of PII redaction containing the redacted text and a mapping
/// from tokens back to original values for restoration.
class PiiRedactionResult {
  const PiiRedactionResult({
    required this.redactedText,
    required this.tokensMap,
  });

  final String redactedText;
  final Map<String, String> tokensMap;
}

/// Types of personally identifiable information detected and redacted.
enum PiiType {
  personName('TEN_NGUOI'),
  phoneNumber('SO_DIEN_THOAI'),
  bankAccount('SO_TAI_KHOAN'),
  otp('MA_OTP'),
  nationalId('CCCD'),
  email('EMAIL'),
  address('DIA_CHI'),
  cardNumber('SO_THE'),
  socialMedia('MANG_XA_HOI'),
  urlLink('DUONG_DAN'),
  dateOfBirth('NGAY_SINH');

  const PiiType(this.tokenPrefix);

  final String tokenPrefix;
}

/// Internal: tracks a single replacement span in the original text.
class Replacement {
  const Replacement({
    required this.start,
    required this.end,
    required this.token,
    required this.originalValue,
  });

  final int start;
  final int end;
  final String token;
  final String originalValue;
}
