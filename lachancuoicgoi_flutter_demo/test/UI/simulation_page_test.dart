import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import 'package:lachancuocgoi_flutter/ui/simulation_page/simulation_page.dart';

import 'test_helpers.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  Widget buildPage() {
    return ProviderScope(
      overrides: [bridgeOverride(), settingsOverride(), devModeOverride()],
      child: MaterialApp.router(
        routerConfig: GoRouter(
          initialLocation: '/simulation',
          routes: [
            GoRoute(
              path: '/',
              builder: (_, __) => const Scaffold(body: Text('Home')),
            ),
            GoRoute(
              path: '/simulation',
              builder: (_, __) => const SimulationPage(),
            ),
          ],
        ),
      ),
    );
  }

  group('SimulationPage', () {
    testWidgets('renders app bar title', (tester) async {
      await tester.pumpWidget(buildPage());
      await tester.pumpAndSettle();

      expect(find.text('Tình huống giả lập'), findsOneWidget);
    });

    testWidgets('renders search bar with hint text', (tester) async {
      await tester.pumpWidget(buildPage());
      await tester.pumpAndSettle();

      expect(find.byType(TextField), findsOneWidget);
      expect(find.text('Tìm kịch bản...'), findsOneWidget);
    });

    testWidgets('back button is present', (tester) async {
      await tester.pumpWidget(buildPage());
      await tester.pumpAndSettle();

      expect(find.byIcon(Icons.arrow_back), findsOneWidget);
    });

    testWidgets('page renders without crash', (tester) async {
      await tester.pumpWidget(buildPage());
      // Wait for addPostFrameCallback + async loadData
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));
      await tester.pumpAndSettle();

      // Page should render without crashing
      expect(find.byType(SimulationPage), findsOneWidget);
    });
  });
}
