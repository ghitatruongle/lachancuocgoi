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
  // Track which permission requests are currently in flight so a fast
  // double-tap on the same row can't spawn multiple concurrent
  // permission dialogs. The old code only blocked "request all", which
  // left individual buttons vulnerable to adb-style script replay or
  // impatient fingers.
  final Set<String> _inFlightPermissions = <String>{};

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    final state = ref.watch(permissionControllerProvider);
    final controller = ref.read(permissionControllerProvider.notifier);

    return Dialog(
      insetPadding: const EdgeInsets.all(AppSpacing.sm),
      child: SafeArea(
        child: SizedBox(
          height: (MediaQuery.of(context).size.height -
                  MediaQuery.of(context).padding.top -
                  MediaQuery.of(context).padding.bottom) *
              0.90,
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
                      isInFlight: _inFlightPermissions.contains('microphone'),
                      onRequest: state.snapshot.recordAudio
                          ? null
                          : () => _requestPermission(
                                'microphone',
                                () => controller.requestMicrophonePermission(),
                              ),
                    ),
                    _PermissionItem(
                      icon: Icons.phone,
                      title: 'Trạng thái cuộc gọi',
                      description:
                          'Phát hiện cuộc gọi đến để tự động giám sát.',
                      isGranted: state.snapshot.phoneState,
                      isInFlight: _inFlightPermissions
                          .contains('phoneAndCallLog'),
                      onRequest: state.snapshot.phoneState
                          ? null
                          : () => _requestPermission(
                                'phoneAndCallLog',
                                () => controller
                                    .requestPhoneAndCallLogPermissions(),
                              ),
                    ),
                    _PermissionItem(
                      icon: Icons.history,
                      title: 'Lịch sử cuộc gọi',
                      description: 'Đọc lịch sử cuộc gọi liên quan tới giám sát.',
                      isGranted: state.snapshot.callLog,
                      isInFlight: _inFlightPermissions
                          .contains('phoneAndCallLog'),
                      onRequest: state.snapshot.callLog
                          ? null
                          : () => _requestPermission(
                                'phoneAndCallLog',
                                () => controller
                                    .requestPhoneAndCallLogPermissions(),
                              ),
                    ),
                    _PermissionItem(
                      icon: Icons.layers,
                      title: 'Hiển thị trên ứng dụng khác',
                      description:
                          'Hiện cảnh báo ngoài ứng dụng khi phát hiện lừa đảo.\n👉 Cần bật thủ công trong Cài đặt > Ứng dụng > Lá chắn > Hiển thị trên ứng dụng khác.',
                      isGranted: state.snapshot.overlay,
                      isInFlight:
                          _inFlightPermissions.contains('overlay'),
                      onRequest: state.snapshot.overlay
                          ? null
                          : () => _requestPermission(
                                'overlay',
                                () => controller.requestOverlayPermission(),
                              ),
                    ),
                    _PermissionItem(
                      icon: Icons.notifications,
                      title: 'Thông báo',
                      description:
                          'Gửi thông báo khi đang giám sát hoặc phát hiện nguy cơ.\n👉 Android 13+ cần bật thủ công trong Cài đặt > Thông báo ứng dụng.',
                      isGranted: state.snapshot.notification,
                      isInFlight: _inFlightPermissions
                          .contains('notification'),
                      onRequest: state.snapshot.notification
                          ? null
                          : () => _requestPermission(
                                'notification',
                                () =>
                                    controller.requestNotificationPermission(),
                              ),
                    ),
                    _PermissionItem(
                      icon: Icons.call,
                      title: 'Vai trò sàng lọc cuộc gọi',
                      description:
                          'Tự động sàng lọc cuộc gọi đến trên thiết bị.\n👉 Cần bật thủ công: Cài đặt > Ứng dụng mặc định > Sàng lọc cuộc gọi > Lá chắn.',
                      isGranted: state.snapshot.callScreening,
                      isInFlight: _inFlightPermissions
                          .contains('callScreening'),
                      onRequest: state.snapshot.callScreening
                          ? null
                          : () => _requestPermission(
                                'callScreening',
                                () =>
                                    controller.requestCallScreeningPermission(),
                              ),
                    ),
                    _PermissionItem(
                      icon: Icons.accessibility_new,
                      title: 'Trợ năng',
                      description:
                          'Đọc phụ đề cuộc gọi để phân tích không cần loa.\n👉 Cần bật thủ công: Cài đặt > Trợ năng > Lá chắn > Bật dịch vụ.',
                      isGranted: state.snapshot.accessibility,
                      isInFlight:
                          _inFlightPermissions.contains('accessibility'),
                      onRequest: state.snapshot.accessibility
                          ? null
                          : () => _requestPermission(
                                'accessibility',
                                () =>
                                    controller.requestAccessibilityPermission(),
                              ),
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

  /// Wrap a permission-requestor so we can disable its button while the
  /// underlying dialog / settings intent is in flight. Keys are stable
  /// strings (`microphone`, `overlay`, …) — the controller already
  /// knows how to handle concurrent calls, but the UI shouldn't be
  /// firing the same channel twice within a few hundred milliseconds.
  Future<void> _requestPermission(
    String key,
    Future<void> Function() requestor,
  ) async {
    if (_inFlightPermissions.contains(key)) return;
    setState(() => _inFlightPermissions.add(key));
    try {
      await requestor();
    } finally {
      if (mounted) {
        setState(() => _inFlightPermissions.remove(key));
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
    this.isInFlight = false,
  });

  final IconData icon;
  final String title;
  final String description;
  final bool isGranted;
  final Future<void> Function()? onRequest;
  // Disables the action button while a request for this row is in
  // flight, preventing duplicate dialogs from rapid taps.
  final bool isInFlight;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final canRequest = onRequest != null;

    return Card(
      margin: const EdgeInsets.only(bottom: AppSpacing.xxs),
      color: cs.surfaceContainerHighest.withValues(alpha: isGranted ? 0.5 : 0.8),
      child: ListTile(
        leading: Icon(
          icon,
          color: isGranted ? const Color(0xFF4CAF50) : cs.primary,
        ),
        title: Text(
          title,
          style: TextStyle(
            fontWeight: isGranted ? FontWeight.normal : FontWeight.bold,
            color: isGranted ? cs.onSurface.withValues(alpha: 0.7) : cs.onSurface,
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
                icon: isInFlight
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.settings),
                tooltip: isInFlight ? 'Đang cấp quyền...' : 'Cấp quyền',
                onPressed: isInFlight ? null : onRequest,
              ),
            ],
          ],
        ),
      ),
    );
  }
}
