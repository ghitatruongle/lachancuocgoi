import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

class InfoLine extends StatelessWidget {
  const InfoLine({
    super.key,
    required this.icon,
    required this.text,
    this.color,
    this.iconSize = 16,
    this.gap = AppSpacing.xs,
  });

  final IconData icon;
  final String text;

  final Color? color;

  final double iconSize;
  final double gap;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final c = color ?? cs.onSurfaceVariant;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: iconSize, color: c),
        SizedBox(width: gap),
        Expanded(
          child: Text(text, style: TextStyle(color: c)),
        ),
      ],
    );
  }
}
