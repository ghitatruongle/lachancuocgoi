import 'pii_collectors.dart';
import 'pii_types.dart';

/// Facade for Vietnamese PII redaction and restoration.
///
/// Delegates to [PiiCollectors] for pattern scanning and uses [PiiRedactionResult]
/// for the output. The regex definitions live in [pii_regex] and the collector
/// implementations in [pii_collectors] — this file orchestrates the pipeline.
class PIIStripper {
  /// Maximum size of the tokens map to prevent memory leaks.
  ///
  /// BUG FIX (Bug #5): Originally 200 tokens. If a transcript contains more
  /// than 200 PII entities (rare but possible in long calls), the oldest
  /// tokens were evicted from the map, making them impossible to restore —
  /// placeholders like `[SO_DIEN_THOAI_1]` would leak into the final
  /// analysis output instead of the original phone number.
  ///
  /// Fix: throw a [StateError] when the limit is exceeded so the caller can
  /// surface a clear failure instead of silently corrupting the result. We
  /// deliberately do NOT silently drop tokens — every PII entity must be
  /// restorable to keep the LLM analysis trustworthy.
  static const int _maxTokensMapSize = 500;

  /// Scans [originalText] for Vietnamese PII patterns, replaces each with a
  /// unique token (e.g. `[SO_DIEN_THOAI_1]`), and returns the redacted result
  /// along with the token-to-original mapping for later restoration.
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

    // Run all collectors in priority order (most specific first).
    // Order matters: contextual matches before generic ones to reduce false
    // positives and overlapping match resolution.
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

  /// Reverses the redaction: replaces tokens in [redactedText] with their
  /// original values from [tokensMap].
  static String restorePII(String redactedText, Map<String, String> tokensMap) {
    var restored = redactedText;
    final entries = tokensMap.entries.toList()
      ..sort((left, right) => right.key.length.compareTo(left.key.length));
    for (final entry in entries) {
      restored = restored.replaceAll(entry.key, entry.value);
    }
    return restored;
  }

  /// Builds the final redacted string from the original text and sorted
  /// replacements, applying the tokensMap size limit.
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

      // Limit tokensMap size to prevent memory leaks.
      // Since Dart maps preserve insertion order, the oldest entry is
      // tokensMap.keys.first.
      //
      // BUG FIX (Bug #5): Previously the oldest entry was silently dropped,
      // which caused PII placeholders to leak into the restored analysis
      // text (e.g. `[SO_DIEN_THOAI_1]` instead of the real phone number).
      // Instead of silently corrupting the result, throw a clear error so
      // the caller knows the transcript exceeded the safe limit.
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
