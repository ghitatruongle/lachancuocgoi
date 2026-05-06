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
    return MaterialApp.router(
      debugShowCheckedModeBanner: false,
      title: 'Lá chắn cuộc gọi',
      theme: AppTheme.light,
      darkTheme: AppTheme.dark,
      themeMode: settings.isDarkTheme ? ThemeMode.dark : ThemeMode.light,
      routerConfig: ref.watch(appRouterProvider),
    );
  }
}
