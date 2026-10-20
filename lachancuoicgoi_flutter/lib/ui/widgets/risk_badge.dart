import 'package:flutter/material.dart';

import '../../core/risk_level.dart';
import '../theme/risk_level_colors.dart';

class RiskBadge extends StatelessWidget {
  const RiskBadge({super.key, required this.level, this.fontSize});

  final RiskLevel level;

  final double? fontSize;

  @override
  Widget build(BuildContext context) {
    final color = level.color;
    return Semantics(
      label: 'Mức độ rủi ro: ${level.vietnameseName}',

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
