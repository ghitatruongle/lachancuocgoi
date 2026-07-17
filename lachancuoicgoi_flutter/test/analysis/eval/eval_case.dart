import 'dart:convert';

import 'package:lachancuocgoi_flutter/core/risk_level.dart';

enum EvalExpectation {
  green,
  yellow,
  orange,
  red,
  yellowOrGreen,
  orangeOrRed;

  static EvalExpectation parse(String value) {
    return switch (value.trim().toUpperCase()) {
      'GREEN' => EvalExpectation.green,
      'YELLOW' => EvalExpectation.yellow,
      'ORANGE' => EvalExpectation.orange,
      'RED' => EvalExpectation.red,
      'YELLOW_OR_GREEN' => EvalExpectation.yellowOrGreen,
      'ORANGE_OR_RED' => EvalExpectation.orangeOrRed,
      _ => throw FormatException('Unknown eval expectation: $value'),
    };
  }

  bool get isBinaryRisky {
    return switch (this) {
      EvalExpectation.orange ||
      EvalExpectation.red ||
      EvalExpectation.orangeOrRed => true,
      EvalExpectation.green ||
      EvalExpectation.yellow ||
      EvalExpectation.yellowOrGreen => false,
    };
  }

  bool accepts(RiskLevel predicted) {
    return switch (this) {
      EvalExpectation.green => predicted == RiskLevel.green,
      EvalExpectation.yellow => predicted.index <= RiskLevel.yellow.index,
      EvalExpectation.orange => predicted.index >= RiskLevel.orange.index,
      EvalExpectation.red => predicted == RiskLevel.red,
      EvalExpectation.yellowOrGreen =>
        predicted.index <= RiskLevel.yellow.index,
      EvalExpectation.orangeOrRed =>
        predicted.index >= RiskLevel.orange.index,
    };
  }

  RiskLevel get canonicalRiskLevel {
    return switch (this) {
      EvalExpectation.green => RiskLevel.green,
      EvalExpectation.yellow => RiskLevel.yellow,
      EvalExpectation.orange => RiskLevel.orange,
      EvalExpectation.red => RiskLevel.red,
      EvalExpectation.yellowOrGreen => RiskLevel.green,
      EvalExpectation.orangeOrRed => RiskLevel.orange,
    };
  }
}

class EvalCase {
  const EvalCase({
    required this.id,
    required this.text,
    required this.expected,
    required this.scenario,
    this.notes,
  });

  final String id;
  final String text;
  final EvalExpectation expected;
  final String scenario;
  final String? notes;

  factory EvalCase.fromJson(Map<String, Object?> json) {
    return EvalCase(
      id: json['id'] as String? ?? '',
      text: json['text'] as String? ?? '',
      expected: EvalExpectation.parse(json['expected'] as String? ?? ''),
      scenario: json['scenario'] as String? ?? 'unknown',
      notes: json['notes'] as String?,
    );
  }
}

List<EvalCase> parseEvalJsonl(String jsonl) {
  final cases = <EvalCase>[];
  final lines = const LineSplitter().convert(jsonl);
  for (var i = 0; i < lines.length; i++) {
    final line = lines[i].trim();
    if (line.isEmpty || line.startsWith('#')) continue;
    final decoded = jsonDecode(line);
    if (decoded is! Map) {
      throw FormatException('Line ${i + 1} is not a JSON object');
    }
    cases.add(EvalCase.fromJson(decoded.cast<String, Object?>()));
  }
  return cases;
}
