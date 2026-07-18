import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'app/lachancuocgoi_app.dart';
import 'core/system_logger.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  _installGlobalErrorHandlers();
  // Bug #1 fix: use defaultTargetPlatform instead of dart:io Platform
  // to avoid importing dart:io which is unavailable on Web.
  if (!kIsWeb &&
      (defaultTargetPlatform == TargetPlatform.windows ||
          defaultTargetPlatform == TargetPlatform.linux ||
          defaultTargetPlatform == TargetPlatform.macOS)) {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  }
  if (kDebugMode) {
    debugPrint(
      'Lachancuocgoi: DEBUG build — dùng flutter run (không phải release) để xem log đầy đủ.',
    );
  }
  // Database opens lazily via appDatabaseFutureProvider on first access.
  // The provider uses NativeBridgeInterface.create() as the single source of
  // truth for selecting the Android bridge or the cross-platform simulator.
  runApp(const ProviderScope(child: LachancuocgoiApp()));
  // Sprint 2 (B2): pre-warm SharedPreferences AFTER runApp so the first
  // frame isn't blocked on disk I/O. SettingsController.build() also
  // calls SharedPreferences.getInstance() — when the singleton is
  // already warm, that returns instantly.
  unawaited(
    Future.microtask(() async {
      try {
        await SharedPreferences.getInstance();
      } on Exception catch (e) {
        debugPrint('Pre-warm SharedPreferences failed: $e');
      }
    }),
  );
}

void _installGlobalErrorHandlers() {
  final logger = SystemLogger.instance;
  final previousFlutterHandler = FlutterError.onError;
  FlutterError.onError = (details) {
    logger.error(
      'Unhandled Flutter framework error',
      details.exception,
      details.stack,
    );
    if (previousFlutterHandler != null) {
      previousFlutterHandler(details);
    } else {
      FlutterError.presentError(details);
    }
  };

  final dispatcher = PlatformDispatcher.instance;
  final previousPlatformHandler = dispatcher.onError;
  dispatcher.onError = (error, stackTrace) {
    logger.error('Unhandled asynchronous error', error, stackTrace);
    return previousPlatformHandler?.call(error, stackTrace) ?? true;
  };
}
