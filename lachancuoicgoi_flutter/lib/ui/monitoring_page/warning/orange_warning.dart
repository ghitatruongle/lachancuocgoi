import 'package:flutter/material.dart';

import 'full_screen_warning.dart';

/// Full-screen orange warning dialog for suspicious calls.
class OrangeWarning extends StatelessWidget {
  const OrangeWarning({super.key, required this.title, required this.onDismiss});

  final String title;
  final VoidCallback onDismiss;

  static const _orangeColor = Color(0xFFFFA500);

  @override
  Widget build(BuildContext context) {
    return FullScreenWarning(
      color: _orangeColor,
      icon: Icons.info,
      titleText: 'NGUY CƠ',
      subtitle: title,
      buttonColor: _orangeColor,
      onDismiss: onDismiss,
    );
  }
}
