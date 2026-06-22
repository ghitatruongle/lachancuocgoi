import 'package:flutter/material.dart';

import '../../core/risk_level.dart';
import '../theme/app_theme.dart';
import '../theme/risk_level_colors.dart';

/// A card with a colored left accent bar whose color reflects a [RiskLevel].
///
/// Layout: `Card(clipBehavior.hardEdge) > IntrinsicHeight > Row[accentBar,
/// Expanded(Pad(Column))]`. Used by history item, result analysis summary and
/// simulation scenario cards (Sprint 5.2 — Pattern C).
class RiskAccentCard extends StatelessWidget {
  const RiskAccentCard({
    super.key,
    required this.level,
    required this.child,
    this.padding = const EdgeInsets.all(AppSpacing.sm),
  });

  /// Risk level that drives the accent-bar color (see [RiskLevel.color]).
  final RiskLevel level;

  final Widget child;

  /// Inner padding of the content column. Defaults to [AppSpacing.sm].
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
