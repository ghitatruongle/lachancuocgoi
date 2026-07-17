import 'package:flutter/material.dart';

import '../../core/risk_level.dart';
import '../../l10n/app_localizations.dart';
import '../theme/risk_level_colors.dart';

/// Animated risk level progress bar with color transitions.
class RiskLevelIndicator extends StatelessWidget {
  const RiskLevelIndicator({super.key, required this.riskLevel});

  final RiskLevel riskLevel;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    // Phase 2 (P2-7): respect the user's reduce-motion / accessibility setting.
    // When active, skip the color transition animation entirely.
    final reduceMotion = MediaQuery.disableAnimationsOf(context) ||
        MediaQuery.accessibleNavigationOf(context);
    final animDuration =
        reduceMotion ? Duration.zero : const Duration(milliseconds: 800);
    final targetProgress =
        riskLevel.index / (RiskLevel.values.length - 1).toDouble();

    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Expanded(
              child: Text(
                AppLocalizations.of(context)!.riskLevelLabel,
                style: tt.titleMedium?.copyWith(fontWeight: FontWeight.bold),
              ),
            ),
            const SizedBox(width: 8),
            Flexible(
              child: TweenAnimationBuilder<Color?>(
                tween: ColorTween(end: riskLevel.color),
                duration: animDuration,
                builder: (context, color, _) {
                  return Text(
                    riskLevel.vietnameseName,
                    style: tt.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: color,
                    ),
                  );
                },
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        TweenAnimationBuilder<Color?>(
          tween: ColorTween(end: riskLevel.color),
          duration: animDuration,
          builder: (context, color, _) {
            return LinearProgressIndicator(
              value: targetProgress,
              minHeight: 8,
              color: color,
              backgroundColor: cs.surfaceContainerHighest,
              borderRadius: BorderRadius.circular(4),
            );
          },
        ),
      ],
    );
  }
}
