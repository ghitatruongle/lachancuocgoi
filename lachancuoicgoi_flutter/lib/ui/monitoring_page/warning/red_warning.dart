import 'package:flutter/material.dart';

import '../../../l10n/app_localizations.dart';
import 'full_screen_warning.dart';

/// Full-screen red warning dialog for dangerous calls.
class RedWarning extends StatelessWidget {
  const RedWarning({super.key, required this.title, required this.onDismiss});

  final String title;
  final VoidCallback onDismiss;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    // Phase 2 (P2-7): respect reduce-motion / accessibility setting.
    final reduceMotion = MediaQuery.disableAnimationsOf(context) ||
        MediaQuery.accessibleNavigationOf(context);
    return FullScreenWarning(
      color: Colors.red,
      icon: Icons.warning,
      titleText: l10n.warningRedTitle,
      subtitle: title,
      buttonColor: Colors.red,
      onDismiss: onDismiss,
      isUrgent:
          true, // Heavy haptic feedback — break psychological manipulation
      reduceMotion: reduceMotion,
    );
  }
}
