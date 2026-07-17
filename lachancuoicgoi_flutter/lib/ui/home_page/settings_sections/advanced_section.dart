import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../analysis/analysis_providers.dart';
import '../../../app/settings_controller.dart';
import '../../../data/remote_config_store.dart';
import '../../../services/developer_mode_manager.dart';
import '../../../services/native_call_shield_bridge.dart';
import '../../theme/app_theme.dart';

/// Advanced settings: developer mode section, call screening card, OTA update card.
class AdvancedSection extends ConsumerStatefulWidget {
  const AdvancedSection({
    super.key,
    required this.settings,
    required this.controller,
  });

  final SettingsState settings;
  final SettingsController controller;

  @override
  ConsumerState<AdvancedSection> createState() => _AdvancedSectionState();
}

class _AdvancedSectionState extends ConsumerState<AdvancedSection> {
  @override
  Widget build(BuildContext context) {
    final developerMode = ref.watch(developerModeProvider);
    final tt = Theme.of(context).textTheme;

    return Column(
      children: [
        const _SystemHealthCard(),
        const SizedBox(height: AppSpacing.sm),

        if (developerMode.isActive) ...[
          const SizedBox(height: AppSpacing.sm),
          const Divider(),
          const SizedBox(height: AppSpacing.xxs),
          Align(
            alignment: Alignment.centerLeft,
            child: Text(
              'Nhà sáng tạo',
              style: tt.titleSmall?.copyWith(fontWeight: FontWeight.bold),
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          _CreatorSection(
            settings: widget.settings,
            controller: widget.controller,
          ),
        ],

        const SizedBox(height: AppSpacing.sm),

        _CallScreeningCard(
          settings: widget.settings,
          controller: widget.controller,
          bridge: ref.read(nativeBridgeProvider),
        ),

        const SizedBox(height: AppSpacing.sm),

        const _OtaUpdateCard(),
      ],
    );
  }
}

/// Creator mode section (developer-only audio screen capture toggle).
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
              onChanged: (v) =>
                  controller.update(settings.copyWith(creatorAudioCapture: v)),
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
    );
  }
}

// --- System Health Card ---
class _SystemHealthCard extends ConsumerWidget {
  const _SystemHealthCard();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    Map<String, String> summary;
    try {
      summary = ref.read(analysisCoordinatorProvider).healthSummary();
    } on Object catch (_) {
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

// --- Call Screening Card ---
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
    if (enabled) {
      await widget.bridge.setBlockedNumbers(next.blockedNumbers);
    }
  }

  Future<void> _addNumber() async {
    final number =
        _numberController.text.trim().replaceAll(RegExp(r'\D'), '');
    if (number.isEmpty) return;
    if (widget.settings.blockedNumbers.contains(number)) return;
    final next = widget.settings.copyWith(
      blockedNumbers: [...widget.settings.blockedNumbers, number],
    );
    await widget.controller.update(next);
    await widget.bridge.setBlockedNumbers(next.blockedNumbers);
    _numberController.clear();
    setState(() {});
  }

  Future<void> _removeNumber(String number) async {
    final next = widget.settings.copyWith(
      blockedNumbers:
          widget.settings.blockedNumbers.where((n) => n != number).toList(),
    );
    await widget.controller.update(next);
    await widget.bridge.setBlockedNumbers(next.blockedNumbers);
    setState(() {});
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
            Row(
              children: [
                Icon(Icons.block, color: cs.error),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Chặn số lừa đảo',
                        style: tt.titleSmall?.copyWith(fontWeight: FontWeight.bold),
                      ),
                      Text(
                        'Tự động từ chối cuộc gọi từ danh sách số đã biết lừa đảo. Mặc định TỦT.',
                        style: tt.bodySmall?.copyWith(color: cs.onSurfaceVariant),
                      ),
                    ],
                  ),
                ),
                Switch(
                  value: settings.callScreeningBlockEnabled,
                  onChanged: _toggleBlock,
                ),
              ],
            ),
            if (settings.callScreeningBlockEnabled) ...[
              const SizedBox(height: AppSpacing.xs),
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
                  const SizedBox(width: AppSpacing.xs),
                  IconButton(
                    icon: const Icon(Icons.add_circle),
                    onPressed: _addNumber,
                  ),
                ],
              ),
              if (settings.blockedNumbers.isNotEmpty) ...[
                const SizedBox(height: AppSpacing.xxs),
                Wrap(
                  spacing: 8,
                  runSpacing: 4,
                  children: settings.blockedNumbers.map((number) {
                    return Chip(
                      label: Text(number),
                      onDeleted: () => _removeNumber(number),
                      deleteIcon: const Icon(Icons.close, size: 18),
                    );
                  }).toList(),
                ),
              ],
            ],
          ],
        ),
      ),
    );
  }
}

// --- Consent Dialog ---
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
      title: const Text('C\u1ea3nh b\u00e1o: Ch\u1eb7n cu\u1ed9c g\u1ecdi'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Vi\u1ec7c ch\u1eb7n cu\u1ed9c g\u1ecdi c\u00f3 th\u1ec3 khi\u1ebfn b\u1ea1n b\u1ecf l\u1ee1 cu\u1ed9c g\u1ecdi quan tr\u1ecdng t\u1eeb:',
          ),
          const SizedBox(height: 8),
          const Text('\u2022 S\u1ed1 b\u00e1o \u0111\u1ed9ng / kh\u1ea9n c\u1ea5p'),
          const Text('\u2022 Ng\u00e2n h\u00e0ng / c\u01a1 quan ch\u00ednh th\u1ee9c'),
          const Text('\u2022 S\u1ed1 giao d\u1ecbch t\u00e0i ch\u00ednh quan tr\u1ecdng'),
          const SizedBox(height: 12),
          const Text(
            'S\u1ed1 "c\u00f4ng an gi\u1ea3" c\u00f3 th\u1ec3 gi\u1ea3 m\u1ea1o s\u1ed1. Danh s\u00e1ch ch\u1eb7n kh\u00f4ng ph\u1ea3i b\u1ea3o \u0111\u1ea3m tuy\u1ec7t \u0111\u1ed1i.',
          ),
          const SizedBox(height: 16),
          CheckboxListTile(
            contentPadding: EdgeInsets.zero,
            value: _consented,
            onChanged: (v) => setState(() => _consented = v ?? false),
            title: const Text('T\u00f4i hi\u1ec3u r\u1ee7i ro v\u00e0 mu\u1ed1n b\u1eadt ch\u1eb7n s\u1ed1 l\u1eeba \u0111\u1ea3o.'),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(false),
          child: const Text('H\u1ee7y'),
        ),
        FilledButton(
          onPressed: _consented
              ? () => Navigator.of(context).pop(true)
              : null,
          child: const Text('\u0110\u1ed3ng \u00fd'),
        ),
      ],
    );
  }
}

// --- OTA Update Card ---
class _OtaUpdateCard extends ConsumerStatefulWidget {
  const _OtaUpdateCard();

  @override
  ConsumerState<_OtaUpdateCard> createState() => _OtaUpdateCardState();
}

class _OtaUpdateCardState extends ConsumerState<_OtaUpdateCard> {
  bool _checking = false;
  String? _statusMessage;

  Future<void> _checkForUpdates() async {
    final store = ref.read(remoteConfigStoreProvider);
    if (store == null) {
      setState(() {
        _statusMessage = 'C\u1eadp nh\u1eadt t\u1eeb xa ch\u01b0a \u0111\u01b0\u1ee3c c\u1ea5u h\u00ecnh.';
      });
      return;
    }
    setState(() {
      _checking = true;
      _statusMessage = null;
    });
    try {
      final wasUpdated = await store.refreshIfNeeded();
      if (wasUpdated) {
        ref.invalidate(l1AnalyzerProvider);
        ref.invalidate(gDetectionEngineProvider);
        ref.invalidate(l2AnalyzerProvider);
        ref.invalidate(l3AnalyzerProvider);
      }
      final newVersion = await store.getAppliedVersion();
      setState(() {
        _checking = false;
        _statusMessage = wasUpdated
            ? '\u0110\u00e3 c\u1eadp nh\u1eadt b\u1ed9 t\u1eeb kh\u00f3a (v$newVersion).'
            : 'B\u1ed9 t\u1eeb kh\u00f3a \u0111\u00e3 m\u1edbi nh\u1ea5t (v$newVersion).';
      });
    } on Object catch (e) {
      setState(() {
        _checking = false;
        _statusMessage = 'L\u1ed7i c\u1eadp nh\u1eadt: $e';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    final store = ref.watch(remoteConfigStoreProvider);

    if (store == null) {
      return Card(
        color: cs.surfaceContainerHighest,
        margin: EdgeInsets.zero,
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.sm),
          child: Row(
            children: [
              Icon(Icons.cloud_off, color: cs.onSurfaceVariant),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Text(
                  'C\u1eadp nh\u1eadt t\u1eeb xa ch\u01b0a \u0111\u01b0\u1ee3c c\u1ea5u h\u00ecnh. App d\u00f9ng b\u1ed9 t\u1eeb kh\u00f3a m\u1eb7c \u0111\u1ecbnh.',
                  style: tt.bodySmall?.copyWith(color: cs.onSurfaceVariant),
                ),
              ),
            ],
          ),
        ),
      );
    }

    return FutureBuilder<int>(
      future: store.getAppliedVersion(),
      builder: (context, snapshot) {
        final version = snapshot.data ?? 0;
        return Card(
          color: cs.surfaceContainerHighest,
          margin: EdgeInsets.zero,
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.sm),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(Icons.cloud_download, color: cs.primary),
                    const SizedBox(width: AppSpacing.sm),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'C\u1eadp nh\u1eadt b\u1ed9 t\u1eeb kh\u00f3a',
                            style: tt.titleSmall?.copyWith(fontWeight: FontWeight.bold),
                          ),
                          Text(
                            'Phi\u00ean b\u1ea3n: ${version > 0 ? "v$version" : "m\u1eb7c \u0111\u1ecbnh (bundled)"}',
                            style: tt.bodySmall?.copyWith(color: cs.onSurfaceVariant),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                if (_statusMessage != null) ...[
                  const SizedBox(height: AppSpacing.xxs),
                  Text(
                    _statusMessage!,
                    style: tt.bodySmall?.copyWith(
                      color: _statusMessage!.startsWith('L\u1ed7i')
                          ? cs.error
                          : cs.onSurfaceVariant,
                    ),
                  ),
                ],
                const SizedBox(height: AppSpacing.xs),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton.tonal(
                    onPressed: _checking ? null : _checkForUpdates,
                    child: _checking
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Text('Ki\u1ec3m tra c\u1eadp nh\u1eadt'),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
