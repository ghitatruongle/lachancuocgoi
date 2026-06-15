enum NoiseMode {
  remove,
  space,
}

class TextNormalizer {
  TextNormalizer._();

  // ── Slang replacement via Aho-Corasick ──────────────────────────────
  static _SlangAutomaton? _slangAutomaton;

  // ── Number word normalization ──────────────────────────────────────────
  static const Map<String, int> _numberWordValues = {
    'khong': 0, 'mot': 1, 'hai': 2, 'ba': 3, 'bon': 4,
    'lam': 5, 'sau': 6, 'bay': 7, 'tam': 8, 'chin': 9,
    'muoi': 10,
    'tram': 100,
    'nghin': 1000, 'ngan': 1000,
    'trieu': 1000000, 'ti': 1000000000, 'ty': 1000000000,
  };

  static final RegExp _numberWordPattern = RegExp(
    r'\b(?:(?:mot|hai|ba|bon|lam|sau|bay|tam|chin|muoi|'
    r'tram|nghin|ngan|trieu|ti|ty|khong)\s*){2,8}\b',
    caseSensitive: false,
  );

  /// Converts Vietnamese number words to digits.
  /// E.g. "nam tram nghin" → "500000", "hai trieu" → "2000000".
  static String _normalizeNumberWords(String text) {
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

  // ── ASR (speech-to-text) common error patterns ────────────────────────
  /// Common ASR (speech-to-text) word confusions in Vietnamese.
  /// Keys are the misrecognized form (with diacritics — normalized at use).
  /// Values are the corrected form (also normalized at use).
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

  // ── Telex/VNI common typing error corrections ─────────────────────
  /// Common Telex typing errors: transposed diacritics, duplicated marks.
  /// Applied BEFORE normalization (on original text) so that corrected
  /// Vietnamese words (e.g. "chuyeene"→"chuyển") flow through the full
  /// normalization pipeline correctly.
  static const List<MapEntry<String, String>> _telexCorrectionsRaw = [
    // Common transposed compound words (5+ chars, high specificity).
    // NOTE: Generic vowel cluster rules (iee→iê, uoo→uô, etc.) were removed
    // because they match inside correctly-formed Vietnamese words (e.g.
    // "chuyển" contains "iee"), corrupting them.
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

  /// Lazily built normalized ASR corrections (keys+values run through
  /// phonetic + noise stripping so they match the already-normalized text).
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

  /// Lightweight phonetic strip (lowercase + diacritics removal only).
  /// Mirrors the first 3 steps of normalize() but without slang/numbers.
  static String _phoneticStrip(String text) {
    var result = text.toLowerCase();
    result = _mapPhoneticCharacters(result);
    result = result.replaceAll(_combiningMarks, '');
    result = result.replaceAll(_noiseChars, ' ');
    return result.trim().replaceAll(RegExp(r'\s+'), ' ');
  }

  /// Applies common ASR error corrections using word-boundary matching.
  static String _correctAsrErrors(String text) {
    var result = text;
    for (final entry in _asrCorrections.entries) {
      if (result.contains(entry.key)) {
        result = result.replaceAll(entry.key, entry.value);
      }
    }
    return result;
  }

  /// Applies common Telex/VNI typing error corrections.
  /// Uses substring matching (same approach as ASR corrections).
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
    // Build Aho-Corasick automaton for O(n+m) multi-pattern slang replacement.
    // Replaces the old O(n*m) sequential loop over _slangEntries.
    _slangAutomaton = entries.isEmpty
        ? null
        : _SlangAutomaton.build(entries);
  }

  static String normalize(
    String text, {
    bool applySlang = true,
    NoiseMode noiseMode = NoiseMode.remove,
  }) {
    // Phase 0: Telex/VNI typing error correction on ORIGINAL text
    // (before normalization strips diacritics). This fixes transposed
    // characters like "chuyeene"→"chuyển", "tienf"→"tiền" so that
    // subsequent normalization produces correct token forms.
    var result = _correctTelexErrors(text);

    result = result.toLowerCase();

    result = _mapPhoneticCharacters(result);
    result = result.replaceAll(_combiningMarks, '');

    result = switch (noiseMode) {
      NoiseMode.remove => result.replaceAll(_noiseChars, ''),
      NoiseMode.space => result.replaceAll(_noiseChars, ' '),
    };

    result = result.trim().replaceAll(RegExp(r'\s+'), ' ');

    // Phase 3: ASR error correction (before slang, so corrected words
    // can still be processed by slang replacement).
    result = _correctAsrErrors(result);

    if (applySlang && _slangAutomaton != null) {
      result = _slangAutomaton!.replaceAll(result);
    }

    // Phase 3: Number word normalization (after slang so "k"→"nghin" etc.
    // are already resolved). Converts "nam tram nghin" → "500000".
    result = _normalizeNumberWords(result);

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

// ═══════════════════════════════════════════════════════════════════════════
// Slang Aho-Corasick Automaton
// ═══════════════════════════════════════════════════════════════════════════

/// Aho-Corasick automaton for O(n+m) multi-pattern slang replacement.
///
/// Built once from slang entries (via [loadSlangConfig]), then reused for
/// every [normalize] call. Finds all non-overlapping matches in a single
/// pass over whitespace-delimited tokens, then applies replacements
/// atomically from end-to-start to avoid position shifting.
///
/// Semantics match the old `' $text '.replaceAll(' $key ', ' $value ')` loop:
/// each slang key is matched at word boundaries (token-level).
class _SlangAutomaton {
  _SlangAutomaton._();

  // Flat trie arrays — each node is an int index.
  final List<Map<String, int>> _children = [{}];
  final List<int> _failure = [0];
  final List<int> _dictionary = [0];
  final List<String?> _output = [null];   // replacement value
  final List<int> _depth = [0];           // pattern token count at this node
  int _size = 1;

  /// Build automaton from pre-sorted (longest-first) slang entries.
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

  /// Find all non-overlapping matches and replace atomically.
  ///
  /// Algorithm:
  /// 1. Tokenize text by whitespace.
  /// 2. Walk the Aho-Corasick automaton token-by-token.
  /// 3. Collect all matches with (startTokenIdx, endTokenIdx, replacement).
  /// 4. Sort by position, greedily select non-overlapping (earliest + longest).
  /// 5. Reconstruct text from tokens, substituting matched spans.
  String replaceAll(String text) {
    if (text.isEmpty) return text;
    final tokens = text.split(' ').where((t) => t.isNotEmpty).toList();
    if (tokens.isEmpty) return text;

    final matches = <(int, int, String)>[]; // (startIdx, endIdx, replacement)
    var state = 0;

    for (var i = 0; i < tokens.length; i++) {
      final token = tokens[i];
      while (state != 0 && !_children[state].containsKey(token)) {
        state = _failure[state];
      }
      state = _children[state][token] ?? 0;

      // Collect output via dictionary chain (longest match first).
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

    // Sort by start position, then by length descending (prefer longest).
    matches.sort((a, b) {
      final cmp = a.$1.compareTo(b.$1);
      if (cmp != 0) return cmp;
      return (b.$2 - b.$1).compareTo(a.$2 - a.$1);
    });

    // Greedily select non-overlapping matches.
    final result = <String>[];
    var lastEnd = -1;
    var matchIdx = 0;

    for (var i = 0; i < tokens.length; i++) {
      // Skip past the last consumed match end.
      if (i <= lastEnd) continue;

      // Find next match starting at or after i.
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
