import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:lachancuocgoi_flutter/app/settings_controller.dart';
import 'package:lachancuocgoi_flutter/analysis/analysis_mode.dart';
import 'package:lachancuocgoi_flutter/services/developer_mode_manager.dart';
import 'package:lachancuocgoi_flutter/ui/widgets/app_action_buttons.dart';

/// Fake settings controller for testing SettingsActionButton (which opens
/// SettingsDialog, a ConsumerStatefulWidget).
class _FakeSettingsController extends Notifier<SettingsState>
    implements SettingsController {
  @override
  SettingsState build() => const SettingsState(
    isDarkTheme: false,
    followSystemTheme: false,
    analysisMode: AnalysisMode.gDetection,
    audioBoost: false,
    autoEnableSpeakerphone: false,
    creatorAudioCapture: false,
    isLoaded: true,
  );

  @override
  Future<void> update(SettingsState next) async {
    state = next;
  }

  @override
  bool get loaded => true;

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

/// Fake dev mode controller.
class _FakeDevModeController extends Notifier<DeveloperModeState>
    implements DeveloperModeController {
  @override
  DeveloperModeState build() => const DeveloperModeState();

  @override
  DeveloperTapResult onTitleTap() => DeveloperTapResult.nothing;

  @override
  bool verifyPassword(String input) => false;

  @override
  Future<void> activate() async {}

  @override
  Future<void> deactivate() async {}

  @override
  bool get isActive => false;

  @override
  int get remainingSeconds => -1;

  @override
  int get expiresAtEpochMs => 0;

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  Widget wrapWithProviders(Widget child) {
    return ProviderScope(
      overrides: [
        settingsControllerProvider.overrideWith(
          () => _FakeSettingsController(),
        ),
        developerModeProvider.overrideWith(() => _FakeDevModeController()),
      ],
      child: MaterialApp(home: Scaffold(body: child)),
    );
  }

  group('SettingsActionButton', () {
    testWidgets('renders settings icon', (tester) async {
      await tester.pumpWidget(wrapWithProviders(const SettingsActionButton()));

      expect(find.byIcon(Icons.settings), findsOneWidget);
    });

    testWidgets('has tooltip', (tester) async {
      await tester.pumpWidget(wrapWithProviders(const SettingsActionButton()));

      final semantics = tester.getSemantics(find.byIcon(Icons.settings));
      expect(semantics.tooltip, 'Cài đặt');
    });

    testWidgets('opens SettingsDialog when tapped', (tester) async {
      await tester.pumpWidget(wrapWithProviders(const SettingsActionButton()));

      await tester.tap(find.byIcon(Icons.settings));
      await tester.pumpAndSettle();

      expect(find.byType(Dialog), findsOneWidget);
    });
  });

  group('HomeBackButton', () {
    testWidgets('renders back arrow icon', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(appBar: AppBar(leading: const HomeBackButton())),
        ),
      );

      expect(find.byIcon(Icons.arrow_back), findsOneWidget);
    });

    testWidgets('has tooltip', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(appBar: AppBar(leading: const HomeBackButton())),
        ),
      );

      final semantics = tester.getSemantics(find.byIcon(Icons.arrow_back));
      expect(semantics.tooltip, 'Về trang chính');
    });

    testWidgets('navigates to / when tapped', (tester) async {
      final goRouter = GoRouter(
        initialLocation: '/other',
        routes: [
          GoRoute(path: '/', builder: (_, __) => const Text('Home')),
          GoRoute(
            path: '/other',
            builder: (_, __) =>
                Scaffold(appBar: AppBar(leading: const HomeBackButton())),
          ),
        ],
      );

      await tester.pumpWidget(MaterialApp.router(routerConfig: goRouter));
      expect(find.text('Home'), findsNothing);

      await tester.tap(find.byIcon(Icons.arrow_back));
      await tester.pumpAndSettle();

      expect(find.text('Home'), findsOneWidget);
    });
  });
}
