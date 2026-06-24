import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'app/lachancuocgoi_app.dart';
import 'services/native_call_shield_bridge.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
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
  final nativeBridge = NativeCallShieldBridge.instance;
  runApp(
    ProviderScope(
      overrides: [nativeBridgeProvider.overrideWithValue(nativeBridge)],
      child: const LachancuocgoiApp(),
    ),
  );
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
