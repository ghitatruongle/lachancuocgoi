import 'dart:collection';

import 'package:lachancuocgoi_flutter/analysis/analysis_coordinator.dart';
import 'package:lachancuocgoi_flutter/analysis/analysis_mode.dart';
import 'package:lachancuocgoi_flutter/analysis/analysis_result.dart';
import 'package:lachancuocgoi_flutter/core/risk_level.dart';

import 'eval_case.dart';

class EvalRunner {
  const EvalRunner();

  Future<EvalReport> run({
    required List<EvalCase> cases,
    required AnalysisMode mode,
    required AnalysisCoordinator coordinator,
    bool resetBetweenCases = true,
  }) async {
    final rows = <EvalCaseResult>[];
    for (final evalCase in cases) {
      if (resetBetweenCases) {
        coordinator.resetMode(mode);
      }
      final result = await coordinator.analyze(evalCase.text, mode);
      rows.add(EvalCaseResult(evalCase: evalCase, result: result));
    }
    return EvalReport(rows);
  }
}

class EvalCaseResult {
  const EvalCaseResult({required this.evalCase, required this.result});

  final EvalCase evalCase;
  final AnalysisResult result;

  RiskLevel get predicted => result.overallRiskLevel;

  bool get accepted => evalCase.expected.accepts(predicted);
}

class EvalReport {
  EvalReport(this.rows);

  final List<EvalCaseResult> rows;

  int get tp => _count(binaryExpected: true, binaryPredicted: true);
  int get fp => _count(binaryExpected: false, binaryPredicted: true);
  int get fn => _count(binaryExpected: true, binaryPredicted: false);
  int get tn => _count(binaryExpected: false, binaryPredicted: false);

  int get falseRedOnGreen {
    return rows.where((row) {
      return row.evalCase.expected == EvalExpectation.green &&
          row.predicted == RiskLevel.red;
    }).length;
  }

  int get greenCaseCount => rows
      .where((row) => row.evalCase.expected == EvalExpectation.green)
      .length;

  double get falseRedRate => _safeDivide(falseRedOnGreen, greenCaseCount);

  int get criticalFalseGreen => rows.where((row) {
    return row.evalCase.isCritical && row.predicted == RiskLevel.green;
  }).length;

  int get acceptedCount => rows.where((row) => row.accepted).length;

  double get precision => _safeDivide(tp, tp + fp);
  double get recall => _safeDivide(tp, tp + fn);
  double get f1 {
    final denominator = precision + recall;
    if (denominator == 0) return 0;
    return 2 * precision * recall / denominator;
  }

  Map<RiskLevel, Map<RiskLevel, int>> get confusionMatrix {
    final matrix = <RiskLevel, Map<RiskLevel, int>>{
      for (final expected in RiskLevel.values)
        expected: <RiskLevel, int>{
          for (final predicted in RiskLevel.values) predicted: 0,
        },
    };
    for (final row in rows) {
      final expected = row.evalCase.expected.canonicalRiskLevel;
      final predicted = row.predicted;
      matrix[expected]![predicted] = matrix[expected]![predicted]! + 1;
    }
    return UnmodifiableMapView(matrix);
  }

  String toMarkdownTable() {
    final buffer = StringBuffer()
      ..writeln('| Metric | Value |')
      ..writeln('| --- | ---: |')
      ..writeln('| Cases | ${rows.length} |')
      ..writeln('| Accepted expectation | $acceptedCount |')
      ..writeln('| TP | $tp |')
      ..writeln('| FP | $fp |')
      ..writeln('| FN | $fn |')
      ..writeln('| TN | $tn |')
      ..writeln('| Precision | ${precision.toStringAsFixed(3)} |')
      ..writeln('| Recall | ${recall.toStringAsFixed(3)} |')
      ..writeln('| F1 | ${f1.toStringAsFixed(3)} |')
      ..writeln('| False RED on GREEN | $falseRedOnGreen |')
      ..writeln('| False RED rate | ${falseRedRate.toStringAsFixed(3)} |')
      ..writeln('| Critical false GREEN | $criticalFalseGreen |')
      ..writeln()
      ..writeln('| Expected \\ Predicted | GREEN | YELLOW | ORANGE | RED |')
      ..writeln('| --- | ---: | ---: | ---: | ---: |');

    final matrix = confusionMatrix;
    for (final expected in RiskLevel.values) {
      buffer.writeln(
        '| ${expected.storageName} | '
        '${matrix[expected]![RiskLevel.green]} | '
        '${matrix[expected]![RiskLevel.yellow]} | '
        '${matrix[expected]![RiskLevel.orange]} | '
        '${matrix[expected]![RiskLevel.red]} |',
      );
    }

    final failures = rows.where((row) => !row.accepted).toList();
    if (failures.isNotEmpty) {
      buffer
        ..writeln()
        ..writeln('| Failed case | Expected | Predicted | Reason |')
        ..writeln('| --- | --- | --- | --- |');
      for (final failure in failures) {
        buffer.writeln(
          '| ${failure.evalCase.id} | '
          '${failure.evalCase.expected.name} | '
          '${failure.predicted.storageName} | '
          '${(failure.result.reason ?? '').replaceAll('|', '/')} |',
        );
      }
    }
    return buffer.toString();
  }

  int _count({required bool binaryExpected, required bool binaryPredicted}) {
    return rows.where((row) {
      return row.evalCase.expected.isBinaryRisky == binaryExpected &&
          (row.predicted.index >= RiskLevel.orange.index) == binaryPredicted;
    }).length;
  }

  double _safeDivide(int numerator, int denominator) {
    if (denominator == 0) return 0;
    return numerator / denominator;
  }
}
