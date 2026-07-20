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
      EvalExpectation.orangeOrRed => predicted.index >= RiskLevel.orange.index,
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
    this.group = 'unknown',
    this.isCritical = false,
  });

  final String id;
  final String text;
  final EvalExpectation expected;
  final String scenario;
  final String? notes;
  final String group;
  final bool isCritical;

  factory EvalCase.fromJson(Map<String, Object?> json) {
    return EvalCase(
      id: json['id'] as String? ?? '',
      text: json['text'] as String? ?? '',
      expected: EvalExpectation.parse(json['expected'] as String? ?? ''),
      scenario: json['scenario'] as String? ?? 'unknown',
      notes: json['notes'] as String?,
      group: json['group'] as String? ?? 'unknown',
      isCritical: json['isCritical'] as bool? ?? false,
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

/// Expands a compact, reviewed template corpus into the concrete cases used
/// by the regression gate. This keeps 300 cases maintainable while ensuring
/// every generated transcript has a stable ID and category.
List<EvalCase> parseEvalTemplateCorpus(String rawJson) {
  final decoded = jsonDecode(rawJson);
  if (decoded is! Map<String, dynamic>) {
    throw const FormatException('Template corpus root must be a JSON object');
  }

  final cases = <EvalCase>[];
  for (final groupEntry in decoded.entries) {
    final group = groupEntry.key;
    final groupValue = groupEntry.value;
    if (groupValue is! Map<String, dynamic>) {
      throw FormatException('Corpus group $group must be a JSON object');
    }
    final expected = EvalExpectation.parse(
      groupValue['expected'] as String? ?? '',
    );
    final variants = (groupValue['variants'] as List<dynamic>? ?? const [])
        .cast<String>();
    final templates = (groupValue['templates'] as List<dynamic>? ?? const [])
        .cast<Map<String, dynamic>>();
    if (variants.isEmpty || templates.isEmpty) {
      throw FormatException('Corpus group $group cannot be empty');
    }

    for (final template in templates) {
      final templateId = template['id'] as String? ?? '';
      final templateText = template['text'] as String? ?? '';
      final scenario = template['scenario'] as String? ?? group;
      final isCritical = template['isCritical'] as bool? ?? false;
      for (var index = 0; index < variants.length; index++) {
        final variant = variants[index];
        cases.add(
          EvalCase(
            id: '${group}_${templateId}_${index + 1}',
            text: templateText.replaceAll('{variant}', variant).trim(),
            expected: expected,
            scenario: scenario,
            group: group,
            isCritical: isCritical,
          ),
        );
      }
    }
  }
  return cases;
}
