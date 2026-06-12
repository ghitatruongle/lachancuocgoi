import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:permission_handler/permission_handler.dart';

import 'native_call_shield_bridge.dart';

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
  double get progress => totalPermissions > 0 ? grantedCount / totalPermissions : 0;
  bool get allGranted => snapshot.allGranted;

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
class PermissionController extends StateNotifier<PermissionState>
    with WidgetsBindingObserver {
  PermissionController(this._bridge) : super(const PermissionState()) {
    WidgetsBinding.instance.addObserver(this);
    _refresh();
  }

  final NativeBridgeInterface _bridge;
  DateTime? _lastRefreshTime;

  static bool get _canUseRuntimePermissionUi =>
      !kIsWeb &&
      (defaultTargetPlatform == TargetPlatform.android ||
          defaultTargetPlatform == TargetPlatform.iOS);

  /// Microphone (and similar) via permission_handler; snapshot refreshed from native.
  Future<bool> requestMicrophonePermission() async {
    if (!_canUseRuntimePermissionUi) {
      await _refresh();
      return state.snapshot.recordAudio;
    }
    try {
      await Permission.microphone.request();
      await _refresh();
      return state.snapshot.recordAudio;
    } catch (e) {
      debugPrint('Failed to request microphone permission: $e');
      await _refresh();
      return state.snapshot.recordAudio;
    }
  }

  /// READ_PHONE_STATE / READ_CALL_LOG (Android) via permission_handler.
  Future<bool> requestPhoneAndCallLogPermissions() async {
    if (defaultTargetPlatform != TargetPlatform.android) {
      await _refresh();
      return state.snapshot.phoneState && state.snapshot.callLog;
    }
    try {
      await _bridge.requestPhoneAndCallLogPermissions();
      await _refresh();
      return state.snapshot.phoneState && state.snapshot.callLog;
    } catch (e) {
      debugPrint('Failed to request phone/call log permissions: $e');
      await _refresh();
      return state.snapshot.phoneState && state.snapshot.callLog;
    }
  }

  /// POST_NOTIFICATIONS (Android 13+) / notification (iOS).
  Future<bool> requestNotificationPermission() async {
    if (!_canUseRuntimePermissionUi) {
      await _refresh();
      return state.snapshot.notification;
    }
    try {
      await Permission.notification.request();
      await _refresh();
      return state.snapshot.notification;
    } catch (e) {
      debugPrint('Failed to request notification permission: $e');
      await _refresh();
      return state.snapshot.notification;
    }
  }

  Future<void> _requestStandardRuntimePermissions() async {
    if (!_canUseRuntimePermissionUi) return;

    final s = state.snapshot;
    final perms = <Permission>[];
    if (!s.recordAudio) perms.add(Permission.microphone);
    if (defaultTargetPlatform == TargetPlatform.android) {
      if (!s.notification) perms.add(Permission.notification);
    } else if (defaultTargetPlatform == TargetPlatform.iOS) {
      if (!s.notification) perms.add(Permission.notification);
    }
    if (perms.isEmpty) return;

    try {
      await perms.request();
    } catch (e) {
      debugPrint('Runtime permission batch request failed: $e');
    }
    await _refresh();
  }

  /// Refresh permission snapshot from native.
  /// Throttled to avoid rapid successive platform channel calls
  /// and unnecessary widget rebuilds.
  Future<void> _refresh() async {
    final now = DateTime.now();
    if (_lastRefreshTime != null &&
        now.difference(_lastRefreshTime!).inMilliseconds < 500) {
      return; // Skip if refreshed within last 500ms
    }
    _lastRefreshTime = now;
    try {
      final snapshot = await _bridge.getPermissionSnapshot();
      if (!mounted) return;
      // Only update state if snapshot actually changed to avoid rebuilds
      if (snapshot != state.snapshot) {
        state = state.copyWith(
          snapshot: snapshot,
          lastUpdated: DateTime.now(),
        );
      }
    } catch (e) {
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
  Future<bool> requestOverlayPermission() async {
    try {
      return await _bridge.requestOverlayPermission();
    } catch (e) {
      debugPrint('Failed to request overlay permission: $e');
      return false;
    }
  }

  /// Request accessibility permission.
  /// Lifecycle-based refresh handles state update when user returns from settings.
  Future<bool> requestAccessibilityPermission() async {
    try {
      return await _bridge.openAccessibilitySettings();
    } catch (e) {
      debugPrint('Failed to open accessibility settings: $e');
      return false;
    }
  }

  /// Request call screening role.
  /// Lifecycle-based refresh handles state update when user returns from settings.
  Future<bool> requestCallScreeningPermission() async {
    try {
      return await _bridge.requestCallScreeningRole();
    } catch (e) {
      debugPrint('Failed to request call screening role: $e');
      return false;
    }
  }

  /// Check if monitoring is active.
  Future<bool> checkMonitoringActive() async {
    try {
      return await _bridge.isMonitoringActive();
    } catch (e) {
      debugPrint('Failed to check monitoring status: $e');
      return false;
    }
  }

  /// Request all missing permissions in sequence.
  Future<Map<String, bool>> requestAllPermissions() async {
    final results = <String, bool>{};

    await _requestStandardRuntimePermissions();

    if (!state.snapshot.phoneState || !state.snapshot.callLog) {
      results['phoneAndCallLog'] = await requestPhoneAndCallLogPermissions();
    }

    if (!state.snapshot.overlay) {
      results['overlay'] = await requestOverlayPermission();
    }
    if (!state.snapshot.accessibility) {
      results['accessibility'] = await requestAccessibilityPermission();
    }
    if (!state.snapshot.callScreening) {
      results['callScreening'] = await requestCallScreeningPermission();
    }

    // Final refresh
    await _refresh();

    return results;
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }
}

// ─── Riverpod Providers ───────────────────────────────────────────────────────

final permissionControllerProvider = StateNotifierProvider<PermissionController, PermissionState>((ref) {
  final bridge = ref.watch(nativeBridgeProvider);
  return PermissionController(bridge);
});

/// Provider that returns true when all permissions are granted.
final allPermissionsGrantedProvider = Provider<bool>((ref) {
  final state = ref.watch(permissionControllerProvider);
  return state.allGranted;
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
