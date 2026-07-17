import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

import '../l10n/app_localizations.dart';
import '../services/native_call_shield_bridge.dart';
import '../ui/theme/app_theme.dart';
import 'router.dart';
import 'settings_controller.dart';

// Phase 2 (P2-6): AppLocalizations delegate reference, kept at top-level so the
// generated localization code is tree-shaken only when truly unused.
const _localizationsDelegates = <LocalizationsDelegate<dynamic>>[
  ...AppLocalizations.localizationsDelegates,
  GlobalMaterialLocalizations.delegate,
  GlobalWidgetsLocalizations.delegate,
  GlobalCupertinoLocalizations.delegate,
];

class LachancuocgoiApp extends ConsumerStatefulWidget {
  const LachancuocgoiApp({super.key});

  @override
  ConsumerState<LachancuocgoiApp> createState() => _LachancuocgoiAppState();
}

class _LachancuocgoiAppState extends ConsumerState<LachancuocgoiApp> {
  bool _callScreeningSynced = false;

  /// BUG 2 fix (P2-4 review): sync Flutter-persisted call screening state
  /// into native SharedPreferences so CallScreeningService (which runs in a
  /// separate background process) sees the correct blocklist even after app
  /// reinstall / cache clear. Without this, the Flutter UI shows "enabled"
  /// but native never sees the list until the user re-toggles manually.
  void _syncCallScreeningToNative() {
    if (_callScreeningSynced) return;
    final settings = ref.read(settingsControllerProvider);
    if (!settings.isLoaded) return;
    _callScreeningSynced = true;

    final bridge = ref.read(nativeBridgeProvider);
    unawaited(
      (() async {
        await bridge.setCallScreeningBlockEnabled(
          settings.callScreeningBlockEnabled,
        );
        await bridge.setBlockedNumbers(settings.blockedNumbers);
      })(),
    );
  }

  @override
  Widget build(BuildContext context) {
    final settings = ref.watch(settingsControllerProvider);
    // Wait until persisted settings are loaded to avoid a theme flash
    // that causes Android Activity recreate (manifest android:theme mismatch).
    if (!settings.isLoaded) {
      return const MaterialApp(
        debugShowCheckedModeBanner: false,
        home: Scaffold(body: Center(child: CircularProgressIndicator())),
      );
    }
    _syncCallScreeningToNative();
    final l10n = AppLocalizations.of(context);
    return MaterialApp.router(
      debugShowCheckedModeBanner: kDebugMode,
      onGenerateTitle: (context) => l10n?.appTitle ?? 'Lá chắn cuộc gọi',
      theme: AppTheme.light,
      darkTheme: AppTheme.dark,
      themeMode: settings.followSystemTheme
          ? ThemeMode.system
          : (settings.isDarkTheme ? ThemeMode.dark : ThemeMode.light),
      localizationsDelegates: _localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      routerConfig: ref.watch(appRouterProvider),
    );
  }
}
