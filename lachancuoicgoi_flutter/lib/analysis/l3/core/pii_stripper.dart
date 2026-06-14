class PiiRedactionResult {
  const PiiRedactionResult({
    required this.redactedText,
    required this.tokensMap,
  });

  final String redactedText;
  final Map<String, String> tokensMap;
}

enum _PiiType {
  personName('TEN_NGUOI'),
  phoneNumber('SO_DIEN_THOAI'),
  bankAccount('SO_TAI_KHOAN'),
  otp('MA_OTP'),
  nationalId('CCCD'),
  email('EMAIL'),
  address('DIA_CHI'),
  cardNumber('SO_THE');

  const _PiiType(this.tokenPrefix);

  final String tokenPrefix;
}

class _Replacement {
  const _Replacement({
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

class PIIStripper {
  static final List<String> _roleKeywords = <String>[
    'công an',
    'cong an',
    'kiểm sát',
    'kiem sat',
    'toà án',
    'toa an',
    'ngân hàng',
    'ngan hang',
    'bưu điện',
    'buu dien',
    'nhân viên',
    'nhan vien',
    'hỗ trợ',
    'ho tro',
    'đại úy',
    'dai uy',
    'thiếu tá',
    'thieu ta',
    'trung tá',
    'trung ta',
    'thượng tá',
    'thuong ta',
    'tổng đài',
    'tong dai',
    'chăm sóc khách hàng',
    'cham soc khach hang',
  ];

  static final RegExp _otpRegex = RegExp(
    r'\b(?:mã|ma)\s*(?:otp|xác minh|xac minh|bảo mật|bao mat|kích hoạt|kich hoat)\b(?:[^\d\n]{0,20})((?:\d[\s.-]?){3,7}\d)',
    caseSensitive: false,
  );

  static final RegExp _bankAccountRegex = RegExp(
    r'\b(?:số tài khoản|so tai khoan|số tk|so tk|stk|tài khoản|tai khoan)\b(?:[^\d\n]{0,20})((?:\d[\s.-]?){5,17}\d)',
    caseSensitive: false,
  );

  static final RegExp _nationalIdRegex = RegExp(
    r'\b(?:cccd|cmnd|căn cước|can cuoc|chứng minh nhân dân|chung minh nhan dan)\b(?:[^\d\n]{0,20})((?:\d[\s.-]?){8,11}\d)',
    caseSensitive: false,
  );

  static final RegExp _cardNumberRegex = RegExp(
    r'\b(?:số thẻ|so the|thẻ ngân hàng|the ngan hang|thẻ tín dụng|the tin dung)\b(?:[^\d\n]{0,20})((?:\d[\s-]?){12,18}\d)',
    caseSensitive: false,
  );

  static final RegExp _emailRegex = RegExp(
    r'\b[A-Z0-9._%+-]+@[A-Z0-9.-]+\.[A-Z]{2,}\b',
    caseSensitive: false,
  );

  static final RegExp _phoneRegex = RegExp(
    r'(?:\+84|84|0)(?:[\s.-]?\d){8,10}\b',
  );

  static final RegExp _personNameRegex = RegExp(
    r'\b(?:tôi tên là|toi ten la|em tên là|em ten la|anh tên là|anh ten la|chị tên là|chi ten la|cháu tên là|chau ten la|tên tôi là|ten toi la|tên em là|ten em la|người nhận là|nguoi nhan la|tôi là|toi la|em là|em la|anh là|anh la|chị là|chi la|cháu là|chau la)\s+([a-zà-ỹ]{2,}(?:\s+[a-zà-ỹ]{2,}){0,4})',
    caseSensitive: false,
  );

  static final RegExp _addressRegex = RegExp(
    r'\b(?:địa chỉ|dia chi|nhà ở|nha o|gửi về|gui ve|giao tới|giao toi)\b(?:\s*(?:là|la|:))?\s+([^,.!?;\n]{6,80})',
    caseSensitive: false,
  );

  static final RegExp _digitCleaner = RegExp(r'\D');

  static PiiRedactionResult redactPII(String originalText) {
    if (originalText.trim().isEmpty) {
      return PiiRedactionResult(
        redactedText: originalText,
        tokensMap: const <String, String>{},
      );
    }

    final counters = <_PiiType, int>{};
    final replacements = <_Replacement>[];
    final tokenByValue = <String, String>{};

    _collectContextualNumberReplacements(
      text: originalText,
      replacements: replacements,
      tokenByValue: tokenByValue,
      counters: counters,
      type: _PiiType.otp,
      regex: _otpRegex,
      groupIndex: 1,
    );
    _collectContextualNumberReplacements(
      text: originalText,
      replacements: replacements,
      tokenByValue: tokenByValue,
      counters: counters,
      type: _PiiType.bankAccount,
      regex: _bankAccountRegex,
      groupIndex: 1,
    );
    _collectContextualNumberReplacements(
      text: originalText,
      replacements: replacements,
      tokenByValue: tokenByValue,
      counters: counters,
      type: _PiiType.nationalId,
      regex: _nationalIdRegex,
      groupIndex: 1,
    );
    _collectContextualNumberReplacements(
      text: originalText,
      replacements: replacements,
      tokenByValue: tokenByValue,
      counters: counters,
      type: _PiiType.cardNumber,
      regex: _cardNumberRegex,
      groupIndex: 1,
    );
    _collectDirectReplacements(
      text: originalText,
      replacements: replacements,
      tokenByValue: tokenByValue,
      counters: counters,
      type: _PiiType.email,
      regex: _emailRegex,
      validator: (_) => true,
    );
    _collectCompactPhoneLabelReplacements(
      text: originalText,
      replacements: replacements,
      tokenByValue: tokenByValue,
      counters: counters,
    );
    _collectDirectReplacements(
      text: originalText,
      replacements: replacements,
      tokenByValue: tokenByValue,
      counters: counters,
      type: _PiiType.phoneNumber,
      regex: _phoneRegex,
      validator: (candidate) {
        final digits = candidate.replaceAll(_digitCleaner, '');
        return digits.length >= 9 && digits.length <= 11;
      },
    );
    _collectContextualTextReplacements(
      text: originalText,
      replacements: replacements,
      tokenByValue: tokenByValue,
      counters: counters,
      type: _PiiType.personName,
      regex: _personNameRegex,
      validator: (candidate) {
        final normalized = _normalizeVietnamese(candidate);
        final wordCount = normalized
            .split(' ')
            .where((part) => part.isNotEmpty)
            .length;
        return normalized.length >= 5 &&
            wordCount >= 2 &&
            wordCount <= 5 &&
            _roleKeywords.every((keyword) => !normalized.contains(keyword));
      },
    );
    _collectContextualTextReplacements(
      text: originalText,
      replacements: replacements,
      tokenByValue: tokenByValue,
      counters: counters,
      type: _PiiType.address,
      regex: _addressRegex,
      validator: (candidate) => candidate.trim().length >= 6,
    );

    if (replacements.isEmpty) {
      return PiiRedactionResult(
        redactedText: originalText,
        tokensMap: const <String, String>{},
      );
    }

    final buffer = StringBuffer();
    final tokensMap = <String, String>{};
    var lastIndex = 0;
    final sorted = replacements
      ..sort((left, right) => left.start.compareTo(right.start));
    for (final replacement in sorted) {
      if (replacement.start > lastIndex) {
        buffer.write(originalText.substring(lastIndex, replacement.start));
      }
      buffer.write(replacement.token);
      
      // Limit tokensMap size to 200 items to prevent memory leaks.
      // Since Dart maps preserve insertion order, the oldest entry is tokensMap.keys.first.
      if (!tokensMap.containsKey(replacement.token)) {
        if (tokensMap.length >= 200) {
          final oldestKey = tokensMap.keys.first;
          tokensMap.remove(oldestKey);
        }
        tokensMap[replacement.token] = replacement.originalValue;
      }
      
      lastIndex = replacement.end;
    }
    if (lastIndex < originalText.length) {
      buffer.write(originalText.substring(lastIndex));
    }
    return PiiRedactionResult(
      redactedText: buffer.toString(),
      tokensMap: tokensMap,
    );
  }

  static String restorePII(String redactedText, Map<String, String> tokensMap) {
    var restored = redactedText;
    final entries = tokensMap.entries.toList()
      ..sort((left, right) => right.key.length.compareTo(left.key.length));
    for (final entry in entries) {
      restored = restored.replaceAll(entry.key, entry.value);
    }
    return restored;
  }

  static void _collectContextualNumberReplacements({
    required String text,
    required List<_Replacement> replacements,
    required Map<String, String> tokenByValue,
    required Map<_PiiType, int> counters,
    required _PiiType type,
    required RegExp regex,
    required int groupIndex,
  }) {
    for (final match in regex.allMatches(text)) {
      final group = match.group(groupIndex);
      if (group == null) {
        continue;
      }
      final start = match.start + match.group(0)!.indexOf(group);
      _addReplacementIfValid(
        text: text,
        replacements: replacements,
        tokenByValue: tokenByValue,
        counters: counters,
        type: type,
        start: start,
        end: start + group.length,
        validator: (candidate) =>
            candidate.replaceAll(RegExp(r'\D'), '').isNotEmpty,
      );
    }
  }

  static void _collectContextualTextReplacements({
    required String text,
    required List<_Replacement> replacements,
    required Map<String, String> tokenByValue,
    required Map<_PiiType, int> counters,
    required _PiiType type,
    required RegExp regex,
    required bool Function(String candidate) validator,
  }) {
    for (final match in regex.allMatches(text)) {
      final group = match.group(1);
      if (group == null) {
        continue;
      }
      final start = match.start + match.group(0)!.indexOf(group);
      _addReplacementIfValid(
        text: text,
        replacements: replacements,
        tokenByValue: tokenByValue,
        counters: counters,
        type: type,
        start: start,
        end: start + group.length,
        validator: validator,
      );
    }
  }

  static void _collectDirectReplacements({
    required String text,
    required List<_Replacement> replacements,
    required Map<String, String> tokenByValue,
    required Map<_PiiType, int> counters,
    required _PiiType type,
    required RegExp regex,
    required bool Function(String candidate) validator,
  }) {
    for (final match in regex.allMatches(text)) {
      _addReplacementIfValid(
        text: text,
        replacements: replacements,
        tokenByValue: tokenByValue,
        counters: counters,
        type: type,
        start: match.start,
        end: match.end,
        validator: validator,
      );
    }
  }

  static void _collectCompactPhoneLabelReplacements({
    required String text,
    required List<_Replacement> replacements,
    required Map<String, String> tokenByValue,
    required Map<_PiiType, int> counters,
  }) {
    final regex = RegExp(
      r'\b(?:số điện thoại|so dien thoai|sdt|điện thoại|dien thoai)\s+((?:\+84|84|0)(?:[\s.-]?\d){8,10})\b',
      caseSensitive: false,
    );
    for (final match in regex.allMatches(text)) {
      final phoneNumber = match.group(1);
      if (phoneNumber == null) continue;
      _addReplacementIfValid(
        text: text,
        replacements: replacements,
        tokenByValue: tokenByValue,
        counters: counters,
        type: _PiiType.phoneNumber,
        start: match.start,
        end: match.end,
        tokenKeyValue: phoneNumber.replaceAll(RegExp(r'\D'), ''),
        storedOriginalValue: phoneNumber,
        validator: (_) {
          final digits = phoneNumber.replaceAll(RegExp(r'\D'), '');
          return digits.length >= 9 && digits.length <= 11;
        },
      );
    }
  }

  static void _addReplacementIfValid({
    required String text,
    required List<_Replacement> replacements,
    required Map<String, String> tokenByValue,
    required Map<_PiiType, int> counters,
    required _PiiType type,
    required int start,
    required int end,
    required bool Function(String candidate) validator,
    String? tokenKeyValue,
    String? storedOriginalValue,
  }) {
    if (start < 0 ||
        end > text.length ||
        start >= end ||
        _hasOverlap(replacements, start, end)) {
      return;
    }
    final originalValue = text.substring(start, end).trim();
    if (!validator(originalValue)) {
      return;
    }
    final tokenKey =
        '${type.name}:${_normalizeVietnamese(tokenKeyValue ?? originalValue)}';
    // The putIfAbsent callback only fires for keys not yet seen, so
    // `counters[type]` advances exactly once per unique PII value.
    // Re-occurrences of the same value reuse the previously assigned
    // token (no gap in numbering) and the validator result from a
    // previous call already determined whether the token was created.
    final token = tokenByValue.putIfAbsent(tokenKey, () {
      final nextIndex = (counters[type] ?? 0) + 1;
      counters[type] = nextIndex;
      return '[${type.tokenPrefix}_$nextIndex]';
    });
    replacements.add(
      _Replacement(
        start: start,
        end: end,
        token: token,
        originalValue: storedOriginalValue ?? originalValue,
      ),
    );
  }

  static bool _hasOverlap(List<_Replacement> replacements, int start, int end) {
    for (final replacement in replacements) {
      if (start < replacement.end && end > replacement.start) {
        return true;
      }
    }
    return false;
  }

  static String _normalizeVietnamese(String input) {
    return input.trim().toLowerCase().replaceAll(RegExp(r'\s+'), ' ');
  }
}
