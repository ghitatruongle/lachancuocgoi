import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../analysis/analysis_providers.dart';
import '../../../app/settings_controller.dart';
import '../../../services/developer_mode_manager.dart';
import '../../../services/native_call_shield_bridge.dart';
import '../../theme/app_theme.dart';

/// Advanced settings. Developer Mode remains available in production through
/// the existing title-tap/password flow.
class AdvancedSection extends ConsumerWidget {
  const AdvancedSection({
    super.key,
    required this.settings,
    required this.controller,
  });

  final SettingsState settings;
  final SettingsController controller;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final developerMode = ref.watch(developerModeProvider);
    final tt = Theme.of(context).textTheme;
    return Column(
      children: [
        const _SystemHealthCard(),
        if (developerMode.isActive) ...[
          const SizedBox(height: AppSpacing.sm),
          const Divider(),
          Align(
            alignment: Alignment.centerLeft,
            child: Text(
              'Nhà sáng tạo',
              style: tt.titleSmall?.copyWith(fontWeight: FontWeight.bold),
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          _CreatorSection(settings: settings, controller: controller),
        ],
        const SizedBox(height: AppSpacing.sm),
        _CallScreeningCard(
          settings: settings,
          controller: controller,
          bridge: ref.read(nativeBridgeProvider),
        ),
      ],
    );
  }
}

class _CreatorSection extends StatelessWidget {
  const _CreatorSection({required this.settings, required this.controller});

  final SettingsState settings;
  final SettingsController controller;

  @override
  Widget build(BuildContext context) {
    final tt = Theme.of(context).textTheme;
    return Card(
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
              onChanged: (value) => controller.update(
                settings.copyWith(creatorAudioCapture: value),
              ),
            ),
            Text(
              'Yêu cầu đồng ý quyền ghi màn hình khi bắt đầu giám sát.',
              style: tt.bodySmall?.copyWith(
                color: Theme.of(context).colorScheme.error,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SystemHealthCard extends ConsumerWidget {
  const _SystemHealthCard();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    Map<String, String> summary;
    try {
      summary = ref.read(analysisCoordinatorProvider).healthSummary();
    } on Object {
      summary = const {'status': 'Chưa khởi tạo'};
    }
    return Card(
      color: cs.surfaceContainerHighest,
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.sm),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Trạng thái hệ thống AI',
              style: tt.titleSmall?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: AppSpacing.xxs),
            for (final entry in summary.entries)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 2),
                child: Row(
                  children: [
                    SizedBox(
                      width: 72,
                      child: Text(
                        entry.key,
                        style: tt.labelMedium?.copyWith(
                          color: cs.onSurfaceVariant,
                        ),
                      ),
                    ),
                    Expanded(child: Text(entry.value, style: tt.bodySmall)),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _CallScreeningCard extends StatefulWidget {
  const _CallScreeningCard({
    required this.settings,
    required this.controller,
    required this.bridge,
  });

  final SettingsState settings;
  final SettingsController controller;
  final NativeBridgeInterface bridge;

  @override
  State<_CallScreeningCard> createState() => _CallScreeningCardState();
}

class _CallScreeningCardState extends State<_CallScreeningCard> {
  final _numberController = TextEditingController();

  @override
  void dispose() {
    _numberController.dispose();
    super.dispose();
  }

  Future<void> _toggleBlock(bool enabled) async {
    if (enabled) {
      final consented = await showDialog<bool>(
        context: context,
        builder: (_) => const _CallScreeningConsentDialog(),
      );
      if (consented != true) return;
    }
    final next = widget.settings.copyWith(callScreeningBlockEnabled: enabled);
    await widget.controller.update(next);
    await widget.bridge.setCallScreeningBlockEnabled(enabled);
    await widget.bridge.setBlockedNumbers(next.blockedNumbers);
  }

  Future<void> _addNumber() async {
    final number = _numberController.text.trim().replaceAll(RegExp(r'\D'), '');
    if (number.isEmpty || widget.settings.blockedNumbers.contains(number)) {
      return;
    }
    final next = widget.settings.copyWith(
      blockedNumbers: [...widget.settings.blockedNumbers, number],
    );
    await widget.controller.update(next);
    await widget.bridge.setBlockedNumbers(next.blockedNumbers);
    _numberController.clear();
  }

  Future<void> _removeNumber(String number) async {
    final next = widget.settings.copyWith(
      blockedNumbers: widget.settings.blockedNumbers
          .where((candidate) => candidate != number)
          .toList(),
    );
    await widget.controller.update(next);
    await widget.bridge.setBlockedNumbers(next.blockedNumbers);
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    final settings = widget.settings;
    return Card(
      color: cs.surfaceContainerHighest,
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.sm),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              secondary: Icon(Icons.block, color: cs.error),
              title: const Text('Chặn số lừa đảo'),
              subtitle: const Text(
                'Tự động từ chối cuộc gọi từ danh sách do bạn quản lý. Mặc định tắt.',
              ),
              value: settings.callScreeningBlockEnabled,
              onChanged: _toggleBlock,
            ),
            if (settings.callScreeningBlockEnabled) ...[
              Text(
                'Danh sách số bị chặn (${settings.blockedNumbers.length})',
                style: tt.labelMedium?.copyWith(color: cs.onSurfaceVariant),
              ),
              const SizedBox(height: AppSpacing.xxs),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _numberController,
                      decoration: const InputDecoration(
                        labelText: 'Số điện thoại',
                        isDense: true,
                        border: OutlineInputBorder(),
                      ),
                      keyboardType: TextInputType.phone,
                      onSubmitted: (_) => _addNumber(),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.add_circle),
                    onPressed: _addNumber,
                  ),
                ],
              ),
              Wrap(
                spacing: 8,
                children: settings.blockedNumbers
                    .map(
                      (number) => Chip(
                        label: Text(number),
                        onDeleted: () => _removeNumber(number),
                      ),
                    )
                    .toList(),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _CallScreeningConsentDialog extends StatefulWidget {
  const _CallScreeningConsentDialog();

  @override
  State<_CallScreeningConsentDialog> createState() =>
      _CallScreeningConsentDialogState();
}

class _CallScreeningConsentDialogState
    extends State<_CallScreeningConsentDialog> {
  bool _consented = false;

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Cảnh báo: Chặn cuộc gọi'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Việc chặn có thể khiến bạn bỏ lỡ cuộc gọi quan trọng. Danh sách chặn không bảo đảm nhận diện tuyệt đối.',
          ),
          const SizedBox(height: AppSpacing.sm),
          CheckboxListTile(
            contentPadding: EdgeInsets.zero,
            value: _consented,
            onChanged: (value) => setState(() => _consented = value ?? false),
            title: const Text('Tôi hiểu rủi ro và muốn bật chặn số.'),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(false),
          child: const Text('Hủy'),
        ),
        FilledButton(
          onPressed: _consented ? () => Navigator.of(context).pop(true) : null,
          child: const Text('Đồng ý'),
        ),
      ],
    );
  }
}
