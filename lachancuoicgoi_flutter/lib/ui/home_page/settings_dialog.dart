import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../analysis/analysis_mode.dart';
import '../../app/settings_controller.dart';
import '../../services/developer_mode_manager.dart';
import '../theme/app_theme.dart';

class SettingsDialog extends ConsumerStatefulWidget {
  const SettingsDialog({super.key});

  @override
  ConsumerState<SettingsDialog> createState() => _SettingsDialogState();
}

class _SettingsDialogState extends ConsumerState<SettingsDialog> {
  @override
  Widget build(BuildContext context) {
    final settings = ref.watch(settingsControllerProvider);
    final controller = ref.read(settingsControllerProvider.notifier);
    final developerMode = ref.watch(developerModeProvider);
    final developerController = ref.read(developerModeProvider.notifier);
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
                  child: InkWell(
                    borderRadius: BorderRadius.circular(12),
                    onTap: () {
                      final result = developerController.onTitleTap();
                      if (result == DeveloperTapResult.showPassword) {
                        WidgetsBinding.instance.addPostFrameCallback((_) async {
                          final activated =
                              await showDialog<bool>(
                                context: context,
                                builder: (context) =>
                                    const _DevPasswordDialog(),
                              ) ??
                              false;
                          if (activated && mounted) {
                            await ref
                                .read(developerModeProvider.notifier)
                                .activate();
                          }
                        });
                      }
                    },
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 4),
                      child: Text(
                        developerMode.isActive
                            ? 'Cài đặt  ${developerMode.remainingSeconds}s'
                            : 'Cài đặt',
                        style: tt.headlineSmall,
                      ),
                    ),
                  ),
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
                      onChanged: (v) =>
                          controller.update(settings.copyWith(isDarkTheme: v)),
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
                      onChanged: (v) =>
                          controller.update(settings.copyWith(audioBoost: v)),
                    ),

                    const SizedBox(height: AppSpacing.sm),

                    _SettingToggleCard(
                      icon: Icons.speaker_phone,
                      title: 'Tự bật loa ngoài',
                      description:
                          'Bật loa ngoài khi bắt đầu giám sát để tăng khả năng thu tiếng.',
                      checked: settings.autoEnableSpeakerphone,
                      onChanged: (v) => controller.update(
                        settings.copyWith(autoEnableSpeakerphone: v),
                      ),
                    ),

                    if (developerMode.isActive) ...[
                      const SizedBox(height: AppSpacing.sm),
                      const Divider(),
                      const SizedBox(height: AppSpacing.xxs),
                      Align(
                        alignment: Alignment.centerLeft,
                        child: Text(
                          'Nhà sáng tạo',
                          style: tt.titleSmall?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      const SizedBox(height: AppSpacing.sm),
                      Card(
                        color: Theme.of(context).colorScheme.primaryContainer,
                        child: Padding(
                          padding: const EdgeInsets.all(AppSpacing.sm),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              SwitchListTile(
                                contentPadding: EdgeInsets.zero,
                                title: const Text('Chụp audio màn hình'),
                                subtitle: const Text(
                                  'Lấy audio VoIP trực tiếp từ hệ thống để phân tích. Chỉ hoạt động với Zalo/Telegram/WhatsApp.',
                                ),
                                value: settings.creatorAudioCapture,
                                onChanged: (v) => controller.update(
                                  settings.copyWith(creatorAudioCapture: v),
                                ),
                              ),
                              const SizedBox(height: AppSpacing.xxs),
                              Text(
                                'Yêu cầu đồng ý quyền ghi màn hình khi bắt đầu giám sát.',
                                style: tt.bodySmall?.copyWith(
                                  color: Theme.of(context).colorScheme.error,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],

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
            Switch(
              value: checked,
              onChanged: onChanged,
            ),
          ],
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
              style: Theme.of(
                context,
              ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold),
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

class _DevPasswordDialog extends ConsumerStatefulWidget {
  const _DevPasswordDialog();

  @override
  ConsumerState<_DevPasswordDialog> createState() => _DevPasswordDialogState();
}

class _DevPasswordDialogState extends ConsumerState<_DevPasswordDialog> {
  final _controller = TextEditingController();
  bool _showPassword = false;
  bool _hasError = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final developerController = ref.read(developerModeProvider.notifier);

    void attempt() {
      if (developerController.verifyPassword(_controller.text)) {
        Navigator.of(context).pop(true);
      } else {
        setState(() {
          _hasError = true;
          _controller.clear();
        });
      }
    }

    return AlertDialog(
      title: const Text('Chế độ Nhà phát triển'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text(
            'Nhập mật mã để kích hoạt chế độ Nhà phát triển (10 phút).',
          ),
          const SizedBox(height: AppSpacing.sm),
          TextField(
            controller: _controller,
            obscureText: !_showPassword,
            keyboardType: TextInputType.number,
            decoration: InputDecoration(
              labelText: 'Mật mã',
              errorText: _hasError
                  ? 'Mật mã không đúng. Vui lòng thử lại.'
                  : null,
              suffixIcon: IconButton(
                icon: Icon(
                  _showPassword ? Icons.visibility_off : Icons.visibility,
                ),
                onPressed: () {
                  setState(() => _showPassword = !_showPassword);
                },
              ),
            ),
            onChanged: (_) {
              setState(() {
                if (_hasError) {
                  _hasError = false;
                }
              });
            },
            onSubmitted: (_) => attempt(),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(false),
          child: const Text('Huỷ'),
        ),
        FilledButton(
          onPressed: _controller.text.trim().isEmpty ? null : attempt,
          child: const Text('Kích hoạt'),
        ),
      ],
    );
  }
}
