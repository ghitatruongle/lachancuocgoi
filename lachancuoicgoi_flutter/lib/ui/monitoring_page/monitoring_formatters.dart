import '../../analysis/analysis_mode.dart';

String modeLabel(AnalysisMode mode) {
  return switch (mode) {
    AnalysisMode.normal => 'L1',
    AnalysisMode.gDetection => 'L2',
    AnalysisMode.geminiApi => 'L3',
    AnalysisMode.parallel => 'Parallel',
  };
}

String formatSessionDateTime() {
  final now = DateTime.now();
  return formatDateTime(now);
}

String formatDateTime(DateTime value) {
  String two(int n) => n.toString().padLeft(2, '0');
  return '${two(value.hour)}:${two(value.minute)}:${two(value.second)} '
      '${two(value.day)}/${two(value.month)}/${value.year}';
}

String formatElapsedTime(int seconds) {
  final m = seconds ~/ 60;
  final s = seconds % 60;
  return '${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
}
