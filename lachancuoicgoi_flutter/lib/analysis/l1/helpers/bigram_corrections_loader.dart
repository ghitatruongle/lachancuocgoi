// Wave 3 refactor: Extract bigram corrections loading from L1Analyzer.
//
// Pure parsing logic with no Flutter dependencies. Can be unit tested directly.

import 'dart:convert';

import '../../../core/logger.dart';

/// Represents a single bigram correction entry.
class TokenCorrection {
  final List<String> from;
  final List<String> to;

  const TokenCorrection(this.from, this.to);
}

/// Helper for loading and parsing bigram corrections from JSON.
class BigramCorrectionsLoader {
  /// Loads corrections from JSON string and populates the output map.
  ///
  /// @param jsonText JSON string containing `corrections` array.
  /// @param corrections Output map keyed by first word of `from` list.
  /// @param logger Optional logger for error reporting.
  static void loadFromJson(
    String jsonText,
    Map<String, List<TokenCorrection>> corrections,
    AppLogger? logger,
  ) {
    try {
      final decoded = jsonDecode(jsonText);
      if (decoded is! Map<String, dynamic>) return;

      final correctionsList = decoded['corrections'];
      if (correctionsList is! List) return;

      for (final rawEntry in correctionsList) {
        if (rawEntry is! Map) continue;
        final from = _readTokenList(rawEntry['from']);
        final to = _readTokenList(rawEntry['to']);
        if (from.isEmpty || to.isEmpty) continue;

        final firstWord = from.first;
        corrections
            .putIfAbsent(firstWord, () => [])
            .add(TokenCorrection(from, to));
      }

      // Sort by length (longest first) for greedy matching.
      for (final list in corrections.values) {
        list.sort((a, b) => b.from.length.compareTo(a.from.length));
      }
    } on Object catch (e) {
      logger?.warning('Failed to parse bigram corrections: $e');
    }
  }

  static List<String> _readTokenList(dynamic value) {
    if (value is! List) return const [];
    return value.whereType<String>().toList(growable: false);
  }
}