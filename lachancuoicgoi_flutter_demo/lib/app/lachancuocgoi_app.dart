import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../ui/theme/app_theme.dart';
import 'router.dart';
import 'settings_controller.dart';

class LachancuocgoiApp extends ConsumerWidget {
  const LachancuocgoiApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(settingsControllerProvider);
    // Wait until persisted settings are loaded to avoid a theme flash
    // that causes Android Activity recreate (manifest android:theme mismatch).
    if (!settings.isLoaded) {
      return const MaterialApp(
        debugShowCheckedModeBanner: false,
        home: Scaffold(body: Center(child: CircularProgressIndicator())),
      );
    }
    return MaterialApp.router(
      debugShowCheckedModeBanner: kDebugMode,
      title: 'Lá chắn cuộc gọi',
      theme: AppTheme.light,
      darkTheme: AppTheme.dark,
      themeMode: settings.isDarkTheme ? ThemeMode.dark : ThemeMode.light,
      routerConfig: ref.watch(appRouterProvider),
    );
  }
}
