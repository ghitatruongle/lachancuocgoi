import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

/// A reusable content card: `Card > Padding > Column(crossAxisAlignment.start)`.
///
/// This is the single most repeated layout skeleton in the app (12+ call sites
/// before extraction — see Sprint 5.2). It standardises the inner padding
/// ([AppSpacing.sm]) and start-aligned column, and optionally renders a header
/// row with a [title] and a trailing widget (e.g. an action button).
///
/// Pass [child] for body-only cards, or [title]/[trailing] + [child] for cards
/// with a header.
class SectionCard extends StatelessWidget {
  const SectionCard({
    super.key,
    required this.child,
    this.title,
    this.trailing,
    this.padding = const EdgeInsets.all(AppSpacing.sm),
  });

  /// Body of the card. Required.
  final Widget child;

  /// Optional header title rendered above [child]. When `null`, no header row
  /// is rendered.
  final Widget? title;

  /// Optional widget placed at the end of the header row (e.g. an action).
  /// Ignored when [title] is `null`.
  final Widget? trailing;

  /// Inner padding around the column. Defaults to [AppSpacing.sm] on all sides.
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: padding,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (title != null) ...[
              Row(
                children: [
                  Expanded(child: title!),
                  if (trailing != null) trailing!,
                ],
              ),
              const SizedBox(height: AppSpacing.xs),
            ],
            child,
          ],
        ),
      ),
    );
  }
}
