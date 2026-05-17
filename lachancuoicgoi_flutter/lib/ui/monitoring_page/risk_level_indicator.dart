import 'package:flutter/material.dart';

import '../../core/risk_level.dart';

/// Animated risk level progress bar with color transitions.
class RiskLevelIndicator extends StatelessWidget {
  const RiskLevelIndicator({super.key, required this.riskLevel});

  final RiskLevel riskLevel;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    final targetProgress =
        riskLevel.index / (RiskLevel.values.length - 1).toDouble();

    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Mức độ rủi ro',
              style:
                  tt.titleMedium?.copyWith(fontWeight: FontWeight.bold),
            ),
            TweenAnimationBuilder<Color?>(
              tween: ColorTween(end: riskLevel.color),
              duration: const Duration(milliseconds: 800),
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
          ],
        ),
        const SizedBox(height: 8),
        TweenAnimationBuilder<Color?>(
          tween: ColorTween(end: riskLevel.color),
          duration: const Duration(milliseconds: 800),
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
