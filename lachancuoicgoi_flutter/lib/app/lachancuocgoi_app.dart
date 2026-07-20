import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

import '../l10n/app_localizations.dart';
import '../data/app_database.dart';
import '../data/call_history_retention.dart';
import '../services/native_call_shield_bridge.dart';
import '../ui/monitoring_page/monitoring_controller.dart';
import '../ui/theme/app_theme.dart';
import 'native_call_event_coordinator.dart';
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
  CallHistoryRetention? _lastRetentionCleanup;
  String? _lastSyncedAnalysisMode;
  bool? _lastSyncedSpeakerphonePreference;
  late final NativeCallEventCoordinator _nativeCallEventCoordinator;
  bool _backgroundMonitoringSession = false;

  @override
  void initState() {
    super.initState();
    _nativeCallEventCoordinator = NativeCallEventCoordinator(
      events: ref.read(nativeBridgeProvider).callEventStream,
      onNavigateToMonitoring: (event) {
        if (!mounted) return;
        final router = ref.read(appRouterProvider);
        if (router.routeInformationProvider.value.uri.path == '/monitoring') {
          return;
        }
        router.go(
          '/monitoring',
          extra: <String, Object?>{
            if (event.maskedNumber != null) 'maskedNumber': event.maskedNumber,
          },
        );
      },
      onMonitoringAccepted: (event) {
        scheduleMicrotask(() {
          if (!mounted) return;
          _backgroundMonitoringSession = true;
          final controller = ref.read(monitoringControllerProvider.notifier);
          controller.init();
          controller.maskedNumber = event.maskedNumber;
          controller.initAfterFrame(nativeMonitoringAlreadyStarted: true);
        });
      },
      onSessionEnded: (event) {
        scheduleMicrotask(() {
          if (!mounted || !_backgroundMonitoringSession) return;
          _backgroundMonitoringSession = false;
          unawaited(
            ref.read(monitoringControllerProvider.notifier).endSession(),
          );
        });
      },
    )..start();
  }

  @override
  void dispose() {
    unawaited(_nativeCallEventCoordinator.dispose());
    super.dispose();
  }

  void _cleanupExpiredHistory(SettingsState settings) {
    if (_lastRetentionCleanup == settings.callHistoryRetention) return;
    _lastRetentionCleanup = settings.callHistoryRetention;
    unawaited(
      (() async {
        try {
          final database = await ref.read(appDatabaseFutureProvider.future);
          await ref
              .read(callHistoryRetentionServiceProvider)
              .cleanup(database, settings.callHistoryRetention);
        } on Exception catch (error) {
          debugPrint('History retention cleanup failed: $error');
        }
      })(),
    );
  }

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
    // Delay sync to allow native service to fully initialize, preventing timeouts
    unawaited(
      (() async {
        await Future<void>.delayed(const Duration(seconds: 2));
        await bridge.setCallScreeningBlockEnabled(
          settings.callScreeningBlockEnabled,
        );
        await bridge.setBlockedNumbers(settings.blockedNumbers);
      })(),
    );
  }

  /// Mirrors the persisted analysis mode into native SharedPreferences so the
  /// background monitoring overlay can show the active L1/L2/L3/L1L2L3 label.
  /// Runs on load and whenever the user changes the mode.
  void _syncAnalysisModeToNative(SettingsState settings) {
    final mode = settings.analysisMode.storageName;
    final speakerphone = settings.autoEnableSpeakerphone;
    if (_lastSyncedAnalysisMode == mode &&
        _lastSyncedSpeakerphonePreference == speakerphone) {
      return;
    }
    _lastSyncedAnalysisMode = mode;
    _lastSyncedSpeakerphonePreference = speakerphone;
    final bridge = ref.read(nativeBridgeProvider);
    // Delay sync to allow native service to fully initialize
    unawaited(
      (() async {
        await Future<void>.delayed(const Duration(seconds: 2));
        try {
          await bridge.syncAnalysisMode(mode);
          await bridge.syncAutoEnableSpeakerphone(speakerphone);
        } on Exception catch (e) {
          debugPrint('Failed to sync monitoring preferences to native: $e');
        }
      })(),
    );
  }

  @override
  Widget build(BuildContext context) {
    final settings = ref.watch(settingsControllerProvider);
    _nativeCallEventCoordinator.setReady(
      settings.isLoaded && settings.onboardingCompleted,
    );
    // Wait until persisted settings are loaded to avoid a theme flash
    // that causes Android Activity recreate (manifest android:theme mismatch).
    if (!settings.isLoaded) {
      return const MaterialApp(
        debugShowCheckedModeBanner: false,
        home: Scaffold(body: Center(child: CircularProgressIndicator())),
      );
    }
    _syncCallScreeningToNative();
    _syncAnalysisModeToNative(settings);
    _cleanupExpiredHistory(settings);
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
