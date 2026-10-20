import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../home_page/settings_dialog.dart';

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
