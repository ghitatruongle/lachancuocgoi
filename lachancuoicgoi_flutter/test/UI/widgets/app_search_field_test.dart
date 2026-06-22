import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lachancuocgoi_flutter/ui/widgets/app_search_field.dart';

void main() {
  Widget wrap(Widget child) => MaterialApp(home: Scaffold(body: child));

  group('AppSearchField', () {
    testWidgets('renders with hint text', (tester) async {
      await tester.pumpWidget(
        wrap(const AppSearchField(hintText: 'Tìm kiếm...')),
      );

      expect(find.text('Tìm kiếm...'), findsOneWidget);
      expect(find.byIcon(Icons.search), findsOneWidget);
    });

    testWidgets('calls onChanged when typing', (tester) async {
      String? changedValue;
      await tester.pumpWidget(
        wrap(AppSearchField(onChanged: (v) => changedValue = v)),
      );

      await tester.enterText(find.byType(TextField), 'hello');
      expect(changedValue, 'hello');
    });

    testWidgets('shows clear button when controller has text', (tester) async {
      final controller = TextEditingController(text: 'test');
      await tester.pumpWidget(wrap(AppSearchField(controller: controller)));

      expect(find.byIcon(Icons.close), findsOneWidget);
    });

    testWidgets('clear button clears controller and calls onChanged', (
      tester,
    ) async {
      final controller = TextEditingController(text: 'test');
      String? changedValue;
      await tester.pumpWidget(
        wrap(
          AppSearchField(
            controller: controller,
            onChanged: (v) => changedValue = v,
          ),
        ),
      );

      await tester.tap(find.byIcon(Icons.close));
      await tester.pump();

      expect(controller.text, isEmpty);
      expect(changedValue, '');
    });

    testWidgets('shows clear button when value is non-empty', (tester) async {
      await tester.pumpWidget(
        wrap(AppSearchField(value: 'query', onClear: () {})),
      );

      expect(find.byIcon(Icons.close), findsOneWidget);
    });

    testWidgets('hides clear button when empty', (tester) async {
      await tester.pumpWidget(wrap(const AppSearchField(value: '')));

      expect(find.byIcon(Icons.close), findsNothing);
    });

    testWidgets('calls onSubmitted when Enter is pressed', (tester) async {
      String? submittedValue;
      await tester.pumpWidget(
        wrap(AppSearchField(onSubmitted: (v) => submittedValue = v)),
      );

      await tester.enterText(find.byType(TextField), 'search');
      await tester.testTextInput.receiveAction(TextInputAction.done);
      await tester.pump();

      expect(submittedValue, 'search');
    });

    testWidgets('calls onClear callback when provided', (tester) async {
      var clearCalled = false;
      final controller = TextEditingController(text: 'test');
      await tester.pumpWidget(
        wrap(
          AppSearchField(
            controller: controller,
            onClear: () => clearCalled = true,
          ),
        ),
      );

      await tester.tap(find.byIcon(Icons.close));
      await tester.pump();

      expect(clearCalled, isTrue);
    });

    testWidgets('has rounded border (circular 24)', (tester) async {
      await tester.pumpWidget(wrap(const AppSearchField()));

      final decoration =
          tester.widget<TextField>(find.byType(TextField)).decoration
              as InputDecoration;
      final border = decoration.border as OutlineInputBorder;
      expect(border.borderRadius, equals(BorderRadius.circular(24)));
    });
  });
}
