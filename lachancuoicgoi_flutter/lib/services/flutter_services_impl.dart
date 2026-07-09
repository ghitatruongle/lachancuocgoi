import 'dart:typed_data';
import 'package:flutter/services.dart' show rootBundle;
import '../core/logger.dart';
import '../core/system_logger.dart';
import '../core/asset_loader.dart';

/// Legacy [AppLogger] implementation that delegates to [SystemLogger].
///
/// This class is kept for backward compatibility. New code should use
/// [SystemLogger.instance] directly or inject [AppLogger] via Riverpod.
class FlutterLogger implements AppLogger {
  const FlutterLogger();

  @override
  void debug(String message) {
    SystemLogger.instance.debug(message);
  }

  @override
  void info(String message) {
    SystemLogger.instance.info(message);
  }

  @override
  void warning(String message, [Object? error, StackTrace? stackTrace]) {
    SystemLogger.instance.warning(message, error, stackTrace);
  }

  @override
  void error(String message, [Object? error, StackTrace? stackTrace]) {
    SystemLogger.instance.error(message, error, stackTrace);
  }
}

class FlutterAssetLoader implements AssetLoader {
  const FlutterAssetLoader();

  @override
  Future<String> loadString(String key) {
    return rootBundle.loadString(key);
  }

  @override
  Future<ByteData> load(String key) {
    return rootBundle.load(key);
  }
}
