// Data classes for simulation scenarios, mirroring Kotlin SimulationScenarioData.

class SimulationScenarioData {
  const SimulationScenarioData({
    required this.title,
    required this.description,
    this.category = 'Chung',
    required this.riskLevel,
    this.script = const [],
    this.iconEmoji = '📞',
  });

  final String title;
  final String description;
  final String category;
  final String riskLevel;
  final List<SimulationScriptLine> script;
  final String iconEmoji;

  factory SimulationScenarioData.fromJson(Map<String, dynamic> json) {
    final rawScript =
        (json['script'] as List<dynamic>?)
            ?.map(
              (e) => SimulationScriptLine.fromJson(e as Map<String, dynamic>),
            )
            .toList() ??
        const <SimulationScriptLine>[];
    return SimulationScenarioData(
      title: json['title'] as String? ?? '',
      description: json['description'] as String? ?? '',
      category: json['category'] as String? ?? 'Chung',
      riskLevel: json['riskLevel'] as String? ?? 'GREEN',
      iconEmoji: json['iconEmoji'] as String? ?? '📞',
      script: _computeRelativeDelays(rawScript),
    );
  }

  /// Convert absolute timestamps to relative delays between lines.
  static List<SimulationScriptLine> _computeRelativeDelays(
    List<SimulationScriptLine> lines,
  ) {
    if (lines.length <= 1) return lines;
    final result = <SimulationScriptLine>[];
    for (var i = 0; i < lines.length; i++) {
      // Default gap when timestamps are equal/zero/inverted: 1500ms
      // (sits comfortably inside the [500, 10000] clamp window).
      const fallbackGap = 1500;
      final rawGap = i == 0 ? 0 : (lines[i].delay - lines[i - 1].delay).abs();
      final relativeDelay = rawGap <= 0 ? fallbackGap : rawGap;
      result.add(
        SimulationScriptLine(
          speaker: lines[i].speaker,
          line: lines[i].line,
          riskLevel: lines[i].riskLevel,
          delay: relativeDelay.clamp(500, 10000),
        ),
      );
    }
    return result;
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
      speaker: json['speaker'] as String? ?? '',
      line: json['line'] as String? ?? '',
      riskLevel: json['riskLevel'] as String?,
      delay:
          (json['timestamp'] as num?)?.toInt() ??
          (json['delay'] as num?)?.toInt() ??
          2000,
    );
  }
}

/// Normal mode only shows these scenario titles.
const normalModeTitles = [
  'Bạn bè hỏi thăm',
  'Dọa khóa SIM — Giả nhân viên viễn thông',
  'Giả danh Công an — Lệnh triệu tập',
  'Lừa đảo ngân hàng — Yêu cầu OTP',
];
