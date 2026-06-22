import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';

/// A full-width primary [ElevatedButton] that swaps its icon for a spinner when
/// loading and disables itself.
///
/// Replaces the repeated `ElevatedButton.icon(... _isRequesting ? spinner :
/// icon ...)` pattern in rights dialog, onboarding and monitoring pages
/// (Sprint 5.2 — Pattern K).
///
/// By default the button is full-width with [icon] on the leading edge. For
/// inline layouts (e.g. a footer row), set [expanded] to `false` so it sizes to
/// its content. Pass [style] to override colors/shape/padding (used by callers
/// that need a colored primary or fixed-height button), and [spinnerSize] to
/// match the surrounding icon size.
///
/// Accessibility: when [isLoading] flips to `true`, "Đang xử lý…" is announced
/// via [SemanticsService.sendAnnouncement] so screen-reader users know the
/// action was accepted and is running (the button also disables itself, which
/// TalkBack / VoiceOver otherwise wouldn't narrate on its own).
class LoadingElevatedButton extends StatefulWidget {
  const LoadingElevatedButton({
    super.key,
    required this.isLoading,
    required this.icon,
    required this.label,
    required this.onPressed,
    this.style,
    this.expanded = true,
    this.spinnerSize = 16,
  });

  final bool isLoading;
  final IconData icon;
  final String label;
  final VoidCallback? onPressed;

  /// Optional [ElevatedButton] style override (colors, shape, padding, …).
  final ButtonStyle? style;

  /// When `true` (default) the button stretches to full width via a wrapping
  /// [SizedBox]. When `false` it hugs its content — useful inside a `Row`.
  final bool expanded;

  /// Diameter of the loading spinner. Defaults to `16` to match the default
  /// icon size; callers using a larger icon may bump this up.
  final double spinnerSize;

  @override
  State<LoadingElevatedButton> createState() => _LoadingElevatedButtonState();
}

class _LoadingElevatedButtonState extends State<LoadingElevatedButton> {
  @override
  void didUpdateWidget(covariant LoadingElevatedButton oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!oldWidget.isLoading && widget.isLoading) {
      SemanticsService.sendAnnouncement(
        View.of(context),
        'Đang xử lý…',
        TextDirection.ltr,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final button = ElevatedButton.icon(
      onPressed: widget.isLoading ? null : widget.onPressed,
      style: widget.style,
      icon: widget.isLoading
          ? SizedBox(
              width: widget.spinnerSize,
              height: widget.spinnerSize,
              child: const CircularProgressIndicator(strokeWidth: 2),
            )
          : Icon(widget.icon),
      label: Text(widget.label),
    );
    return widget.expanded
        ? SizedBox(width: double.infinity, child: button)
        : button;
  }
}
