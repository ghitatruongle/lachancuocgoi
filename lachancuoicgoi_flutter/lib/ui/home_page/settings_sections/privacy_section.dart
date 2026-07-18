import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/settings_controller.dart';
import '../../../core/system_logger.dart';
import '../../../data/app_database.dart';
import '../../../data/call_history_retention.dart';
import '../../../services/native_call_shield_bridge.dart';
import '../../theme/app_theme.dart';

class PrivacySection extends ConsumerStatefulWidget {
  const PrivacySection({
    super.key,
    required this.settings,
    required this.controller,
  });

  final SettingsState settings;
  final SettingsController controller;

  @override
  ConsumerState<PrivacySection> createState() => _PrivacySectionState();
}

class _PrivacySectionState extends ConsumerState<PrivacySection> {
  bool _isResetting = false;

  Future<void> _changeCloudConsent(bool granted) async {
    if (granted) {
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Đồng ý phân tích đám mây'),
          content: const Text(
            'Khi bật, nội dung cần thiết từ cuộc gọi có thể được gửi tới '
            'dịch vụ AI bên ngoài để phân tích. Bạn có thể thu hồi đồng ý '
            'bất kỳ lúc nào. Dữ liệu cục bộ vẫn tuân theo thời hạn lưu đã chọn.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Hủy'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: const Text('Tôi đồng ý'),
            ),
          ],
        ),
      );
      if (confirmed != true) return;
    }
    await widget.controller.setCloudAnalysisConsent(granted);
  }

  Future<void> _resetSensitiveData() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Xóa dữ liệu nhạy cảm?'),
        content: const Text(
          'Thao tác này xóa toàn bộ lịch sử, bản khôi phục phiên, transcript '
          'đã lưu, log cục bộ và danh sách số chặn. Không thể hoàn tác.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Hủy'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Xóa dữ liệu'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    setState(() => _isResetting = true);
    try {
      final database = await ref.read(appDatabaseFutureProvider.future);
      final resetService = ref.read(sensitiveDataResetServiceProvider);
      await resetService.reset(
        database: database,
        clearPersistedLogs: () async {
          SystemLogger.instance.clear();
          await SystemLogger.instance.clearPersisted();
        },
      );
      final next = await widget.controller.resetSensitivePreferences();
      final bridge = ref.read(nativeBridgeProvider);
      await bridge.setCallScreeningBlockEnabled(next.callScreeningBlockEnabled);
      await bridge.setBlockedNumbers(next.blockedNumbers);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Đã xóa dữ liệu nhạy cảm trên thiết bị.')),
      );
    } on Exception {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Không thể xóa hết dữ liệu. Hãy thử lại.'),
        ),
      );
    } finally {
      if (mounted) setState(() => _isResetting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    return Card(
      color: cs.surfaceContainerHighest,
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.sm),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Dữ liệu & quyền riêng tư',
              style: tt.titleSmall?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: AppSpacing.xxs),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Cho phép phân tích đám mây'),
              subtitle: const Text(
                'Mặc định tắt. Bắt buộc có đồng ý trước khi gửi nội dung ra ngoài thiết bị.',
              ),
              value: widget.settings.cloudAnalysisConsent,
              onChanged: _changeCloudConsent,
            ),
            const SizedBox(height: AppSpacing.xxs),
            DropdownButtonFormField<CallHistoryRetention>(
              initialValue: widget.settings.callHistoryRetention,
              decoration: const InputDecoration(
                labelText: 'Tự động xóa lịch sử sau',
                border: OutlineInputBorder(),
              ),
              items: CallHistoryRetention.values
                  .map(
                    (retention) => DropdownMenuItem(
                      value: retention,
                      child: Text(retention.label),
                    ),
                  )
                  .toList(growable: false),
              onChanged: (retention) {
                if (retention == null) return;
                widget.controller.update(
                  widget.settings.copyWith(callHistoryRetention: retention),
                );
              },
            ),
            const SizedBox(height: AppSpacing.sm),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: _isResetting ? null : _resetSensitiveData,
                icon: _isResetting
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.delete_forever_outlined),
                label: const Text('Xóa dữ liệu nhạy cảm'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
