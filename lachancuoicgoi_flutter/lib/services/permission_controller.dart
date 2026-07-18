import 'dart:async';

import 'package:clock/clock.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart' show BuildContext, Icons;
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:permission_handler/permission_handler.dart';

import 'native_call_shield_bridge.dart';
import '../ui/widgets/permission_rationale_dialog.dart';

/// User-facing capability groups. Only [coreProtection] is required to begin
/// monitoring; enhanced overlays/accessibility and call blocking remain
/// explicit optional upgrades.
enum PermissionCapabilityGroup {
  coreProtection,
  enhancedProtection,
  callBlocking,
}

extension PermissionCapabilityGroupX on PermissionCapabilityGroup {
  String get title => switch (this) {
    PermissionCapabilityGroup.coreProtection => 'Bảo vệ cốt lõi',
    PermissionCapabilityGroup.enhancedProtection => 'Bảo vệ nâng cao',
    PermissionCapabilityGroup.callBlocking => 'Chặn cuộc gọi',
  };

  String get description => switch (this) {
    PermissionCapabilityGroup.coreProtection =>
      'Phát hiện cuộc gọi, nhận âm thanh và gửi cảnh báo.',
    PermissionCapabilityGroup.enhancedProtection =>
      'Hiện cảnh báo nổi và đọc phụ đề cuộc gọi khi thiết bị hỗ trợ.',
    PermissionCapabilityGroup.callBlocking =>
      'Từ chối các số bạn chủ động thêm vào danh sách chặn.',
  };

  bool get isRequired => this == PermissionCapabilityGroup.coreProtection;
}

class CapabilityGroupStatus {
  const CapabilityGroupStatus({
    required this.group,
    required this.grantedCount,
    required this.totalCount,
    required this.missingPermissions,
  });

  final PermissionCapabilityGroup group;
  final int grantedCount;
  final int totalCount;
  final List<String> missingPermissions;

  bool get isGranted => grantedCount == totalCount;
  double get progress => totalCount == 0 ? 1 : grantedCount / totalCount;
}

/// State holder for all permission statuses.
class PermissionState {
  const PermissionState({
    this.snapshot = const PermissionSnapshot(),
    this.isLoading = false,
    this.lastUpdated,
  });

  final PermissionSnapshot snapshot;
  final bool isLoading;
  final DateTime? lastUpdated;

  int get grantedCount => snapshot.grantedCount;
  int get totalPermissions => PermissionSnapshot.totalPermissions;
  double get progress =>
      totalPermissions > 0 ? grantedCount / totalPermissions : 0;
  bool get allGranted => snapshot.allGranted;
  bool get essentialGranted =>
      capabilityStatus(PermissionCapabilityGroup.coreProtection).isGranted;
  int get essentialGrantedCount =>
      capabilityStatus(PermissionCapabilityGroup.coreProtection).grantedCount;
  int get essentialPermissionCount =>
      capabilityStatus(PermissionCapabilityGroup.coreProtection).totalCount;
  double get essentialProgress =>
      capabilityStatus(PermissionCapabilityGroup.coreProtection).progress;

  List<CapabilityGroupStatus> get capabilityGroups =>
      PermissionCapabilityGroup.values.map(capabilityStatus).toList();

  CapabilityGroupStatus capabilityStatus(PermissionCapabilityGroup group) {
    final entries = switch (group) {
      PermissionCapabilityGroup.coreProtection => <(String, bool)>[
        ('Ghi âm', snapshot.recordAudio),
        ('Trạng thái cuộc gọi', snapshot.phoneState),
        ('Lịch sử cuộc gọi', snapshot.callLog),
        ('Thông báo', snapshot.notification),
      ],
      PermissionCapabilityGroup.enhancedProtection => <(String, bool)>[
        ('Hiển thị trên ứng dụng khác', snapshot.overlay),
        ('Trợ năng', snapshot.accessibility),
      ],
      PermissionCapabilityGroup.callBlocking => <(String, bool)>[
        ('Sàng lọc cuộc gọi', snapshot.callScreening),
      ],
    };
    return CapabilityGroupStatus(
      group: group,
      grantedCount: entries.where((entry) => entry.$2).length,
      totalCount: entries.length,
      missingPermissions: entries
          .where((entry) => !entry.$2)
          .map((entry) => entry.$1)
          .toList(growable: false),
    );
  }

  PermissionState copyWith({
    PermissionSnapshot? snapshot,
    bool? isLoading,
    DateTime? lastUpdated,
  }) {
    return PermissionState(
      snapshot: snapshot ?? this.snapshot,
      isLoading: isLoading ?? this.isLoading,
      lastUpdated: lastUpdated ?? this.lastUpdated,
    );
  }

  @override
  String toString() {
    return 'PermissionState(granted: $grantedCount/$totalPermissions, allGranted: $allGranted)';
  }
}

/// Controller for managing Android permissions via native bridge.
class PermissionController extends Notifier<PermissionState>
    with WidgetsBindingObserver {
  /// Backward-compatible constructor for tests that instantiate directly.
  /// In production, use [ProviderContainer] / [NotifierProvider] which calls [build].
  PermissionController([NativeBridgeInterface? bridge])
    : _storedBridge = bridge;

  final NativeBridgeInterface? _storedBridge;

  NativeBridgeInterface get _bridge =>
      _storedBridge ?? ref.read(nativeBridgeProvider);

  @override
  PermissionState build() {
    WidgetsBinding.instance.addObserver(this);
    ref.onDispose(() {
      WidgetsBinding.instance.removeObserver(this);
    });
    _refresh();
    return const PermissionState();
  }

  DateTime? _lastRefreshTime;

  static bool get _canUseRuntimePermissionUi =>
      !kIsWeb &&
      (defaultTargetPlatform == TargetPlatform.android ||
          defaultTargetPlatform == TargetPlatform.iOS);

  /// Microphone (and similar) via permission_handler; snapshot refreshed from native.
  Future<bool> requestMicrophonePermission([BuildContext? context]) async {
    if (context != null && !state.snapshot.recordAudio) {
      final proceed = await PermissionRationaleDialog.show(
        context,
        permissionName: 'Ghi âm',
        rationale:
            'Lá Chắn Cuộc Gọi cần quyền ghi âm để thu nhận giọng nói của cuộc gọi đến, phục vụ cho việc chuyển đổi giọng nói thành văn bản (STT) và phân tích các dấu hiệu lừa đảo theo thời gian thực.',
        icon: Icons.mic,
      );
      if (!proceed) return state.snapshot.recordAudio;
    }

    if (!_canUseRuntimePermissionUi) {
      await _refresh();
      return state.snapshot.recordAudio;
    }
    try {
      await Permission.microphone.request();
      await _refresh();
      return state.snapshot.recordAudio;
    } on Exception catch (e) {
      debugPrint('Failed to request microphone permission: $e');
      await _refresh();
      return state.snapshot.recordAudio;
    }
  }

  /// READ_PHONE_STATE / READ_CALL_LOG (Android) via permission_handler.
  Future<bool> requestPhoneAndCallLogPermissions([
    BuildContext? context,
  ]) async {
    if (context != null &&
        (!state.snapshot.phoneState || !state.snapshot.callLog)) {
      final proceed = await PermissionRationaleDialog.show(
        context,
        permissionName: 'Trạng thái & Lịch sử cuộc gọi',
        rationale:
            'Lá Chắn Cuộc Gọi cần quyền đọc trạng thái điện thoại để phát hiện cuộc gọi đến và tự động kích hoạt giám sát. Quyền lịch sử cuộc gọi giúp ghi nhận thời lượng cuộc gọi và cập nhật thông tin lịch sử quét.',
        icon: Icons.phone,
      );
      if (!proceed) return state.snapshot.phoneState && state.snapshot.callLog;
    }

    if (defaultTargetPlatform != TargetPlatform.android) {
      await _refresh();
      return state.snapshot.phoneState && state.snapshot.callLog;
    }
    try {
      await _bridge.requestPhoneAndCallLogPermissions();
      await _refresh();
      return state.snapshot.phoneState && state.snapshot.callLog;
    } on Exception catch (e) {
      debugPrint('Failed to request phone/call log permissions: $e');
      await _refresh();
      return state.snapshot.phoneState && state.snapshot.callLog;
    }
  }

  /// POST_NOTIFICATIONS (Android 13+) / notification (iOS).
  Future<bool> requestNotificationPermission([BuildContext? context]) async {
    if (context != null && !state.snapshot.notification) {
      final proceed = await PermissionRationaleDialog.show(
        context,
        permissionName: 'Thông báo',
        rationale:
            'Lá Chắn Cuộc Gọi cần quyền gửi thông báo để duy trì dịch vụ chạy nền giám sát cuộc gọi và hiển thị các cảnh báo rủi ro tức thời khi phát hiện dấu hiệu nghi ngờ.',
        icon: Icons.notifications,
      );
      if (!proceed) return state.snapshot.notification;
    }

    if (!_canUseRuntimePermissionUi) {
      await _refresh();
      return state.snapshot.notification;
    }
    try {
      await Permission.notification.request();
      await _refresh();
      return state.snapshot.notification;
    } on Exception catch (e) {
      debugPrint('Failed to request notification permission: $e');
      await _refresh();
      return state.snapshot.notification;
    }
  }

  Future<void> _requestStandardRuntimePermissions([
    BuildContext? context,
  ]) async {
    if (!_canUseRuntimePermissionUi) return;

    final s = state.snapshot;
    if (!s.recordAudio) {
      await requestMicrophonePermission(context);
    }
    if (context != null && !context.mounted) return;
    if (defaultTargetPlatform == TargetPlatform.android ||
        defaultTargetPlatform == TargetPlatform.iOS) {
      if (!state.snapshot.notification) {
        await requestNotificationPermission(context);
      }
    }
    await _refresh();
  }

  /// Refresh permission snapshot from native.
  /// Throttled to avoid rapid successive platform channel calls
  /// and unnecessary widget rebuilds.
  Future<void> _refresh() async {
    final now = clock.now();
    if (_lastRefreshTime != null &&
        now.difference(_lastRefreshTime!).inMilliseconds < 500) {
      return; // Skip if refreshed within last 500ms
    }
    _lastRefreshTime = now;
    try {
      final snapshot = await _bridge.getPermissionSnapshot();
      // Riverpod's Notifier does have ref.mounted, so we check it here
      // before updating state.
      if (!ref.mounted) return;
      if (snapshot != state.snapshot) {
        state = state.copyWith(snapshot: snapshot, lastUpdated: clock.now());
      }
    } on Exception catch (e) {
      debugPrint('Failed to refresh permissions: $e');
    }
  }

  /// Public refresh method.
  Future<void> refresh() => _refresh();

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      // Reset throttle so resume always triggers a fresh snapshot.
      _lastRefreshTime = null;
      _refresh();
    }
  }

  /// Request overlay permission.
  /// Lifecycle-based refresh handles state update when user returns from settings.
  Future<bool> requestOverlayPermission([BuildContext? context]) async {
    if (context != null && !state.snapshot.overlay) {
      final proceed = await PermissionRationaleDialog.show(
        context,
        permissionName: 'Hiển thị trên ứng dụng khác',
        rationale:
            'Lá Chắn Cuộc Gọi cần quyền hiển thị trên ứng dụng khác để bật cảnh báo màu đỏ tràn màn hình khi phát hiện cuộc gọi lừa đảo khẩn cấp, giúp bạn nhận biết ngay lập tức.',
        icon: Icons.layers,
      );
      if (!proceed) return state.snapshot.overlay;
    }

    try {
      return await _bridge.requestOverlayPermission();
    } on Exception catch (e) {
      debugPrint('Failed to request overlay permission: $e');
      return false;
    }
  }

  /// Request accessibility permission.
  /// Lifecycle-based refresh handles state update when user returns from settings.
  Future<bool> requestAccessibilityPermission([BuildContext? context]) async {
    if (context != null && !state.snapshot.accessibility) {
      final proceed = await PermissionRationaleDialog.show(
        context,
        permissionName: 'Trợ năng',
        rationale:
            'Lá Chắn Cuộc Gọi cần quyền Trợ năng để đọc phụ đề âm thanh cuộc gọi trực tiếp từ hệ thống, giúp bảo vệ bạn ngay cả khi bạn không bật loa ngoài.',
        icon: Icons.accessibility_new,
      );
      if (!proceed) return state.snapshot.accessibility;
    }

    try {
      return await _bridge.openAccessibilitySettings();
    } on Exception catch (e) {
      debugPrint('Failed to open accessibility settings: $e');
      return false;
    }
  }

  /// Request call screening role.
  /// Lifecycle-based refresh handles state update when user returns from settings.
  Future<bool> requestCallScreeningPermission([BuildContext? context]) async {
    if (context != null && !state.snapshot.callScreening) {
      final proceed = await PermissionRationaleDialog.show(
        context,
        permissionName: 'Sàng lọc cuộc gọi',
        rationale:
            'Lá Chắn Cuộc Gọi cần quyền Vai trò Sàng lọc Cuộc gọi để chủ động nhận dạng cuộc gọi từ số lạ và thực hiện sàng lọc trước khi chuông điện thoại của bạn reo.',
        icon: Icons.call,
      );
      if (!proceed) return state.snapshot.callScreening;
    }

    try {
      return await _bridge.requestCallScreeningRole();
    } on Exception catch (e) {
      debugPrint('Failed to request call screening role: $e');
      return false;
    }
  }

  /// Check if monitoring is active.
  Future<bool> checkMonitoringActive() async {
    try {
      return await _bridge.isMonitoringActive();
    } on Exception catch (e) {
      debugPrint('Failed to check monitoring status: $e');
      return false;
    }
  }

  /// Request all missing permissions in sequence.
  Future<Map<String, bool>> requestAllPermissions([
    BuildContext? context,
  ]) async {
    final results = <String, bool>{};

    for (final group in PermissionCapabilityGroup.values) {
      if (context != null && !context.mounted) break;
      results.addAll(await requestCapabilityGroup(group, context));
    }

    await _refresh();
    return results;
  }

  /// Requests the permissions for one capability group. This avoids asking
  /// for optional, highly privileged roles during first-run onboarding.
  Future<Map<String, bool>> requestCapabilityGroup(
    PermissionCapabilityGroup group, [
    BuildContext? context,
  ]) async {
    final results = <String, bool>{};

    if (group == PermissionCapabilityGroup.coreProtection) {
      await _requestStandardRuntimePermissions(context);
      if (context != null && !context.mounted) return results;
      if (!state.snapshot.phoneState || !state.snapshot.callLog) {
        results['phoneAndCallLog'] = await requestPhoneAndCallLogPermissions(
          context,
        );
      }
      await _refresh();
      return results;
    }

    if (group == PermissionCapabilityGroup.enhancedProtection) {
      if (!state.snapshot.overlay) {
        results['overlay'] = await requestOverlayPermission(context);
      }
      if (context != null && !context.mounted) return results;
      if (!state.snapshot.accessibility) {
        results['accessibility'] = await requestAccessibilityPermission(
          context,
        );
      }
      await _refresh();
      return results;
    }

    if (!state.snapshot.callScreening) {
      results['callScreening'] = await requestCallScreeningPermission(context);
    }
    await _refresh();
    return results;
  }
}

// ─── Riverpod Providers ───────────────────────────────────────────────────────

final permissionControllerProvider =
    NotifierProvider<PermissionController, PermissionState>(
      PermissionController.new,
    );

/// Provider that returns true when all permissions are granted.
final allPermissionsGrantedProvider = Provider<bool>((ref) {
  final state = ref.watch(permissionControllerProvider);
  return state.allGranted;
});

/// True when the minimum permissions for call monitoring are ready.
final essentialPermissionsGrantedProvider = Provider<bool>((ref) {
  return ref.watch(permissionControllerProvider).essentialGranted;
});

final capabilityGroupsProvider = Provider<List<CapabilityGroupStatus>>((ref) {
  return ref.watch(permissionControllerProvider).capabilityGroups;
});

/// Provider that returns the list of missing permission names.
final missingPermissionsProvider = Provider<List<String>>((ref) {
  final state = ref.watch(permissionControllerProvider);
  final s = state.snapshot;
  final missing = <String>[];

  if (!s.recordAudio) missing.add('Ghi âm');
  if (!s.phoneState) missing.add('Trạng thái cuộc gọi');
  if (!s.callLog) missing.add('Lịch sử cuộc gọi');
  if (!s.overlay) missing.add('Hiển thị trên ứng dụng khác');
  if (!s.notification) missing.add('Thông báo');
  if (!s.accessibility) missing.add('Trợ năng');
  if (!s.callScreening) missing.add('Sàng lọc cuộc gọi');

  return missing;
});
