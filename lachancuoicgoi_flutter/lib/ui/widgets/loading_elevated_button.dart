import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';

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

  final ButtonStyle? style;

  final bool expanded;

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
