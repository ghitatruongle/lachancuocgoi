import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../analysis/analysis_mode.dart';
import '../../app/settings_controller.dart';
import '../theme/app_theme.dart';

class SettingsDialog extends ConsumerWidget {
  const SettingsDialog({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(settingsControllerProvider);
    final controller = ref.read(settingsControllerProvider.notifier);
    final tt = Theme.of(context).textTheme;

    return Dialog(
      insetPadding: const EdgeInsets.all(AppSpacing.sm),
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.sm),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // ── Header ──
            Row(
              children: [
                Expanded(
                  child: Text('Cài đặt', style: tt.headlineSmall),
                ),
                IconButton(
                  onPressed: () => Navigator.of(context).pop(),
                  icon: const Icon(Icons.close),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.xxs),

            // ── Content ──
            Flexible(
              child: SingleChildScrollView(
                child: Column(
                  children: [
                    const SizedBox(height: AppSpacing.sm),

                    // Theme toggle
                    _SettingToggleCard(
                      icon: settings.isDarkTheme
                          ? Icons.dark_mode
                          : Icons.light_mode,
                      title: settings.isDarkTheme
                          ? 'Giao diện tối'
                          : 'Giao diện sáng',
                      description: settings.isDarkTheme
                          ? 'Tắt để chuyển sang giao diện sáng.'
                          : 'Bật để chuyển sang giao diện tối.',
                      checked: settings.isDarkTheme,
                      onChanged: (v) => controller.update(
                        settings.copyWith(isDarkTheme: v),
                      ),
                    ),

                    const SizedBox(height: AppSpacing.sm),

                    // Analysis mode
                    _AnalysisModeCard(
                      selectedMode: settings.analysisMode,
                      onModeSelected: (mode) => controller.update(
                        settings.copyWith(analysisMode: mode),
                      ),
                    ),

                    const SizedBox(height: AppSpacing.sm),

                    // Audio boost
                    _SettingToggleCard(
                      icon: Icons.graphic_eq,
                      title: 'Khuếch đại âm thanh',
                      description:
                          'Tự động tăng âm lượng cuộc gọi để cải thiện độ chính xác.',
                      checked: settings.audioBoost,
                      onChanged: (v) => controller.update(
                        settings.copyWith(audioBoost: v),
                      ),
                    ),

                    const SizedBox(height: AppSpacing.sm),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Toggle Card ───────────────────────────────────────────────────────
class _SettingToggleCard extends StatelessWidget {
  const _SettingToggleCard({
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
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Card(
      color: cs.surfaceContainerHighest,
      child: SizedBox(
        height: 120,
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.sm),
          child: Stack(
            children: [
              Align(
                alignment: Alignment.topLeft,
                child: Icon(icon),
              ),
              Align(
                alignment: Alignment.bottomLeft,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title,
                        style: const TextStyle(fontWeight: FontWeight.w500)),
                    Text(
                      description,
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ],
                ),
              ),
              Align(
                alignment: Alignment.bottomRight,
                child: Switch(value: checked, onChanged: onChanged),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─── Analysis Mode Card ────────────────────────────────────────────────
class _AnalysisModeCard extends StatelessWidget {
  const _AnalysisModeCard({
    required this.selectedMode,
    required this.onModeSelected,
  });

  final AnalysisMode selectedMode;
  final ValueChanged<AnalysisMode> onModeSelected;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Card(
      color: cs.surfaceContainerHighest,
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.sm),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Chế độ phân tích',
              style: Theme.of(context)
                  .textTheme
                  .titleSmall
                  ?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: AppSpacing.xxs),
            for (final mode in AnalysisMode.values) ...[
              ListTile(
                title: Text(mode.title),
                subtitle: Text(mode.description),
                leading: Icon(
                  mode == selectedMode
                      ? Icons.radio_button_checked
                      : Icons.radio_button_unchecked,
                  color: mode == selectedMode
                      ? Theme.of(context).colorScheme.primary
                      : null,
                ),
                dense: true,
                contentPadding: EdgeInsets.zero,
                onTap: () => onModeSelected(mode),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
