import 'package:flutter/material.dart';

import '../../core/risk_level.dart';

/// UI-layer adapter that materializes [RiskLevel]'s canonical palette
/// ([RiskLevel.colorValue], an ARGB int) into a Flutter [Color].
///
/// [RiskLevel] itself is kept Flutter-free (core/domain layer); this extension
/// is the single place that bridges the palette into the UI framework. Import
/// it anywhere a `Color` for a risk level is needed:
///
/// ```dart
/// import '../theme/risk_level_colors.dart';
/// final Color c = RiskLevel.red.color;
/// ```
///
/// The underlying int values remain the single source of truth for the
/// palette (Sprint 5.2a) — no color constants are duplicated here.
extension RiskLevelColorX on RiskLevel {
  /// Display color for this level.
  Color get color => Color(colorValue);
}
