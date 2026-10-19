import 'dart:async';
import 'package:flutter/services.dart';

/// Method names shared with Kotlin [NativeBridgeChannels] / MainActivity.
///
/// Prefer these constants over raw strings when adding bridge calls.
abstract final class NativeBridgeMethods {
  static const checkOverlayPermission = 'checkOverlayPermission';
  static const checkCallScreeningStatus = 'checkCallScreeningStatus';
  static const startMonitoring = 'startMonitoring';
  static const stopMonitoring = 'stopMonitoring';
  static const getPermissionsStatus = 'getPermissionsStatus';
}

/// Centralized, Type-Safe MethodChannel contract wrapper for Android Native interop.
///
/// Prevents unhandled [PlatformException] or [TypeError] crashes across the
/// Flutter-Kotlin boundary.
class NativeBridgeContract {
  NativeBridgeContract({MethodChannel? channel})
    : _channel =
          channel ?? const MethodChannel('org.lachancuocgoi/native_service');

  final MethodChannel _channel;

  /// Invokes a native method with strict type-checking and fallback handling.
  Future<T?> invokeTypeSafeMethod<T>(
    String method, [
    dynamic arguments,
    T? fallbackValue,
  ]) async {
    try {
      final result = await _channel.invokeMethod<dynamic>(method, arguments);
      if (result == null) return fallbackValue;
      if (result is T) return result;
      return fallbackValue;
    } on PlatformException catch (_) {
      return fallbackValue;
    } on MissingPluginException catch (_) {
      return fallbackValue;
    } on Object catch (_) {
      return fallbackValue;
    }
  }

  /// Checks whether native overlay permission is granted on Android.
  Future<bool> checkOverlayPermission() async {
    final granted = await invokeTypeSafeMethod<bool>(
      NativeBridgeMethods.checkOverlayPermission,
      null,
      false,
    );
    return granted ?? false;
  }

  /// Checks whether CallScreeningService is active on Android.
  Future<bool> checkCallScreeningStatus() async {
    final active = await invokeTypeSafeMethod<bool>(
      NativeBridgeMethods.checkCallScreeningStatus,
      null,
      false,
    );
    return active ?? false;
  }
}
