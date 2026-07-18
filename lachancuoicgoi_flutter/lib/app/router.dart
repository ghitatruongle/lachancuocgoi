import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../ui/history_page/history_page.dart';
import '../ui/home_page/home_page.dart';
import '../ui/monitoring_page/monitoring_page.dart';
import '../ui/onboarding/onboarding_page.dart';
import '../ui/result_page/result_page.dart';
import '../ui/simulation_page/simulation_page.dart';
import '../ui/tips_lesson_page/tips_lesson_page.dart';
import 'settings_controller.dart';

/// Safe [GoRouteState.extra] for `/monitoring` (expects string keys).
Map<String, dynamic>? _monitoringRouteExtra(Object? extra) {
  if (extra == null) return null;
  if (extra is Map<String, dynamic>) return extra;
  if (extra is Map) {
    try {
      return Map<String, dynamic>.from(
        extra.map((k, v) => MapEntry(k.toString(), v)),
      );
    } on Object {
      return null;
    }
  }
  return null;
}

String? _stringFromExtra(Map<String, dynamic>? map, String key) {
  if (map == null) return null;
  final v = map[key];
  if (v is String) return v;
  if (v != null) return v.toString();
  return null;
}

List<Map<String, dynamic>>? _scriptLinesFromExtra(Map<String, dynamic>? map) {
  if (map == null) return null;
  final v = map['scenarioScriptLines'];
  if (v is List) {
    return v.map((e) {
      if (e is Map<String, dynamic>) return e;
      if (e is Map) return Map<String, dynamic>.from(e);
      return <String, dynamic>{};
    }).toList();
  }
  return null;
}

/// Pure first-run redirect policy, kept separate for deterministic tests.
String? onboardingRedirect(SettingsState settings, String matchedLocation) {
  return _onboardingRedirectValues(
    isLoaded: settings.isLoaded,
    onboardingCompleted: settings.onboardingCompleted,
    matchedLocation: matchedLocation,
  );
}

String? _onboardingRedirectValues({
  required bool isLoaded,
  required bool onboardingCompleted,
  required String matchedLocation,
}) {
  if (!isLoaded) return null;
  final isOnboarding = matchedLocation == '/onboarding';
  if (!onboardingCompleted) {
    return isOnboarding ? null : '/onboarding';
  }
  if (isOnboarding) return '/';
  return null;
}

final appRouterProvider = Provider<GoRouter>((ref) {
  // Theme/audio/privacy changes must not recreate the router and reset the
  // current navigation stack. Only first-run routing state is relevant here.
  final routingState = ref.watch(
    settingsControllerProvider.select(
      (settings) => (settings.isLoaded, settings.onboardingCompleted),
    ),
  );
  final router = GoRouter(
    initialLocation: '/',
    debugLogDiagnostics: kDebugMode,
    redirect: (context, state) {
      return _onboardingRedirectValues(
        isLoaded: routingState.$1,
        onboardingCompleted: routingState.$2,
        matchedLocation: state.matchedLocation,
      );
    },
    routes: [
      GoRoute(
        path: '/onboarding',
        builder: (context, state) => const OnboardingPage(),
      ),
      GoRoute(path: '/', builder: (context, state) => const HomePage()),
      GoRoute(
        path: '/simulation',
        builder: (context, state) => const SimulationPage(),
      ),
      GoRoute(
        path: '/monitoring',
        builder: (context, state) {
          final extra = _monitoringRouteExtra(state.extra);
          return MonitoringPage(
            simulatedScenarioTitle: _stringFromExtra(extra, 'scenarioTitle'),
            simulatedTranscript: _stringFromExtra(extra, 'scenarioTranscript'),
            simulatedScriptLines: _scriptLinesFromExtra(extra),
            initialMaskedNumber: _stringFromExtra(extra, 'maskedNumber'),
          );
        },
      ),
      GoRoute(
        path: '/result/:historyId',
        builder: (context, state) => ResultPage(
          historyId: int.tryParse(state.pathParameters['historyId'] ?? '') ?? 0,
        ),
      ),
      GoRoute(
        path: '/history',
        builder: (context, state) => const HistoryPage(),
      ),
      GoRoute(
        path: '/tips_lesson',
        builder: (context, state) => const TipsLessonPage(),
      ),
    ],
  );
  ref.onDispose(router.dispose);
  return router;
});
