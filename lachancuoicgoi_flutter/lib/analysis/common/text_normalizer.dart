enum NoiseMode {
  remove,
  space,
}

class TextNormalizer {
  TextNormalizer._();

  static final List<MapEntry<String, String>> _slangEntries = [];

  static const Map<String, String> _phoneticMap = {
    '0': 'o',
    '1': 'i',
    '3': 'e',
    '4': 'a',
    '5': 's',
    '7': 't',
    '8': 'b',
    'đ': 'd',
    'Đ': 'd',
  };

  static final RegExp _noiseChars = RegExp(
    r'[^\p{L}\p{N}\s]',
    unicode: true,
  );

  static void loadSlangConfig(Map<String, String> config) {
    _slangEntries
      ..clear()
      ..addAll(
        config.entries.map(
          (entry) => MapEntry(
            normalize(entry.key, applySlang: false),
            normalize(entry.value, applySlang: false),
          ),
        ),
      )
      ..sort((a, b) => b.key.length.compareTo(a.key.length));
  }

  static String normalize(
    String text, {
    bool applySlang = true,
    NoiseMode noiseMode = NoiseMode.remove,
  }) {
    var result = text.toLowerCase();

    for (final entry in _phoneticMap.entries) {
      result = result.replaceAll(entry.key, entry.value);
    }

    result = _stripVietnameseAccents(result);

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

  static String _stripVietnameseAccents(String value) {
    const source =
        'àáạảãâầấậẩẫăằắặẳẵèéẹẻẽêềếệểễìíịỉĩòóọỏõôồốộổỗơờớợởỡùúụủũưừứựửữỳýỵỷỹ';
    const target =
        'aaaaaaaaaaaaaaaaaeeeeeeeeeeeiiiiiooooooooooooooooouuuuuuuuuuuyyyyy';
    var output = value;
    for (var i = 0; i < source.length; i++) {
      output = output.replaceAll(source[i], target[i]);
    }
    return output;
  }
}
