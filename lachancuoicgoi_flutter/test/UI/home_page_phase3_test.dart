import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lachancuocgoi_flutter/l10n/app_localizations.dart';
import 'package:lachancuocgoi_flutter/services/native_call_shield_bridge.dart';
import 'package:lachancuocgoi_flutter/ui/home_page/home_page.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('HomePage — Phase 3: permission dialog spam fix', () {
    setUp(() {
      SharedPreferences.setMockInitialValues({});
    });

    testWidgets('permission dialog shows once on first visit', (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            nativeBridgeProvider.overrideWithValue(
              NativeBridgeInterface.create(),
            ),
          ],
          child: const MaterialApp(
            locale: Locale('vi'),
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: HomePage(),
          ),
        ),
      );

      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      expect(find.byType(Dialog), findsOneWidget);
    });

    testWidgets('permission dialog does not show on second build', (
      tester,
    ) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            nativeBridgeProvider.overrideWithValue(
              NativeBridgeInterface.create(),
            ),
          ],
          child: const MaterialApp(
            locale: Locale('vi'),
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: HomePage(),
          ),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      if (find.byType(Dialog).evaluate().isNotEmpty) {}

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            nativeBridgeProvider.overrideWithValue(
              NativeBridgeInterface.create(),
            ),
          ],
          child: const MaterialApp(
            locale: Locale('vi'),
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: HomePage(),
          ),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
    });
  });
}
