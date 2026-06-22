import 'package:flutter/material.dart';

import '../../core/risk_level.dart';
import '../theme/risk_level_colors.dart';

/// Pill-shaped badge displaying a risk-level label in the level's color.
///
/// Renders as a rounded (`circular(50)`) container with a 10% tint of the risk
/// color and the level's Vietnamese name in the full risk color, bold.
/// Used by history item card and result page (Sprint 5.2 — Pattern B).
class RiskBadge extends StatelessWidget {
  const RiskBadge({super.key, required this.level, this.fontSize});

  final RiskLevel level;

  /// Optional override for the label font size.
  final double? fontSize;

  @override
  Widget build(BuildContext context) {
    final color = level.color;
    return Semantics(
      label: 'Mức độ rủi ro: ${level.vietnameseName}',
      // The visible label (e.g. "Nguy hiểm") is already readable; merge so the
      // combined node is announced once instead of "Nguy hiểm, Nguy hiểm".
      container: true,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(50),
        ),
        child: Text(
          level.vietnameseName,
          style: TextStyle(
            color: color,
            fontWeight: FontWeight.bold,
            fontSize: fontSize,
          ),
        ),
      ),
    );
  }
}
