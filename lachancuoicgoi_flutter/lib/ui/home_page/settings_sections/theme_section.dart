import 'package:flutter/material.dart';

import '../../../app/settings_controller.dart';
import '../../theme/app_theme.dart';

/// Theme settings: "follow system" toggle + manual dark/light mode toggle.
class ThemeSection extends StatelessWidget {
  const ThemeSection({super.key, required this.state, required this.onChanged});

  final SettingsState state;
  final ValueChanged<SettingsState> onChanged;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        _SettingToggleCard(
          icon: Icons.brightness_auto,
          title: 'Theo hệ thống',
          description: 'Tự động sáng/tối theo cài đặt giao diện thiết bị.',
          checked: state.followSystemTheme,
          onChanged: (v) => onChanged(state.copyWith(followSystemTheme: v)),
        ),
        const SizedBox(height: AppSpacing.sm),
        _SettingToggleCard(
          icon: state.isDarkTheme ? Icons.dark_mode : Icons.light_mode,
          title: state.isDarkTheme ? 'Giao diện tối' : 'Giao diện sáng',
          description: state.followSystemTheme
              ? 'Tắt "Theo hệ thống" để dùng tùy chọn này.'
              : (state.isDarkTheme
                    ? 'Tắt để chuyển sang giao diện sáng.'
                    : 'Bật để chuyển sang giao diện tối.'),
          checked: state.isDarkTheme,
          onChanged: state.followSystemTheme
              ? null
              : (v) => onChanged(state.copyWith(isDarkTheme: v)),
        ),
      ],
    );
  }
}

/// Toggle card widget shared across settings sections.
class SettingToggleCard extends StatelessWidget {
  const SettingToggleCard({
    super.key,
    required this.icon,
    required this.title,
    required this.description,
    required this.checked,
    required this.onChanged,
  });

  final IconData icon;
  final String title;
  final String description;
  final bool checked;
  final ValueChanged<bool>? onChanged;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;

    return Card(
      color: cs.surfaceContainerHighest,
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.sm),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, color: cs.primary),
            const SizedBox(width: AppSpacing.sm),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    title,
                    style: const TextStyle(fontWeight: FontWeight.w500),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    description,
                    style: tt.bodySmall?.copyWith(color: cs.onSurfaceVariant),
                  ),
                ],
              ),
            ),
            const SizedBox(width: AppSpacing.sm),
            Switch(value: checked, onChanged: onChanged),
          ],
        ),
      ),
    );
  }
}

class _SettingToggleCard extends SettingToggleCard {
  const _SettingToggleCard({
    required super.icon,
    required super.title,
    required super.description,
    required super.checked,
    required super.onChanged,
  });
}
