import 'package:flutter/material.dart';

import '../../core/risk_level.dart';
import '../theme/app_theme.dart';
import '../theme/risk_level_colors.dart';

class RiskAccentCard extends StatelessWidget {
  const RiskAccentCard({
    super.key,
    required this.level,
    required this.child,
    this.padding = const EdgeInsets.all(AppSpacing.sm),
  });

  final RiskLevel level;

  final Widget child;

  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    return Card(
      clipBehavior: Clip.hardEdge,
      child: IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Container(width: 4, color: level.color),
            Expanded(
              child: Padding(padding: padding, child: child),
            ),
          ],
        ),
      ),
    );
  }
}
