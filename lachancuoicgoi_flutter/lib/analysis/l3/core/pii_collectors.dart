import 'pii_regex.dart' as regex;
import 'pii_types.dart';

/// Collector functions that scan text for PII patterns and produce
/// [Replacement] entries.
///
/// Each collector targets a specific [PiiType] and uses a specific regex
/// strategy: contextual number (keyword + number group), contextual text
/// (keyword + text group), direct (full match), or compact label.
class PiiCollectors {
  /// Collect OTP codes with contextual number pattern.
  static void collectOtp(
    String text,
    List<Replacement> replacements,
    Map<String, String> tokenByValue,
    Map<PiiType, int> counters,
  ) {
    _collectContextualNumber(
      text: text,
      replacements: replacements,
      tokenByValue: tokenByValue,
      counters: counters,
      type: PiiType.otp,
      pattern: regex.otpRegex,
      groupIndex: 1,
    );
  }

  /// Collect bank account numbers with contextual number pattern.
  static void collectBankAccount(
    String text,
    List<Replacement> replacements,
    Map<String, String> tokenByValue,
    Map<PiiType, int> counters,
  ) {
    _collectContextualNumber(
      text: text,
      replacements: replacements,
      tokenByValue: tokenByValue,
      counters: counters,
      type: PiiType.bankAccount,
      pattern: regex.bankAccountRegex,
      groupIndex: 1,
    );
  }

  /// Collect national ID numbers with contextual number pattern.
  static void collectNationalId(
    String text,
    List<Replacement> replacements,
    Map<String, String> tokenByValue,
    Map<PiiType, int> counters,
  ) {
    _collectContextualNumber(
      text: text,
      replacements: replacements,
      tokenByValue: tokenByValue,
      counters: counters,
      type: PiiType.nationalId,
      pattern: regex.nationalIdRegex,
      groupIndex: 1,
    );
  }

  /// Collect card numbers with contextual number pattern.
  static void collectCardNumber(
    String text,
    List<Replacement> replacements,
    Map<String, String> tokenByValue,
    Map<PiiType, int> counters,
  ) {
    _collectContextualNumber(
      text: text,
      replacements: replacements,
      tokenByValue: tokenByValue,
      counters: counters,
      type: PiiType.cardNumber,
      pattern: regex.cardNumberRegex,
      groupIndex: 1,
    );
  }

  /// Collect email addresses (direct match).
  static void collectEmails(
    String text,
    List<Replacement> replacements,
    Map<String, String> tokenByValue,
    Map<PiiType, int> counters,
  ) {
    _collectDirect(
      text: text,
      replacements: replacements,
      tokenByValue: tokenByValue,
      counters: counters,
      type: PiiType.email,
      pattern: regex.emailRegex,
      validator: (_) => true,
    );
  }

  /// Collect URLs (direct match).
  static void collectUrls(
    String text,
    List<Replacement> replacements,
    Map<String, String> tokenByValue,
    Map<PiiType, int> counters,
  ) {
    _collectDirect(
      text: text,
      replacements: replacements,
      tokenByValue: tokenByValue,
      counters: counters,
      type: PiiType.urlLink,
      pattern: regex.urlRegex,
      validator: (_) => true,
    );
  }

  /// Collect social media handles (contextual text).
  static void collectSocialMedia(
    String text,
    List<Replacement> replacements,
    Map<String, String> tokenByValue,
    Map<PiiType, int> counters,
  ) {
    _collectContextualText(
      text: text,
      replacements: replacements,
      tokenByValue: tokenByValue,
      counters: counters,
      type: PiiType.socialMedia,
      pattern: regex.socialMediaRegex,
      validator: (_) => true,
    );
  }

  /// Collect dates of birth (contextual text).
  static void collectDateOfBirth(
    String text,
    List<Replacement> replacements,
    Map<String, String> tokenByValue,
    Map<PiiType, int> counters,
  ) {
    _collectContextualText(
      text: text,
      replacements: replacements,
      tokenByValue: tokenByValue,
      counters: counters,
      type: PiiType.dateOfBirth,
      pattern: regex.dobRegex,
      validator: (_) => true,
    );
  }

  /// Collect partial PII disclosures (contextual text, categorized as bankAccount).
  static void collectPartialPii(
    String text,
    List<Replacement> replacements,
    Map<String, String> tokenByValue,
    Map<PiiType, int> counters,
  ) {
    _collectContextualText(
      text: text,
      replacements: replacements,
      tokenByValue: tokenByValue,
      counters: counters,
      type: PiiType.bankAccount,
      pattern: regex.partialPiiRegex,
      validator: (_) => true,
    );
  }

  /// Collect phone numbers with compact labels.
  static void collectCompactPhoneLabels(
    String text,
    List<Replacement> replacements,
    Map<String, String> tokenByValue,
    Map<PiiType, int> counters,
  ) {
    for (final match in regex.compactPhoneRegex.allMatches(text)) {
      final phoneNumber = match.group(1);
      if (phoneNumber == null) continue;
      _addReplacementIfValid(
        text: text,
        replacements: replacements,
        tokenByValue: tokenByValue,
        counters: counters,
        type: PiiType.phoneNumber,
        start: match.start,
        end: match.end,
        tokenKeyValue: phoneNumber.replaceAll(regex.digitCleaner, ''),
        storedOriginalValue: phoneNumber,
        validator: (_) => regex.isValidPhoneNumber(phoneNumber),
      );
    }
  }

  /// Collect raw phone numbers (direct match).
  static void collectPhoneNumbers(
    String text,
    List<Replacement> replacements,
    Map<String, String> tokenByValue,
    Map<PiiType, int> counters,
  ) {
    _collectDirect(
      text: text,
      replacements: replacements,
      tokenByValue: tokenByValue,
      counters: counters,
      type: PiiType.phoneNumber,
      pattern: regex.phoneRegex,
      validator: regex.isValidPhoneNumber,
    );
  }

  /// Collect person names with context clues.
  static void collectContextualPersonNames(
    String text,
    List<Replacement> replacements,
    Map<String, String> tokenByValue,
    Map<PiiType, int> counters,
  ) {
    _collectContextualText(
      text: text,
      replacements: replacements,
      tokenByValue: tokenByValue,
      counters: counters,
      type: PiiType.personName,
      pattern: regex.personNameRegex,
      validator: regex.isValidPersonName,
    );
  }

  /// Collect generic Vietnamese names (no context clue required).
  static void collectGenericNames(
    String text,
    List<Replacement> replacements,
    Map<String, String> tokenByValue,
    Map<PiiType, int> counters,
  ) {
    _collectDirect(
      text: text,
      replacements: replacements,
      tokenByValue: tokenByValue,
      counters: counters,
      type: PiiType.personName,
      pattern: regex.genericNameRegex,
      validator: regex.isValidPersonName,
    );
  }

  /// Collect addresses (contextual text).
  static void collectAddresses(
    String text,
    List<Replacement> replacements,
    Map<String, String> tokenByValue,
    Map<PiiType, int> counters,
  ) {
    _collectContextualText(
      text: text,
      replacements: replacements,
      tokenByValue: tokenByValue,
      counters: counters,
      type: PiiType.address,
      pattern: regex.addressRegex,
      validator: (candidate) => candidate.trim().length >= 6,
    );
  }

  // ─── Internal collector strategies ──────────────────────────────────

  static void _collectContextualNumber({
    required String text,
    required List<Replacement> replacements,
    required Map<String, String> tokenByValue,
    required Map<PiiType, int> counters,
    required PiiType type,
    required RegExp pattern,
    required int groupIndex,
  }) {
    for (final match in pattern.allMatches(text)) {
      final group = match.group(groupIndex);
      if (group == null) continue;
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
            candidate.replaceAll(regex.digitCleaner, '').isNotEmpty,
      );
    }
  }

  static void _collectContextualText({
    required String text,
    required List<Replacement> replacements,
    required Map<String, String> tokenByValue,
    required Map<PiiType, int> counters,
    required PiiType type,
    required RegExp pattern,
    required bool Function(String candidate) validator,
  }) {
    for (final match in pattern.allMatches(text)) {
      final group = match.group(1);
      if (group == null) continue;
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

  static void _collectDirect({
    required String text,
    required List<Replacement> replacements,
    required Map<String, String> tokenByValue,
    required Map<PiiType, int> counters,
    required PiiType type,
    required RegExp pattern,
    required bool Function(String candidate) validator,
  }) {
    for (final match in pattern.allMatches(text)) {
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

  static void _addReplacementIfValid({
    required String text,
    required List<Replacement> replacements,
    required Map<String, String> tokenByValue,
    required Map<PiiType, int> counters,
    required PiiType type,
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
    if (RegExp(r'\d').hasMatch(originalValue)) {
      final hasDigitBefore =
          start > 0 && RegExp(r'\d').hasMatch(text[start - 1]);
      final hasDigitAfter =
          end < text.length && RegExp(r'\d').hasMatch(text[end]);
      if (hasDigitBefore || hasDigitAfter) {
        return;
      }
    }
    if (!validator(originalValue)) {
      return;
    }
    final tokenKey =
        '${type.name}:${regex.normalizeVietnamese(tokenKeyValue ?? originalValue)}';
    final token = tokenByValue.putIfAbsent(tokenKey, () {
      final nextIndex = (counters[type] ?? 0) + 1;
      counters[type] = nextIndex;
      return '[${type.tokenPrefix}_$nextIndex]';
    });
    replacements.add(
      Replacement(
        start: start,
        end: end,
        token: token,
        originalValue: storedOriginalValue ?? originalValue,
      ),
    );
  }

  static bool _hasOverlap(List<Replacement> replacements, int start, int end) {
    for (final replacement in replacements) {
      if (start < replacement.end && end > replacement.start) {
        return true;
      }
    }
    return false;
  }
}
