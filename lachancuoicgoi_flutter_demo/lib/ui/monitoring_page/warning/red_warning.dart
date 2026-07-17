import 'package:flutter/material.dart';

import 'full_screen_warning.dart';

/// Full-screen red warning dialog for dangerous calls.
class RedWarning extends StatelessWidget {
  const RedWarning({super.key, required this.title, required this.onDismiss});

  final String title;
  final VoidCallback onDismiss;

  @override
  Widget build(BuildContext context) {
    return FullScreenWarning(
      color: Colors.red,
      icon: Icons.warning,
      titleText: 'NGUY HIỂM',
      subtitle: title,
      buttonColor: Colors.red,
      onDismiss: onDismiss,
      isUrgent:
          true, // Heavy haptic feedback — break psychological manipulation
    );
  }
}
