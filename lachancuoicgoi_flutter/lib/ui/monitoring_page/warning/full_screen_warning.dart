import 'package:flutter/material.dart';

/// Shared full-screen warning dialog used by both RedWarning and OrangeWarning.
class FullScreenWarning extends StatelessWidget {
  const FullScreenWarning({
    super.key,
    required this.color,
    required this.icon,
    required this.titleText,
    required this.subtitle,
    required this.buttonColor,
    required this.onDismiss,
  });

  final Color color;
  final IconData icon;
  final String titleText;
  final String subtitle;
  final Color buttonColor;
  final VoidCallback onDismiss;

  @override
  Widget build(BuildContext context) {
    return Dialog.fullscreen(
      child: Stack(
        children: [
          Container(
            color: color.withValues(alpha: 0.95),
            width: double.infinity,
            height: double.infinity,
            child: SingleChildScrollView(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const SizedBox(height: 100),
                  Icon(icon, color: Colors.white, size: 80),
                  const SizedBox(height: 16),
                  Text(
                    titleText,
                    style: Theme.of(context).textTheme.displaySmall?.copyWith(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                        ),
                  ),
                  const SizedBox(height: 16),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 32),
                    child: Text(
                      subtitle,
                      style: Theme.of(context)
                          .textTheme
                          .headlineSmall
                          ?.copyWith(color: Colors.white),
                      textAlign: TextAlign.center,
                    ),
                  ),
                  const SizedBox(height: 32),
                  ElevatedButton(
                    onPressed: onDismiss,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.white,
                      foregroundColor: buttonColor,
                      padding: const EdgeInsets.symmetric(
                          horizontal: 32, vertical: 12),
                    ),
                    child: Text(
                      'ĐÃ HIỂU',
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                            fontWeight: FontWeight.bold,
                            color: buttonColor,
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
              onTap: onDismiss,
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
