enum NoiseMode {
  remove,
  space,
}

class TextNormalizer {
  TextNormalizer._();

  static List<MapEntry<String, String>> _slangEntries =
      const <MapEntry<String, String>>[];

  static const Map<String, String> _phoneticMap = {
    '0': 'o',
    '1': 'i',
    '3': 'e',
    '4': 'a',
    '5': 's',
    '7': 't',
    '8': 'b',
    'à': 'a',
    'á': 'a',
    'ạ': 'a',
    'ả': 'a',
    'ã': 'a',
    'â': 'a',
    'ầ': 'a',
    'ấ': 'a',
    'ậ': 'a',
    'ẩ': 'a',
    'ẫ': 'a',
    'ă': 'a',
    'ằ': 'a',
    'ắ': 'a',
    'ặ': 'a',
    'ẳ': 'a',
    'ẵ': 'a',
    'è': 'e',
    'é': 'e',
    'ẹ': 'e',
    'ẻ': 'e',
    'ẽ': 'e',
    'ê': 'e',
    'ề': 'e',
    'ế': 'e',
    'ệ': 'e',
    'ể': 'e',
    'ễ': 'e',
    'ì': 'i',
    'í': 'i',
    'ị': 'i',
    'ỉ': 'i',
    'ĩ': 'i',
    'ò': 'o',
    'ó': 'o',
    'ọ': 'o',
    'ỏ': 'o',
    'õ': 'o',
    'ô': 'o',
    'ồ': 'o',
    'ố': 'o',
    'ộ': 'o',
    'ổ': 'o',
    'ỗ': 'o',
    'ơ': 'o',
    'ờ': 'o',
    'ớ': 'o',
    'ợ': 'o',
    'ở': 'o',
    'ỡ': 'o',
    'ù': 'u',
    'ú': 'u',
    'ụ': 'u',
    'ủ': 'u',
    'ũ': 'u',
    'ư': 'u',
    'ừ': 'u',
    'ứ': 'u',
    'ự': 'u',
    'ử': 'u',
    'ữ': 'u',
    'ỳ': 'y',
    'ý': 'y',
    'ỵ': 'y',
    'ỷ': 'y',
    'ỹ': 'y',
    'đ': 'd',
  };

  static final Map<int, int> _phoneticCodeUnitMap = _phoneticMap.map(
    (key, value) => MapEntry(key.codeUnitAt(0), value.codeUnitAt(0)),
  );


  static final RegExp _combiningMarks = RegExp(r'[\u0300-\u036f]');
  static final RegExp _noiseChars = RegExp(
    r'[^\p{L}\p{N}\s]',
    unicode: true,
  );

  static void loadSlangConfig(Map<String, String> config) {
    final entries = config.entries
        .map(
          (entry) => MapEntry(
            normalize(entry.key, applySlang: false),
            normalize(entry.value, applySlang: false),
          ),
        )
        .toList()
      ..sort((a, b) => b.key.length.compareTo(a.key.length));
    _slangEntries = List<MapEntry<String, String>>.unmodifiable(entries);
  }

  static String normalize(
    String text, {
    bool applySlang = true,
    NoiseMode noiseMode = NoiseMode.remove,
  }) {
    var result = text.toLowerCase();

    result = _mapPhoneticCharacters(result);
    result = result.replaceAll(_combiningMarks, '');

    result = switch (noiseMode) {
      NoiseMode.remove => result.replaceAll(_noiseChars, ''),
      NoiseMode.space => result.replaceAll(_noiseChars, ' '),
    };

    result = result.trim().replaceAll(RegExp(r'\s+'), ' ');

    if (applySlang && _slangEntries.isNotEmpty) {
      for (final entry in _slangEntries) {
        result =
            ' $result '.replaceAll(' ${entry.key} ', ' ${entry.value} ').trim();
      }
    }

    return result;
  }

  static List<String> tokenize(
    String text, {
    bool applySlang = true,
    NoiseMode noiseMode = NoiseMode.remove,
  }) {
    final normalized = normalize(
      text,
      applySlang: applySlang,
      noiseMode: noiseMode,
    );
    if (normalized.isEmpty) return const [];
    return normalized
        .split(RegExp(r'\s+'))
        .where((token) => token.isNotEmpty)
        .toList();
  }

  static String _mapPhoneticCharacters(String value) {
    final length = value.length;
    var modified = false;
    for (var i = 0; i < length; i++) {
      final codeUnit = value.codeUnitAt(i);
      if (_phoneticCodeUnitMap.containsKey(codeUnit)) {
        modified = true;
        break;
      }
    }
    if (!modified) return value;

    final codeUnits = List<int>.filled(length, 0);
    for (var i = 0; i < length; i++) {
      final codeUnit = value.codeUnitAt(i);
      codeUnits[i] = _phoneticCodeUnitMap[codeUnit] ?? codeUnit;
    }
    return String.fromCharCodes(codeUnits);
  }

}
