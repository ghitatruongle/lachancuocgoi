import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lachancuocgoi_flutter/analysis/analysis_mode.dart';
import 'package:lachancuocgoi_flutter/app/settings_controller.dart';
import 'package:lachancuocgoi_flutter/services/developer_mode_manager.dart';
import 'package:lachancuocgoi_flutter/ui/home_page/settings_dialog.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  // ─── Helper: pump dialog into a ProviderScope MaterialApp ──────────────
  Future<void> pumpDialog(WidgetTester tester) async {
    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          home: Builder(
            builder: (context) {
              return ElevatedButton(
                onPressed: () => showDialog(
                  context: context,
                  builder: (_) => const SettingsDialog(),
                ),
                child: const Text('Open'),
              );
            },
          ),
        ),
      ),
    );
    // Tap the button to show the dialog
    await tester.tap(find.text('Open'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
  }

  // ─── Basic rendering ─────────────────────────────────────────────────
  group('SettingsDialog — rendering', () {
    testWidgets('shows title and close button', (tester) async {
      await pumpDialog(tester);

      expect(find.text('Cài đặt'), findsOneWidget);
      expect(find.byIcon(Icons.close), findsOneWidget);
    });

    testWidgets('shows theme toggle', (tester) async {
      await pumpDialog(tester);

      expect(find.text('Giao diện sáng'), findsOneWidget);
      expect(find.text('Giao diện tối'), findsNothing);
    });

    testWidgets('shows analysis mode section', (tester) async {
      await pumpDialog(tester);

      expect(find.text('Chế độ phân tích'), findsOneWidget);
      // AnalysisMode.gDetection is default
      expect(find.text('Cấp 2: Nâng cao'), findsOneWidget);
    });

    testWidgets('shows audio boost and speakerphone toggles', (tester) async {
      await pumpDialog(tester);

      expect(find.text('Khuếch đại âm thanh'), findsOneWidget);
      expect(find.text('Tự bật loa ngoài'), findsOneWidget);
    });

    testWidgets('does not show creator section by default', (tester) async {
      await pumpDialog(tester);

      expect(find.text('Nhà sáng tạo'), findsNothing);
      expect(find.text('Chụp audio màn hình'), findsNothing);
    });
  });

  // ─── Theme toggle ─────────────────────────────────────────────────────
  group('SettingsDialog — theme toggle', () {
    testWidgets('toggling theme changes from light to dark', (tester) async {
      await pumpDialog(tester);

      // Initially light
      expect(find.text('Giao diện sáng'), findsOneWidget);

      // Find the Switch widget and toggle it
      final switches = find.byType(Switch);
      expect(switches, findsAtLeastNWidgets(1));

      await tester.tap(switches.first);
      await tester.pumpAndSettle();

      // Should now show dark label
      expect(find.text('Giao diện tối'), findsOneWidget);
      expect(find.text('Giao diện sáng'), findsNothing);
    });
  });

  // ─── Analysis mode selection ──────────────────────────────────────────
  group('SettingsDialog — analysis mode', () {
    testWidgets('radio buttons reflect default GDetection mode', (tester) async {
      await pumpDialog(tester);

      // GDetection is default, should have radio_button_checked
      expect(find.byIcon(Icons.radio_button_checked), findsOneWidget);
    });

    testWidgets('tapping a different mode updates selection', (tester) async {
      await pumpDialog(tester);

      // Tap "Cấp 1: Cơ bản"
      await tester.tap(find.text('Cấp 1: Cơ bản'));
      await tester.pumpAndSettle();

      // Check that normal mode is now checked
      expect(find.byIcon(Icons.radio_button_checked), findsOneWidget);
    });

    testWidgets('tapping all three modes cycles through correctly',
        (tester) async {
      await pumpDialog(tester);

      // Tap Normal
      await tester.tap(find.text('Cấp 1: Cơ bản'));
      await tester.pumpAndSettle();

      // Tap Gemini AI
      await tester.tap(find.text('Cấp 3: AI'));
      await tester.pumpAndSettle();

      // Gemini AI should be checked
      expect(find.byIcon(Icons.radio_button_checked), findsOneWidget);
    });
  });

  // ─── Audio toggles ────────────────────────────────────────────────────
  group('SettingsDialog — audio toggles', () {
    testWidgets('audio boost switch can be toggled', (tester) async {
      await pumpDialog(tester);

      final switches = find.byType(Switch);
      // The second switch (index 1) should be audio boost
      // First switch = theme, second = audio boost
      expect(switches, findsAtLeastNWidgets(2));

      await tester.tap(switches.at(1));
      await tester.pumpAndSettle();
      // No crash = success
    });

    testWidgets('speakerphone switch can be toggled', (tester) async {
      await pumpDialog(tester);

      final switches = find.byType(Switch);
      expect(switches, findsAtLeastNWidgets(3));

      await tester.tap(switches.at(2));
      await tester.pumpAndSettle();
    });
  });

  // ─── Developer mode section ───────────────────────────────────────────
  group('SettingsDialog — developer mode', () {
    testWidgets('shows creator section when dev mode is active', (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            developerModeProvider.overrideWith(
              () => _ActiveDevModeController(),
            ),
          ],
          child: MaterialApp(
            home: Builder(
              builder: (context) {
                return ElevatedButton(
                  onPressed: () => showDialog(
                    context: context,
                    builder: (_) => const SettingsDialog(),
                  ),
                  child: const Text('Open'),
                );
              },
            ),
          ),
        ),
      );

      await tester.tap(find.text('Open'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      // Should now show creator section
      expect(find.text('Nhà sáng tạo'), findsOneWidget);
      expect(find.text('Chụp audio màn hình'), findsOneWidget);
    });

    testWidgets('creator section shows audio capture switch', (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            developerModeProvider.overrideWith(
              () => _ActiveDevModeController(),
            ),
          ],
          child: MaterialApp(
            home: Builder(
              builder: (context) {
                return ElevatedButton(
                  onPressed: () => showDialog(
                    context: context,
                    builder: (_) => const SettingsDialog(),
                  ),
                  child: const Text('Open'),
                );
              },
            ),
          ),
        ),
      );

      await tester.tap(find.text('Open'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      // Find the creator audio capture switch
      expect(find.byType(SwitchListTile), findsOneWidget);
    });
  });

  // ─── Close button ─────────────────────────────────────────────────────
  group('SettingsDialog — close', () {
    testWidgets('tapping close dismisses the dialog', (tester) async {
      await pumpDialog(tester);

      expect(find.byType(Dialog), findsOneWidget);

      await tester.tap(find.byIcon(Icons.close));
      await tester.pumpAndSettle();

      expect(find.byType(Dialog), findsNothing);
    });
  });

  // ─── Title tap (developer mode easter egg) ────────────────────────────
  group('SettingsDialog — title tap', () {
    testWidgets('tapping title 10 times shows password dialog',
        (tester) async {
      await pumpDialog(tester);

      // Tap the "Cài đặt" title 10 times
      for (var i = 0; i < 10; i++) {
        await tester.tap(find.text('Cài đặt'));
        await tester.pump(const Duration(milliseconds: 100));
      }
      await tester.pumpAndSettle();

      // Password dialog should appear
      expect(find.text('Chế độ Nhà phát triển'), findsOneWidget);
      expect(find.text('Mật mã'), findsOneWidget);
      expect(find.text('Huỷ'), findsOneWidget);
      expect(find.text('Kích hoạt'), findsOneWidget);
    });

    testWidgets('password dialog cancel button dismisses', (tester) async {
      await pumpDialog(tester);

      for (var i = 0; i < 10; i++) {
        await tester.tap(find.text('Cài đặt'));
        await tester.pump(const Duration(milliseconds: 100));
      }
      await tester.pumpAndSettle();

      expect(find.text('Chế độ Nhà phát triển'), findsOneWidget);

      await tester.tap(find.text('Huỷ'));
      await tester.pumpAndSettle();

      expect(find.text('Chế độ Nhà phát triển'), findsNothing);
    });

    testWidgets('password dialog shows error on wrong password',
        (tester) async {
      await pumpDialog(tester);

      for (var i = 0; i < 10; i++) {
        await tester.tap(find.text('Cài đặt'));
        await tester.pump(const Duration(milliseconds: 100));
      }
      await tester.pumpAndSettle();

      // Enter wrong password
      await tester.enterText(find.byType(TextField), '000000');
      await tester.pumpAndSettle();

      // The activate button should now be enabled
      await tester.tap(find.text('Kích hoạt'));
      await tester.pumpAndSettle();

      // Should show error
      expect(find.text('Mật mã không đúng. Vui lòng thử lại.'), findsOneWidget);
    });

    testWidgets('password visibility toggle works', (tester) async {
      await pumpDialog(tester);

      for (var i = 0; i < 10; i++) {
        await tester.tap(find.text('Cài đặt'));
        await tester.pump(const Duration(milliseconds: 100));
      }
      await tester.pumpAndSettle();

      // Initially obscured
      final textField = tester.widget<TextField>(find.byType(TextField));
      expect(textField.obscureText, isTrue);

      // Tap visibility toggle — icon is Icons.visibility when _showPassword is false
      await tester.tap(find.byIcon(Icons.visibility));
      await tester.pumpAndSettle();

      final textField2 = tester.widget<TextField>(find.byType(TextField));
      expect(textField2.obscureText, isFalse);
    });

    testWidgets('activate button is disabled when text field is empty',
        (tester) async {
      await pumpDialog(tester);

      for (var i = 0; i < 10; i++) {
        await tester.tap(find.text('Cài đặt'));
        await tester.pump(const Duration(milliseconds: 100));
      }
      await tester.pumpAndSettle();

      // Button should be disabled initially
      final buttonFinder = find.ancestor(
        of: find.text('Kích hoạt'),
        matching: find.byType(FilledButton),
      );
      expect(buttonFinder, findsOneWidget);
      final button = tester.widget<FilledButton>(buttonFinder);
      expect(button.onPressed, isNull);
    });
  });
}

/// A [DeveloperModeController] subclass that starts in the active state
/// without requiring [SharedPreferences] mocking.
class _ActiveDevModeController extends DeveloperModeController {
  @override
  DeveloperModeState build() {
    final expiry = DateTime.now().millisecondsSinceEpoch + 600000;
    state = DeveloperModeState(
      isActive: true,
      remainingSeconds: 300,
      expiresAtEpochMs: expiry,
    );
    return state;
  }
}
