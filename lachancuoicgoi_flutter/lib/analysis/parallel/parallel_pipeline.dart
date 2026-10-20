library;

abstract final class ParallelL3Budgets {
  static const Duration normalMax = Duration(milliseconds: 1800);
  static const Duration elevatedMax = Duration(milliseconds: 800);
  static const Duration normalMin = Duration(milliseconds: 800);
  static const Duration elevatedMin = Duration(milliseconds: 500);
}
