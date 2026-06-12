import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Shared full-screen warning dialog used by both RedWarning and OrangeWarning.
///
/// When [isUrgent] is true (RED alert), the widget plays a repeating
/// heavy haptic feedback pattern every 600ms — this is the "Rung dồn dập"
/// described in the thesis, designed to break the victim's psychological
/// manipulation state by creating a strong, persistent physical interruption.
class FullScreenWarning extends StatefulWidget {
  const FullScreenWarning({
    super.key,
    required this.color,
    required this.icon,
    required this.titleText,
    required this.subtitle,
    required this.buttonColor,
    required this.onDismiss,
    this.isUrgent = false,
  });

  final Color color;
  final IconData icon;
  final String titleText;
  final String subtitle;
  final Color buttonColor;
  final VoidCallback onDismiss;

  /// When true, plays heavy haptic feedback in a loop to break the
  /// scammer's psychological hold on the victim (RED alert).
  final bool isUrgent;

  @override
  State<FullScreenWarning> createState() => _FullScreenWarningState();
}

class _FullScreenWarningState extends State<FullScreenWarning> {
  Timer? _hapticTimer;

  @override
  void initState() {
    super.initState();
    if (widget.isUrgent) {
      // Fire immediately, then repeat every 600ms while the warning is visible.
      _playHapticOnce();
      _hapticTimer = Timer.periodic(
        const Duration(milliseconds: 600),
        (_) => _playHapticOnce(),
      );
    }
  }

  void _playHapticOnce() {
    HapticFeedback.heavyImpact();
  }

  @override
  void dispose() {
    _hapticTimer?.cancel();
    _hapticTimer = null;
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Dialog.fullscreen(
      child: Stack(
        children: [
          Container(
            color: widget.color.withValues(alpha: 0.95),
            width: double.infinity,
            height: double.infinity,
            child: SingleChildScrollView(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const SizedBox(height: 100),
                  Icon(widget.icon, color: Colors.white, size: 80),
                  const SizedBox(height: 16),
                  Text(
                    widget.titleText,
                    style: Theme.of(context).textTheme.displaySmall?.copyWith(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                        ),
                  ),
                  const SizedBox(height: 16),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 32),
                    child: Text(
                      widget.subtitle,
                      style: Theme.of(context)
                          .textTheme
                          .headlineSmall
                          ?.copyWith(color: Colors.white),
                      textAlign: TextAlign.center,
                    ),
                  ),
                  const SizedBox(height: 32),
                  ElevatedButton(
                    onPressed: widget.onDismiss,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.white,
                      foregroundColor: widget.buttonColor,
                      padding: const EdgeInsets.symmetric(
                          horizontal: 32, vertical: 12),
                    ),
                    child: Text(
                      'ĐÃ HIỂU',
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                            fontWeight: FontWeight.bold,
                            color: widget.buttonColor,
                          ),
                    ),
                  ),
                  const SizedBox(height: 40),
                ],
              ),
            ),
          ),
          Positioned(
            top: MediaQuery.of(context).padding.top + 16,
            right: 16,
            child: GestureDetector(
              onTap: widget.onDismiss,
              child: Container(
                width: 64,
                height: 64,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.white.withValues(alpha: 0.4),
                ),
                child: const Icon(Icons.close, color: Colors.white, size: 36),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
