import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../ui/history_page/history_page.dart';
import '../ui/home_page/home_page.dart';
import '../ui/monitoring_page/monitoring_page.dart';
import '../ui/result_page/result_page.dart';
import '../ui/simulation_page/simulation_page.dart';
import '../ui/tips_lesson_page/tips_lesson_page.dart';

final appRouterProvider = Provider<GoRouter>((ref) {
  return GoRouter(
    initialLocation: '/',
    routes: [
      GoRoute(path: '/', builder: (context, state) => const HomePage()),
      GoRoute(
          path: '/simulation',
          builder: (context, state) => const SimulationPage()),
      GoRoute(
        path: '/monitoring',
        builder: (context, state) {
          final extra = state.extra as Map<String, dynamic>?;
          return MonitoringPage(
            simulatedScenarioTitle: extra?['scenarioTitle'] as String?,
            simulatedTranscript: extra?['scenarioTranscript'] as String?,
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
