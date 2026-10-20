import 'helpers/vietnamese_number_normalizer.dart';

enum NoiseMode { remove, space }

class TextNormalizer {
  TextNormalizer._();

  static _SlangAutomaton? _slangAutomaton;

  static String _normalizeNumberWords(String text) {
    return VietnameseNumberNormalizer.normalize(text);
  }

  static const Map<String, String> _asrCorrectionsRaw = {
    'luyện đạo': 'lừa đảo',
    'luân đảo': 'lừa đảo',
    'chuyển tiên': 'chuyển tiền',
    'chuyên tiên': 'chuyển tiền',
    'mã o tê pê': 'mã otp',
    'mã ô tê pê': 'mã otp',
    'công an an': 'công an',
    'côông an': 'công an',
    'tải khỏan': 'tài khoản',
    'mat khẩu': 'mật khẩu',
    'căn cươc': 'căn cước',
  };

  static const List<MapEntry<String, String>> _telexCorrectionsRaw = [
    MapEntry('chuyeene', 'chuyển'),
    MapEntry('chuyeenr', 'chuyển'),
    MapEntry('nguwowif', 'người'),
    MapEntry('nguwowi', 'người'),
    MapEntry('thooif', 'thời'),
    MapEntry('dduowwcj', 'được'),
    MapEntry('dduowc', 'đươc'),
    MapEntry('dduoc', 'được'),
    MapEntry('khoong', 'không'),
    MapEntry('bieets', 'biết'),
    MapEntry('biete', 'biết'),
    MapEntry('muoons', 'muốn'),
    MapEntry('tieenf', 'tiền'),
  ];

  static Map<String, String>? _asrCorrectionsNormalized;

  static Map<String, String> get _asrCorrections {
    return _asrCorrectionsNormalized ??= _buildAsrCorrections();
  }

  static Map<String, String> _buildAsrCorrections() {
    final map = <String, String>{};
    for (final entry in _asrCorrectionsRaw.entries) {
      final normKey = _phoneticStrip(entry.key);
      final normValue = _phoneticStrip(entry.value);
      if (normKey != normValue) {
        map.putIfAbsent(normKey, () => normValue);
      }
    }
    return map;
  }

  static String _phoneticStrip(String text) {
    var result = text.toLowerCase();
    result = _mapPhoneticCharacters(result);
    result = result.replaceAll(_combiningMarks, '');
    result = result.replaceAll(_noiseChars, ' ');
    return result.trim().replaceAll(RegExp(r'\s+'), ' ');
  }

  static String _correctAsrErrors(String text) {
    var result = text;
    for (final entry in _asrCorrections.entries) {
      if (result.contains(entry.key)) {
        result = result.replaceAll(entry.key, entry.value);
      }
    }
    return result;
  }

  static String _correctTelexErrors(String text) {
    var result = text;
    for (final entry in _telexCorrectionsRaw) {
      if (result.contains(entry.key)) {
        result = result.replaceAll(entry.key, entry.value);
      }
    }
    return result;
  }

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
  static final RegExp _noiseChars = RegExp(r'[^\p{L}\p{N}\s]', unicode: true);

  static void loadSlangConfig(Map<String, String> config) {
    final entries =
        config.entries
            .map(
              (entry) => MapEntry(
                normalize(entry.key, applySlang: false),
                normalize(entry.value, applySlang: false),
              ),
            )
            .toList()
          ..sort((a, b) => b.key.length.compareTo(a.key.length));

    _slangAutomaton = entries.isEmpty ? null : _SlangAutomaton.build(entries);
  }

  static String normalize(
    String text, {
    bool applySlang = true,
    NoiseMode noiseMode = NoiseMode.remove,
  }) {
    var result = _correctTelexErrors(text);

    result = result.toLowerCase();

    result = _mapPhoneticCharacters(result);
    result = result.replaceAll(_combiningMarks, '');

    result = switch (noiseMode) {
      NoiseMode.remove => result.replaceAll(_noiseChars, ''),
      NoiseMode.space => result.replaceAll(_noiseChars, ' '),
    };

    result = result.trim().replaceAll(RegExp(r'\s+'), ' ');

    result = _correctAsrErrors(result);

    if (applySlang && _slangAutomaton != null) {
      result = _slangAutomaton!.replaceAll(result);
    }

    result = _normalizeNumberWords(result);

    return result;
  }

  static String normalizeForCache(String text) {
    return text
        .toLowerCase()
        .replaceAll(_noiseChars, ' ')
        .trim()
        .replaceAll(RegExp(r'\s+'), ' ');
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

class _SlangAutomaton {
  _SlangAutomaton._();

  final List<Map<String, int>> _children = [{}];
  final List<int> _failure = [0];
  final List<int> _dictionary = [0];
  final List<String?> _output = [null];
  final List<int> _depth = [0];
  int _size = 1;

  factory _SlangAutomaton.build(List<MapEntry<String, String>> entries) {
    final auto = _SlangAutomaton._();
    for (final entry in entries) {
      auto._insert(entry.key, entry.value);
    }
    auto._buildFailureLinks();
    return auto;
  }

  void _insert(String pattern, String replacement) {
    if (pattern.isEmpty) return;
    var current = 0;
    final tokens = pattern.split(' ');
    for (final token in tokens) {
      final children = _children[current];
      if (children.containsKey(token)) {
        current = children[token]!;
      } else {
        final newNode = _size++;
        _children.add({});
        _failure.add(0);
        _dictionary.add(0);
        _output.add(null);
        _depth.add(_depth[current] + 1);
        children[token] = newNode;
        current = newNode;
      }
    }
    _output[current] = replacement;
  }

  String replaceAll(String text) {
    if (text.isEmpty) return text;
    final tokens = text.split(' ').where((t) => t.isNotEmpty).toList();
    if (tokens.isEmpty) return text;

    final matches = <(int, int, String)>[];
    var state = 0;

    for (var i = 0; i < tokens.length; i++) {
      final token = tokens[i];
      while (state != 0 && !_children[state].containsKey(token)) {
        state = _failure[state];
      }
      state = _children[state][token] ?? 0;

      var temp = state;
      while (temp != 0) {
        final out = _output[temp];
        if (out != null) {
          final patternLen = _depth[temp];
          final startIdx = i - patternLen + 1;
          if (startIdx >= 0) {
            matches.add((startIdx, i, out));
          }
        }
        temp = _dictionary[temp];
        if (temp == 0) break;
      }
    }

    if (matches.isEmpty) return text;

    matches.sort((a, b) {
      final cmp = a.$1.compareTo(b.$1);
      if (cmp != 0) return cmp;
      return (b.$2 - b.$1).compareTo(a.$2 - a.$1);
    });

    final result = <String>[];
    var lastEnd = -1;
    var matchIdx = 0;

    for (var i = 0; i < tokens.length; i++) {
      if (i <= lastEnd) continue;

      while (matchIdx < matches.length && matches[matchIdx].$1 < i) {
        matchIdx++;
      }
      if (matchIdx < matches.length && matches[matchIdx].$1 == i) {
        final (start, end, replacement) = matches[matchIdx];
        result.add(replacement);
        lastEnd = end;
        matchIdx++;
      } else {
        result.add(tokens[i]);
      }
    }

    return result.join(' ');
  }

  void _buildFailureLinks() {
    final queue = <int>[];
    for (final childId in _children[0].values) {
      _failure[childId] = 0;
      _dictionary[childId] = 0;
      queue.add(childId);
    }

    var head = 0;
    while (head < queue.length) {
      final current = queue[head++];
      for (final entry in _children[current].entries) {
        final token = entry.key;
        final childId = entry.value;

        var fail = _failure[current];
        while (fail != 0 && !_children[fail].containsKey(token)) {
          fail = _failure[fail];
        }
        _failure[childId] = _children[fail][token] ?? 0;
        if (_failure[childId] == childId) _failure[childId] = 0;

        _dictionary[childId] = _output[_failure[childId]] != null
            ? _failure[childId]
            : _dictionary[_failure[childId]];
        queue.add(childId);
      }
    }
  }
}
