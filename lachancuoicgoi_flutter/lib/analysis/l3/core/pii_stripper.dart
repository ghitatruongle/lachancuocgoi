import 'pii_collectors.dart';
import 'pii_types.dart';

class PIIStripper {
  static const int _maxTokensMapSize = 500;

  static PiiRedactionResult redactPII(String originalText) {
    if (originalText.trim().isEmpty) {
      return PiiRedactionResult(
        redactedText: originalText,
        tokensMap: <String, String>{},
      );
    }

    final counters = <PiiType, int>{};
    final replacements = <Replacement>[];
    final tokenByValue = <String, String>{};

    PiiCollectors.collectOtp(
      originalText,
      replacements,
      tokenByValue,
      counters,
    );
    PiiCollectors.collectBankAccount(
      originalText,
      replacements,
      tokenByValue,
      counters,
    );
    PiiCollectors.collectNationalId(
      originalText,
      replacements,
      tokenByValue,
      counters,
    );
    PiiCollectors.collectCardNumber(
      originalText,
      replacements,
      tokenByValue,
      counters,
    );
    PiiCollectors.collectEmails(
      originalText,
      replacements,
      tokenByValue,
      counters,
    );
    PiiCollectors.collectUrls(
      originalText,
      replacements,
      tokenByValue,
      counters,
    );
    PiiCollectors.collectSocialMedia(
      originalText,
      replacements,
      tokenByValue,
      counters,
    );
    PiiCollectors.collectDateOfBirth(
      originalText,
      replacements,
      tokenByValue,
      counters,
    );
    PiiCollectors.collectPartialPii(
      originalText,
      replacements,
      tokenByValue,
      counters,
    );
    PiiCollectors.collectCompactPhoneLabels(
      originalText,
      replacements,
      tokenByValue,
      counters,
    );
    PiiCollectors.collectPhoneNumbers(
      originalText,
      replacements,
      tokenByValue,
      counters,
    );
    PiiCollectors.collectContextualPersonNames(
      originalText,
      replacements,
      tokenByValue,
      counters,
    );
    PiiCollectors.collectGenericNames(
      originalText,
      replacements,
      tokenByValue,
      counters,
    );
    PiiCollectors.collectAddresses(
      originalText,
      replacements,
      tokenByValue,
      counters,
    );

    if (replacements.isEmpty) {
      return PiiRedactionResult(
        redactedText: originalText,
        tokensMap: <String, String>{},
      );
    }

    return _buildResult(originalText, replacements);
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

  static PiiRedactionResult _buildResult(
    String originalText,
    List<Replacement> replacements,
  ) {
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

      if (!tokensMap.containsKey(replacement.token)) {
        if (tokensMap.length >= _maxTokensMapSize) {
          throw StateError(
            'PII tokens map exceeded maximum size of $_maxTokensMapSize. '
            'Transcript contains too many PII entities to safely restore. '
            'Refusing to produce a partial/redacted result to avoid leaking '
            'placeholders into the final analysis.',
          );
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
}
