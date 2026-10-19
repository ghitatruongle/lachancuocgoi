import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lachancuocgoi_flutter/ui/onboarding/permission_rationale_steps.dart';

void main() {
  test('default permission steps order starts with mic', () {
    final steps = defaultPermissionRationaleSteps();
    expect(steps, hasLength(5));
    expect(steps.first.title, contains('Micro'));
    expect(steps.last.title, contains('đám mây'));
    expect(steps.where((s) => s.isOptional).length, greaterThanOrEqualTo(2));
  });

  testWidgets('pager shows step title and next', (tester) async {
    final steps = defaultPermissionRationaleSteps();
    var index = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: PermissionRationalePager(
            steps: steps,
            index: index,
            onNext: () => index++,
            onBack: () {},
            onSkipOptional: () => index++,
            onFinish: () {},
          ),
        ),
      ),
    );
    expect(find.textContaining('Micro'), findsOneWidget);
    expect(find.text('Tiếp'), findsOneWidget);
  });
}
