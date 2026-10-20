import 'package:flutter/material.dart';

import '../../../l10n/app_localizations.dart';
import 'full_screen_warning.dart';

class RedWarning extends StatelessWidget {
  const RedWarning({super.key, required this.title, required this.onDismiss});

  final String title;
  final VoidCallback onDismiss;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    final reduceMotion =
        MediaQuery.disableAnimationsOf(context) ||
        MediaQuery.accessibleNavigationOf(context);
    return FullScreenWarning(
      color: Colors.red,
      icon: Icons.warning,
      titleText: l10n.warningRedTitle,
      subtitle: title,
      buttonColor: Colors.red,
      onDismiss: onDismiss,
      isUrgent: true,
      reduceMotion: reduceMotion,
    );
  }
}
