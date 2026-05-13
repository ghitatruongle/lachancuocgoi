import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'native_call_shield_bridge.dart';

/// State holder for all permission statuses.
class PermissionState {
  const PermissionState({
    this.snapshot = const PermissionSnapshot(),
    this.isLoading = false,
    this.lastUpdated,
    this.error,
  });

  final PermissionSnapshot snapshot;
  final bool isLoading;
  final DateTime? lastUpdated;
  final String? error;

  int get grantedCount => snapshot.grantedCount;
  int get totalPermissions => PermissionSnapshot.totalPermissions;
  double get progress => totalPermissions > 0 ? grantedCount / totalPermissions : 0;
  bool get allGranted => snapshot.allGranted;

  PermissionState copyWith({
    PermissionSnapshot? snapshot,
    bool? isLoading,
    DateTime? lastUpdated,
    String? error,
  }) {
    return PermissionState(
      snapshot: snapshot ?? this.snapshot,
      isLoading: isLoading ?? this.isLoading,
      lastUpdated: lastUpdated ?? this.lastUpdated,
      error: error,
    );
  }

  @override
  String toString() {
    return 'PermissionState(granted: $grantedCount/$totalPermissions, allGranted: $allGranted, error: $error)';
  }
}

/// Controller for managing Android permissions via native bridge.
class PermissionController extends StateNotifier<PermissionState> {
  PermissionController(this._bridge) : super(const PermissionState()) {
    _initMonitoringStateStream();
    _refresh();
  }

  final NativeCallShieldBridge _bridge;
  StreamSubscription<(MonitoringState, int?, String?)>? _monitoringStateSub;

  /// Initialize monitoring state stream subscription with proper error handling.
  void _initMonitoringStateStream() {
    try {
      _monitoringStateSub = _bridge.monitoringStateStream.listen(
        (state) {
          debugPrint('Monitoring state changed: $state');
          // Handle state changes if needed
        },
        onError: (error) {
          debugPrint('Error in monitoring state stream: $error');
          state = state.copyWith(error: 'Lỗi stream trạng thái: ${error.toString()}');
        },
        onDone: () {
          debugPrint('Monitoring state stream closed');
        },
        cancelOnError: true,
      );
    } catch (e) {
      debugPrint('Failed to initialize monitoring state stream: $e');
      state = state.copyWith(error: 'Không thể khởi tạo stream giám sát: ${e.toString()}');
    }
  }

  /// Refresh permission snapshot from native.
  Future<void> _refresh() async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      final snapshot = await _bridge.getPermissionSnapshot();
      state = state.copyWith(
        snapshot: snapshot,
        isLoading: false,
        lastUpdated: DateTime.now(),
      );
      debugPrint('Permission refreshed: $snapshot');
    } catch (e) {
      debugPrint('Failed to refresh permissions: $e');
      state = state.copyWith(
        isLoading: false,
        error: 'Không thể tải quyền: ${e.toString()}',
      );
    }
  }

  /// Public refresh method.
  Future<void> refresh() => _refresh();

  /// Request overlay permission.
  Future<bool> requestOverlayPermission() async {
    try {
      final result = await _bridge.requestOverlayPermission();
      if (result) {
        await Future.delayed(const Duration(milliseconds: 500));
        await _refresh();
      }
      return result;
    } catch (e) {
      debugPrint('Failed to request overlay permission: $e');
      state = state.copyWith(error: 'Lỗi xin quyền overlay: ${e.toString()}');
      return false;
    }
  }

  /// Request accessibility permission.
  Future<bool> requestAccessibilityPermission() async {
    try {
      final result = await _bridge.openAccessibilitySettings();
      // User must manually enable in settings, so we just refresh after delay
      if (result) {
        unawaited(Future.delayed(const Duration(seconds: 2)).then((_) => _refresh()));
      }
      return result;
    } catch (e) {
      debugPrint('Failed to open accessibility settings: $e');
      state = state.copyWith(error: 'Lỗi mở cài đặt trợ năng: ${e.toString()}');
      return false;
    }
  }

  /// Request call screening role.
  Future<bool> requestCallScreeningPermission() async {
    try {
      final result = await _bridge.requestCallScreeningRole();
      if (result) {
        await Future.delayed(const Duration(milliseconds: 500));
        await _refresh();
      }
      return result;
    } catch (e) {
      debugPrint('Failed to request call screening role: $e');
      state = state.copyWith(error: 'Lỗi xin vai trò sàng lọc cuộc gọi: ${e.toString()}');
      return false;
    }
  }

  /// Check if monitoring is active.
  Future<bool> checkMonitoringActive() async {
    try {
      return await _bridge.isMonitoringActive();
    } catch (e) {
      debugPrint('Failed to check monitoring status: $e');
      state = state.copyWith(error: 'Lỗi kiểm tra trạng thái giám sát: ${e.toString()}');
      return false;
    }
  }

  /// Request all missing permissions in sequence.
  Future<Map<String, bool>> requestAllPermissions() async {
    final results = <String, bool>{};

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
    _monitoringStateSub?.cancel();
    _monitoringStateSub = null;
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
