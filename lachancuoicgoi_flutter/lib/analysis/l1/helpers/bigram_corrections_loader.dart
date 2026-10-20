import 'dart:convert';

import '../../../core/logger.dart';

class TokenCorrection {
  final List<String> from;
  final List<String> to;

  const TokenCorrection(this.from, this.to);
}

class BigramCorrectionsLoader {
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
