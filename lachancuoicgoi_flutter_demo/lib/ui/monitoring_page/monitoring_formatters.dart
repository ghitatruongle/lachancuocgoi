import '../../analysis/analysis_mode.dart';

// ─── Monitoring Formatters ──────────────────────────────────────────────
//
// Pure formatting utilities extracted from [MonitoringController] to
// reduce class size and enable independent testing.

/// Returns a short label for the given [AnalysisMode].
String modeLabel(AnalysisMode mode) {
  return switch (mode) {
    AnalysisMode.normal => 'L1',
    AnalysisMode.gDetection => 'L2',
    AnalysisMode.geminiApi => 'L3',
    AnalysisMode.parallel => 'Parallel',
  };
}

/// Formats the current wall-clock time as "HH:mm:ss DD/MM/YYYY".
String formatSessionDateTime() {
  final now = DateTime.now();
  return formatDateTime(now);
}

/// Formats a [DateTime] as "HH:mm:ss DD/MM/YYYY".
String formatDateTime(DateTime value) {
  String two(int n) => n.toString().padLeft(2, '0');
  return '${two(value.hour)}:${two(value.minute)}:${two(value.second)} '
      '${two(value.day)}/${two(value.month)}/${value.year}';
}

/// Formats elapsed [seconds] as "MM:SS".
String formatElapsedTime(int seconds) {
  final m = seconds ~/ 60;
  final s = seconds % 60;
  return '${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
}
