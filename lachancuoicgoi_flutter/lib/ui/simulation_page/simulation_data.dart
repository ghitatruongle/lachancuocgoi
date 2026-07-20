// Data classes for bundled simulation scenarios.

class SimulationScenarioData {
  const SimulationScenarioData({
    this.id = '',
    required this.title,
    required this.description,
    this.category = 'Chung',
    this.categoryCode,
    required this.riskLevel,
    this.script = const [],
    this.iconEmoji = '📞',
    this.isFeatured = false,
  });

  final String id;
  final String title;
  final String description;
  final String category;
  final String? categoryCode;
  final String riskLevel;
  final List<SimulationScriptLine> script;
  final String iconEmoji;

  /// Explicit catalog metadata supported by the v1.6 schema. Older bundled
  /// data has no flag, so the controller uses a deterministic fallback.
  final bool isFeatured;

  factory SimulationScenarioData.fromJson(Map<String, dynamic> json) {
    final expected = _stringKeyedMap(json['expected_result']);
    final categoryCode = _stringValue(
      expected?['category'] ?? json['categoryCode'],
    );
    final explicitCategory = _stringValue(json['category']);
    final rawScript = json['script'];
    final scriptMaps = rawScript is List
        ? rawScript
              .map(_stringKeyedMap)
              .whereType<Map<String, dynamic>>()
              .toList(growable: false)
        : const <Map<String, dynamic>>[];
    final timestampsAreAbsolute = scriptMaps.any(
      (entry) => entry.containsKey('timestamp'),
    );
    final parsedScript = scriptMaps
        .map(SimulationScriptLine.fromJson)
        .where((line) => line.line.trim().isNotEmpty)
        .toList(growable: false);

    final title = _stringValue(json['title']) ?? '';
    return SimulationScenarioData(
      id: _stringValue(json['id']) ?? title,
      title: title,
      description: _stringValue(json['description']) ?? '',
      category: explicitCategory?.isNotEmpty == true
          ? _categoryLabel(explicitCategory!)
          : _categoryLabel(categoryCode),
      categoryCode: categoryCode,
      riskLevel: _normalizeRiskLevel(
        _stringValue(expected?['risk_level'] ?? json['riskLevel']),
      ),
      iconEmoji: _stringValue(json['iconEmoji'] ?? json['icon']) ?? '📞',
      script: timestampsAreAbsolute
          ? _absoluteTimestampsToDelays(parsedScript)
          : parsedScript,
      isFeatured:
          json['isFeatured'] == true ||
          json['featured'] == true ||
          _stringValue(json['catalog'])?.toLowerCase() == 'featured' ||
          _stringValue(json['visibility'])?.toLowerCase() == 'public',
    );
  }

  static List<SimulationScriptLine> _absoluteTimestampsToDelays(
    List<SimulationScriptLine> lines,
  ) {
    if (lines.isEmpty) return const [];
    const fallbackGap = 1500;
    final result = <SimulationScriptLine>[];
    for (var index = 0; index < lines.length; index++) {
      final rawGap = index == 0
          ? lines[index].delay
          : lines[index].delay - lines[index - 1].delay;
      final delay = (rawGap <= 0 ? fallbackGap : rawGap)
          .clamp(500, 10000)
          .toInt();
      result.add(lines[index].copyWith(delay: delay));
    }
    return List.unmodifiable(result);
  }

  static Map<String, dynamic>? _stringKeyedMap(Object? value) {
    if (value is! Map) return null;
    return value.map((key, value) => MapEntry(key.toString(), value));
  }

  static String? _stringValue(Object? value) {
    if (value == null) return null;
    final text = value.toString().trim();
    return text.isEmpty ? null : text;
  }

  static String _normalizeRiskLevel(String? value) {
    return switch (value?.trim().toUpperCase()) {
      'RED' => 'RED',
      'ORANGE' => 'ORANGE',
      'YELLOW' => 'YELLOW',
      _ => 'GREEN',
    };
  }

  static String _categoryLabel(String? value) {
    final code = value?.trim().toUpperCase();
    if (code == null || code.isEmpty) return 'Chung';
    if (code == 'SAFE' || code == 'AN TOÀN') return 'An toàn';
    if (code.contains('BANK') ||
        code.contains('CREDIT') ||
        code.contains('INVESTMENT') ||
        code.contains('GAMBLING')) {
      return 'Tài chính';
    }
    if (code.contains('POLICE') ||
        code.contains('GOV') ||
        code.contains('TELECOM')) {
      return 'Mạo danh';
    }
    if (code.contains('JOB') ||
        code.contains('CEO') ||
        code.contains('VISA') ||
        code.contains('IMMIGRATION')) {
      return 'Việc làm';
    }
    if (code.contains('ROMANCE') ||
        code.contains('SOCIAL') ||
        code.contains('SEXTORTION')) {
      return 'Mạng xã hội';
    }
    // Preserve already human-readable category labels.
    if (!RegExp(r'^[A-Z0-9_]+$').hasMatch(code)) return value!.trim();
    return 'Lừa đảo';
  }
}

class SimulationScriptLine {
  const SimulationScriptLine({
    required this.speaker,
    required this.line,
    this.riskLevel,
    this.delay = 2000,
  });

  final String speaker;
  final String line;
  final String? riskLevel;
  final int delay;

  factory SimulationScriptLine.fromJson(Map<String, dynamic> json) {
    return SimulationScriptLine(
      speaker: json['speaker']?.toString().trim() ?? '',
      line: json['line']?.toString().trim() ?? '',
      riskLevel: json['riskLevel']?.toString().toUpperCase(),
      delay:
          (json['timestamp'] as num?)?.toInt() ??
          (json['delay'] as num?)?.toInt() ??
          2000,
    );
  }

  SimulationScriptLine copyWith({int? delay}) {
    return SimulationScriptLine(
      speaker: speaker,
      line: line,
      riskLevel: riskLevel,
      delay: delay ?? this.delay,
    );
  }
}

const int normalSimulationCatalogSize = 4;
