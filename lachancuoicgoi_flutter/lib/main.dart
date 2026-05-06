import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app/lachancuocgoi_app.dart';
import 'data/app_database.dart';
import 'services/native_call_shield_bridge.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final database = await AppDatabase.open();
  final nativeBridge = NativeCallShieldBridge.instance;
  runApp(
    ProviderScope(
      overrides: [
        appDatabaseProvider.overrideWithValue(database),
        nativeBridgeProvider.overrideWithValue(nativeBridge),
      ],
      child: const LachancuocgoiApp(),
    ),
  );
}
