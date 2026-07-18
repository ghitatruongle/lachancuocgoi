import 'dart:convert';
import 'dart:io';

void main(List<String> arguments) {
  final coveragePath = arguments.isEmpty ? 'coverage/lcov.info' : arguments[0];
  final baselinePath = arguments.length < 2
      ? 'tool/coverage_baseline.json'
      : arguments[1];
  final coverageFile = File(coveragePath);
  final baselineFile = File(baselinePath);
  if (!coverageFile.existsSync() || !baselineFile.existsSync()) {
    stderr.writeln('Coverage gate input is missing.');
    exitCode = 2;
    return;
  }

  var found = 0;
  var hit = 0;
  for (final line in coverageFile.readAsLinesSync()) {
    if (line.startsWith('LF:')) {
      found += int.parse(line.substring(3));
    } else if (line.startsWith('LH:')) {
      hit += int.parse(line.substring(3));
    }
  }
  final current = found == 0 ? 0.0 : hit * 100 / found;
  final baseline = jsonDecode(baselineFile.readAsStringSync());
  if (baseline is! Map<String, dynamic>) {
    stderr.writeln('Coverage baseline is invalid.');
    exitCode = 2;
    return;
  }
  final baselinePercent = (baseline['lineCoveragePercent'] as num).toDouble();
  final allowedDrop = (baseline['allowedDropPercentPoints'] as num).toDouble();
  final minimum = baselinePercent - allowedDrop;
  stdout.writeln(
    'Line coverage: ${current.toStringAsFixed(2)}% '
    '(baseline ${baselinePercent.toStringAsFixed(2)}%, '
    'minimum ${minimum.toStringAsFixed(2)}%).',
  );
  if (current + 0.0001 < minimum) {
    stderr.writeln('Coverage dropped by more than the allowed threshold.');
    exitCode = 2;
  }
}
