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

final appRouterProvider = Provider<GoRouter>((ref) {
  return GoRouter(
    initialLocation: '/',
    debugLogDiagnostics: kDebugMode,
    redirect: (context, state) {
      // Allow user to skip onboarding and access home page
      // Permission checks will happen on-demand (when features need them)
      return null;
    },
    routes: [
      GoRoute(
        path: '/onboarding',
        builder: (context, state) => const OnboardingPage(),
      ),
      GoRoute(path: '/', builder: (context, state) => const HomePage()),
      GoRoute(
          path: '/simulation',
          builder: (context, state) => const SimulationPage()),
      GoRoute(
        path: '/monitoring',
        builder: (context, state) {
          final extra = _monitoringRouteExtra(state.extra);
          return MonitoringPage(
            simulatedScenarioTitle: _stringFromExtra(extra, 'scenarioTitle'),
            simulatedTranscript: _stringFromExtra(extra, 'scenarioTranscript'),
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
          path: '/history', builder: (context, state) => const HistoryPage()),
      GoRoute(
          path: '/tips_lesson',
          builder: (context, state) => const TipsLessonPage()),
    ],
  );
});
