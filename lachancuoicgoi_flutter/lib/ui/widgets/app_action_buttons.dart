import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../home_page/settings_dialog.dart';

/// AppBar action that opens the [SettingsDialog]. Replaces 3 duplicated copies
/// (Sprint 5.2 — Pattern D).
class SettingsActionButton extends StatelessWidget {
  const SettingsActionButton({super.key});

  @override
  Widget build(BuildContext context) {
    return IconButton(
      tooltip: 'Cài đặt',
      icon: const Icon(Icons.settings),
      onPressed: () => showDialog<void>(
        context: context,
        builder: (_) => const SettingsDialog(),
      ),
    );
  }
}

/// AppBar leading button that navigates to the home route (`/`).
///
/// Preserves the existing `context.go('/')` behavior used across the app's
/// back buttons (Sprint 5.2 — Pattern E). Keeps a localized tooltip for screen
/// readers.
class HomeBackButton extends StatelessWidget {
  const HomeBackButton({super.key});

  @override
  Widget build(BuildContext context) {
    return IconButton(
      tooltip: 'Về trang chính',
      icon: const Icon(Icons.arrow_back),
      onPressed: () => context.go('/'),
    );
  }
}
