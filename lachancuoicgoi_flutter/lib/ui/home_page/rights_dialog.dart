import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../services/permission_controller.dart';
import '../theme/app_theme.dart';

/// Live permission dialog with real-time status and grant actions.
class RightsDialog extends ConsumerStatefulWidget {
  const RightsDialog({super.key});

  @override
  ConsumerState<RightsDialog> createState() => _RightsDialogState();
}

class _RightsDialogState extends ConsumerState<RightsDialog> {
  bool _isRequestingAll = false;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    final state = ref.watch(permissionControllerProvider);
    final controller = ref.read(permissionControllerProvider.notifier);

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
                        Text('Quyền ứng dụng', style: tt.titleLarge),
                        const SizedBox(height: AppSpacing.xxs),
                        Text(
                          'Cấp quyền để ứng dụng hoạt động đúng chức năng.',
                          style: tt.bodyMedium?.copyWith(
                            color: cs.onSurfaceVariant,
                          ),
                        ),
                        const SizedBox(height: AppSpacing.xxs),
                        LinearProgressIndicator(
                          value: state.progress,
                          backgroundColor: cs.surfaceContainerHighest,
                          color: state.allGranted
                              ? const Color(0xFF4CAF50)
                              : cs.primary,
                        ),
                        const SizedBox(height: AppSpacing.xxs),
                        Text(
                          '${state.grantedCount}/${state.totalPermissions} quyền đã cấp',
                          style: tt.bodySmall?.copyWith(
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
              child: RefreshIndicator(
                onRefresh: () => controller.refresh(),
                child: ListView(
                  padding: const EdgeInsets.all(AppSpacing.sm),
                  children: [
                    _PermissionItem(
                      icon: Icons.mic,
                      title: 'Ghi âm',
                      description: 'Thu âm thanh cuộc gọi qua microphone.',
                      isGranted: state.snapshot.recordAudio,
                      onRequest: null, // Auto-granted at install
                    ),
                    _PermissionItem(
                      icon: Icons.phone,
                      title: 'Trạng thái cuộc gọi',
                      description:
                          'Phát hiện cuộc gọi đến để tự động giám sát.',
                      isGranted: state.snapshot.phoneState,
                      onRequest: null, // Auto-granted at install
                    ),
                    _PermissionItem(
                      icon: Icons.layers,
                      title: 'Hiển thị trên ứng dụng khác',
                      description:
                          'Hiện cảnh báo ngoài ứng dụng khi phát hiện lừa đảo.',
                      isGranted: state.snapshot.overlay,
                      onRequest: state.snapshot.overlay
                          ? null
                          : () => controller.requestOverlayPermission(),
                    ),
                    _PermissionItem(
                      icon: Icons.notifications,
                      title: 'Thông báo',
                      description:
                          'Gửi thông báo khi đang giám sát hoặc phát hiện nguy cơ.',
                      isGranted: state.snapshot.notification,
                      onRequest: null, // Auto-granted at install (API <33)
                    ),
                    _PermissionItem(
                      icon: Icons.call,
                      title: 'Vai trò sàng lọc cuộc gọi',
                      description:
                          'Tự động sàng lọc cuộc gọi đến trên thiết bị.',
                      isGranted: state.snapshot.callScreening,
                      onRequest: state.snapshot.callScreening
                          ? null
                          : () => controller.requestCallScreeningPermission(),
                    ),
                    _PermissionItem(
                      icon: Icons.accessibility_new,
                      title: 'Trợ năng',
                      description:
                          'Đọc phụ đề cuộc gọi để phân tích không cần loa.',
                      isGranted: state.snapshot.accessibility,
                      onRequest: state.snapshot.accessibility
                          ? null
                          : () => controller.requestAccessibilityPermission(),
                    ),
                  ],
                ),
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
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  if (!state.allGranted)
                    ElevatedButton.icon(
                      onPressed: _isRequestingAll ? null : _requestAll,
                      icon: _isRequestingAll
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.auto_fix_high),
                      label: Text(_isRequestingAll ? 'Đang cấp...' : 'Cấp tất cả'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: cs.primary,
                        foregroundColor: cs.onPrimary,
                      ),
                    ),
                  const Spacer(),
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

  Future<void> _requestAll() async {
    setState(() => _isRequestingAll = true);
    try {
      await ref.read(permissionControllerProvider.notifier).requestAllPermissions();
    } finally {
      if (mounted) {
        setState(() => _isRequestingAll = false);
      }
    }
  }
}

class _PermissionItem extends StatelessWidget {
  const _PermissionItem({
    required this.icon,
    required this.title,
    required this.description,
    required this.isGranted,
    this.onRequest,
  });

  final IconData icon;
  final String title;
  final String description;
  final bool isGranted;
  final Future<bool> Function()? onRequest;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final canRequest = onRequest != null;

    return Card(
      margin: const EdgeInsets.only(bottom: AppSpacing.xxs),
      color: cs.surfaceContainerHighest.withOpacity(isGranted ? 0.5 : 0.8),
      child: ListTile(
        leading: Icon(
          icon,
          color: isGranted ? const Color(0xFF4CAF50) : cs.primary,
        ),
        title: Text(
          title,
          style: TextStyle(
            decoration: isGranted ? null : TextDecoration.lineThrough,
            decorationColor: cs.outline,
          ),
        ),
        subtitle: Text(description),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              isGranted ? Icons.check_circle : Icons.cancel_outlined,
              color: isGranted ? const Color(0xFF4CAF50) : cs.error,
            ),
            if (canRequest && !isGranted) ...[
              const SizedBox(width: 8),
              IconButton.filled(
                icon: const Icon(Icons.settings),
                tooltip: 'Cấp quyền',
                onPressed: onRequest,
              ),
            ],
          ],
        ),
      ),
    );
  }
}
