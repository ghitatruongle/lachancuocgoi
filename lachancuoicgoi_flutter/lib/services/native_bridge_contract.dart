import 'dart:async';
import 'package:flutter/services.dart';

abstract final class NativeBridgeMethods {
  static const checkOverlayPermission = 'checkOverlayPermission';
  static const checkCallScreeningStatus = 'checkCallScreeningStatus';
  static const startMonitoring = 'startMonitoring';
  static const stopMonitoring = 'stopMonitoring';
  static const getPermissionsStatus = 'getPermissionsStatus';
}

class NativeBridgeContract {
  NativeBridgeContract({MethodChannel? channel})
    : _channel =
          channel ?? const MethodChannel('org.lachancuocgoi/native_service');

  final MethodChannel _channel;

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

  Future<bool> checkOverlayPermission() async {
    final granted = await invokeTypeSafeMethod<bool>(
      NativeBridgeMethods.checkOverlayPermission,
      null,
      false,
    );
    return granted ?? false;
  }

  Future<bool> checkCallScreeningStatus() async {
    final active = await invokeTypeSafeMethod<bool>(
      NativeBridgeMethods.checkCallScreeningStatus,
      null,
      false,
    );
    return active ?? false;
  }
}
