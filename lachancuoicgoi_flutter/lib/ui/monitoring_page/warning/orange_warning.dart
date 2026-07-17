import 'package:flutter/material.dart';

import '../../../l10n/app_localizations.dart';
import 'full_screen_warning.dart';

/// Full-screen orange warning dialog for suspicious calls.
class OrangeWarning extends StatelessWidget {
  const OrangeWarning({
    super.key,
    required this.title,
    required this.onDismiss,
  });

  final String title;
  final VoidCallback onDismiss;

  static const _orangeColor = Color(0xFFFFA500);

  @override
  Widget build(BuildContext context) {
    // Phase 2 (P2-7): respect reduce-motion / accessibility setting.
    final reduceMotion = MediaQuery.disableAnimationsOf(context) ||
        MediaQuery.accessibleNavigationOf(context);
    return FullScreenWarning(
      color: _orangeColor,
      icon: Icons.info,
      titleText: AppLocalizations.of(context)!.warningOrangeTitle,
      subtitle: title,
      buttonColor: _orangeColor,
      onDismiss: onDismiss,
      reduceMotion: reduceMotion,
    );
  }
}
