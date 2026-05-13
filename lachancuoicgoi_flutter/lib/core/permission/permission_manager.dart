import 'dart:async';
import 'package:flutter/foundation.dart';
import '../native/native_call_shield_bridge.dart';

/// Quản lý trạng thái và yêu cầu các quyền hệ thống quan trọng
/// cho tính năng giám sát cuộc gọi và bảo vệ chống lừa đảo.
class PermissionManager extends ChangeNotifier {
  final NativeCallShieldBridge _bridge;

  bool _hasAccessibility = false;
  bool _hasOverlay = false;
  bool _hasNotification = false;
  bool _isChecking = false;

  PermissionManager(this._bridge) {
    // Lắng nghe sự kiện thay đổi quyền từ Native
    _bridge.permissionStream.listen(_onPermissionChanged);
  }

  bool get hasAccessibility => _hasAccessibility;
  bool get hasOverlay => _hasOverlay;
  bool get hasNotification => _hasNotification;
  bool get isChecking => _isChecking;
  bool get isAllGranted => _hasAccessibility && _hasOverlay && _hasNotification;

  /// Kiểm tra trạng thái quyền hiện tại từ Native
  Future<void> checkPermissions() async {
    _isChecking = true;
    notifyListeners();

    try {
      final status = await _bridge.getPermissionStatus();
      _updateStatus(status);
    } catch (e) {
      debugPrint('Lỗi khi kiểm tra quyền: $e');
      _isChecking = false;
      notifyListeners();
    }
  }

  /// Yêu cầu người dùng cấp quyền Accessibility
  Future<void> requestAccessibility() async {
    await _bridge.requestAccessibilityPermission();
    // Trạng thái sẽ được cập nhật qua stream
  }

  /// Yêu cầu người dùng cấp quyền Overlay (Draw over other apps)
  Future<void> requestOverlay() async {
    await _bridge.requestOverlayPermission();
    // Trạng thái sẽ được cập nhật qua stream
  }

  /// Yêu cầu quyền thông báo (thường đã được cấp khi cài đặt, nhưng cần kiểm tra)
  Future<void> requestNotification() async {
    // Trên Android 13+, cần request runtime permission
    await _bridge.requestNotificationPermission();
  }

  void _onPermissionChanged(Map<String, dynamic> status) {
    _updateStatus(status);
  }

  void _updateStatus(Map<String, dynamic> status) {
    final oldAcc = _hasAccessibility;
    final oldOvl = _hasOverlay;
    final oldNoti = _hasNotification;

    _hasAccessibility = status['accessibility'] ?? false;
    _hasOverlay = status['overlay'] ?? false;
    _hasNotification = status['notification'] ?? false;
    _isChecking = false;

    if (oldAcc != _hasAccessibility || 
        oldOvl != _hasOverlay || 
        oldNoti != _hasNotification) {
      notifyListeners();
    }
  }

  @override
  void dispose() {
    // Stream được quản lý bởi bridge, không cần cancel ở đây nếu bridge là singleton
    super.dispose();
  }
}
