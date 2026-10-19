/// Parallel L1+L2(+L3) scheduling helpers (v1.6.5 extract).
///
/// Runtime fusion still lives in [AnalysisCoordinator] / [AnalysisFusion].
/// This library documents timeout budgets used by the coordinator.
library;

/// Default L3 wall-clock budgets before adaptive calibration.
abstract final class ParallelL3Budgets {
  static const Duration normalMax = Duration(milliseconds: 1800);
  static const Duration elevatedMax = Duration(milliseconds: 800);
  static const Duration normalMin = Duration(milliseconds: 800);
  static const Duration elevatedMin = Duration(milliseconds: 500);
}
