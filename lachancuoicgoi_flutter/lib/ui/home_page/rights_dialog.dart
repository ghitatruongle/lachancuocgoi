import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

/// Simplified rights dialog — shows permission list UI.
/// Actual permission granting is handled by native bridge in Phase 8.
class RightsDialog extends StatelessWidget {
  const RightsDialog({super.key});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;

    return Dialog(
      insetPadding: const EdgeInsets.all(AppSpacing.sm),
      child: SizedBox(
        height: MediaQuery.of(context).size.height * 0.94,
        child: Column(
          children: [
            // ── Header ──
            Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.lg,
                vertical: AppSpacing.sm,
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Quyền ứng dụng',
                            style: tt.titleLarge),
                        const SizedBox(height: AppSpacing.xxs),
                        Text(
                          'Cấp quyền để ứng dụng hoạt động đúng chức năng.',
                          style: tt.bodyMedium?.copyWith(
                            color: cs.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    onPressed: () => Navigator.of(context).pop(),
                    icon: const Icon(Icons.close),
                  ),
                ],
              ),
            ),

            Divider(color: cs.surfaceContainerHighest, height: 1),

            // ── Permission list ──
            Expanded(
              child: ListView(
                padding: const EdgeInsets.all(AppSpacing.sm),
                children: const [
                  _PermissionItem(
                    icon: Icons.mic,
                    title: 'Ghi âm',
                    description: 'Thu âm thanh cuộc gọi qua microphone.',
                    isGranted: true,
                  ),
                  _PermissionItem(
                    icon: Icons.phone,
                    title: 'Trạng thái cuộc gọi',
                    description:
                        'Phát hiện cuộc gọi đến để tự động giám sát.',
                    isGranted: false,
                  ),
                  _PermissionItem(
                    icon: Icons.layers,
                    title: 'Hiển thị trên ứng dụng khác',
                    description:
                        'Hiện cảnh báo ngoài ứng dụng khi phát hiện lừa đảo.',
                    isGranted: false,
                  ),
                  _PermissionItem(
                    icon: Icons.notifications,
                    title: 'Thông báo',
                    description:
                        'Gửi thông báo khi đang giám sát hoặc phát hiện nguy cơ.',
                    isGranted: false,
                  ),
                  _PermissionItem(
                    icon: Icons.call,
                    title: 'Vai trò sàng lọc cuộc gọi',
                    description:
                        'Tự động sàng lọc cuộc gọi đến trên thiết bị.',
                    isGranted: false,
                  ),
                  _PermissionItem(
                    icon: Icons.accessibility_new,
                    title: 'Trợ năng',
                    description:
                        'Đọc phụ đề cuộc gọi để phân tích không cần loa.',
                    isGranted: false,
                  ),
                ],
              ),
            ),

            Divider(color: cs.surfaceContainerHighest, height: 1),

            // ── Footer ──
            Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.lg,
                vertical: AppSpacing.xs,
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: () => Navigator.of(context).pop(),
                    child: const Text('Đóng'),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PermissionItem extends StatelessWidget {
  const _PermissionItem({
    required this.icon,
    required this.title,
    required this.description,
    required this.isGranted,
  });

  final IconData icon;
  final String title;
  final String description;
  final bool isGranted;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Card(
      margin: const EdgeInsets.only(bottom: AppSpacing.xxs),
      color: cs.surfaceContainerHighest,
      child: ListTile(
        leading: Icon(icon, color: cs.primary),
        title: Text(title),
        subtitle: Text(description),
        trailing: Icon(
          isGranted ? Icons.check_circle : Icons.cancel_outlined,
          color: isGranted ? const Color(0xFF4CAF50) : cs.error,
        ),
      ),
    );
  }
}
