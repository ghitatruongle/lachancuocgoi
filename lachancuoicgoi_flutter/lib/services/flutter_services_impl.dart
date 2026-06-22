import 'dart:typed_data';
import 'package:flutter/foundation.dart' show debugPrint;
import 'package:flutter/services.dart' show rootBundle;
import '../core/logger.dart';
import '../core/asset_loader.dart';

class FlutterLogger implements AppLogger {
  const FlutterLogger();

  @override
  void debug(String message) {
    debugPrint('[DEBUG] $message');
  }

  @override
  void info(String message) {
    debugPrint('[INFO] $message');
  }

  @override
  void warning(String message, [Object? error, StackTrace? stackTrace]) {
    debugPrint('[WARN] $message${error != null ? ' | Error: $error' : ''}');
    if (stackTrace != null) {
      debugPrint(stackTrace.toString());
    }
  }

  @override
  void error(String message, [Object? error, StackTrace? stackTrace]) {
    debugPrint('[ERROR] $message${error != null ? ' | Error: $error' : ''}');
    if (stackTrace != null) {
      debugPrint(stackTrace.toString());
    }
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

