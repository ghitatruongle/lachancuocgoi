// Wave 3 refactor: Extract Vietnamese number word normalization from TextNormalizer.
//
// Pure helper for converting Vietnamese number words ("năm trăm nghìn") to digits.

class VietnameseNumberNormalizer {
  VietnameseNumberNormalizer._();

  static const Map<String, int> _numberWordValues = {
    'khong': 0,
    'mot': 1,
    'hai': 2,
    'ba': 3,
    'bon': 4,
    'lam': 5,
    'sau': 6,
    'bay': 7,
    'tam': 8,
    'chin': 9,
    'muoi': 10,
    'tram': 100,
    'nghin': 1000,
    'ngan': 1000,
    'trieu': 1000000,
    'ti': 1000000000,
    'ty': 1000000000,
  };

  static final RegExp _numberWordPattern = RegExp(
    r'\b(?:(?:mot|hai|ba|bon|lam|sau|bay|tam|chin|muoi|'
    r'tram|nghin|ngan|trieu|ti|ty|khong)\s*){2,8}\b',
    caseSensitive: false,
  );

  /// Converts Vietnamese number words to digits.
  /// E.g. "nam tram nghin" → "500000", "hai trieu" → "2000000".
  static String normalize(String text) {
    return text.replaceAllMapped(_numberWordPattern, (match) {
      final words = match.group(0)!.trim().split(RegExp(r'\s+'));
      final result = _parseVietnameseNumber(words);
      if (result == null) return match.group(0)!;
      return result.toString();
    });
  }

  static int? _parseVietnameseNumber(List<String> words) {
    if (words.isEmpty || words.length > 8) return null;
    int total = 0;
    int current = 0;
    bool matched = false;

    for (final word in words) {
      final value = _numberWordValues[word];
      if (value == null) return null;
      matched = true;

      if (value == 1000000000) {
        total += (current == 0 ? 1 : current) * value;
        current = 0;
      } else if (value == 1000000) {
        total += (current == 0 ? 1 : current) * value;
        current = 0;
      } else if (value >= 1000) {
        current = (current == 0 ? 1 : current) * value;
      } else if (value == 100) {
        current = (current == 0 ? 1 : current) * value;
      } else if (value == 10) {
        current = current == 0 ? 10 : current * 10;
      } else {
        current += value;
      }
    }
    if (!matched) return null;
    total += current;
    return total > 0 ? total : null;
  }
}
