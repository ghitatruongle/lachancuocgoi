import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/settings_controller.dart';
import '../../services/developer_mode_manager.dart';
import '../theme/app_theme.dart';
import 'settings_sections/advanced_section.dart';
import 'settings_sections/analysis_section.dart';
import 'settings_sections/audio_section.dart';
import 'settings_sections/privacy_section.dart';
import 'settings_sections/theme_section.dart';

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

    void onChanged(SettingsState next) => controller.update(next);

    return Dialog(
      insetPadding: const EdgeInsets.all(AppSpacing.sm),
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.sm),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // --- Header ---
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
                  tooltip: 'Đóng',
                  icon: const Icon(Icons.close),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.xxs),

            // --- Content ---
            Flexible(
              child: SingleChildScrollView(
                child: Column(
                  children: [
                    const SizedBox(height: AppSpacing.sm),

                    ThemeSection(state: settings, onChanged: onChanged),
                    const SizedBox(height: AppSpacing.sm),

                    AnalysisSection(
                      selectedMode: settings.analysisMode,
                      cloudConsentGranted: settings.cloudAnalysisConsent,
                      onModeSelected: (mode) =>
                          onChanged(settings.copyWith(analysisMode: mode)),
                    ),
                    const SizedBox(height: AppSpacing.sm),

                    AudioSection(state: settings, onChanged: onChanged),
                    const SizedBox(height: AppSpacing.sm),

                    PrivacySection(settings: settings, controller: controller),
                    const SizedBox(height: AppSpacing.sm),

                    AdvancedSection(settings: settings, controller: controller),
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

/// Developer password dialog (triggered by tapping title 5 times).
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
                tooltip: _showPassword ? 'Ẩn mật khẩu' : 'Hiện mật khẩu',
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
