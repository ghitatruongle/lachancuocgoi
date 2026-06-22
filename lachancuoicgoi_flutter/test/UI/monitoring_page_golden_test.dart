import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lachancuocgoi_flutter/analysis/l1/l1_analysis.dart';
import 'package:lachancuocgoi_flutter/services/native_call_shield_bridge.dart';
import 'package:lachancuocgoi_flutter/ui/monitoring_page/monitoring_page.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../helpers/fake_native_bridge.dart';

void main() {
  group('MonitoringPage Golden Tests (Samsung Galaxy J6+ Specs)', () {
    late FakeNativeBridge fakeBridge;

    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      fakeBridge = FakeNativeBridge();
    });

    tearDown(() {
      fakeBridge.dispose();
    });

    L1Analyzer emptyL1Analyzer() {
      return L1Analyzer(
        vocabularyProvider: () => '{"riskLevels": []}',
        bigramCorrectionsProvider: () => '{"corrections": []}',
      );
    }

    testWidgets('renders correctly on Galaxy J6+ portrait screen', (tester) async {
      // Configure target device dimensions for Samsung Galaxy J6+:
      // Physical resolution: 720 x 1480 pixels
      // Logical size: 360 x 740, Device Pixel Ratio: 2.0
      tester.view.physicalSize = const Size(720, 1480);
      tester.view.devicePixelRatio = 2.0;

      final analyzer = emptyL1Analyzer();
      await tester.runAsync(() => analyzer.initialize());

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            nativeBridgeProvider.overrideWithValue(fakeBridge),
          ],
          child: MaterialApp(
            debugShowCheckedModeBanner: false,
            theme: ThemeData.light(),
            home: MonitoringPage(
              l1AnalyzerOverride: analyzer,
              simulatedScenarioTitle: 'Mô phỏng ngân hàng lừa đảo',
              simulatedTranscript: 'Anh Nguyễn Văn A vui lòng cung cấp mã OTP gửi về điện thoại',
            ),
          ),
        ),
      );

      // Use repeated pump with delay instead of pumpAndSettle,
      // because waveform and timer animations run continuously.
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));

      // Verify the UI matching golden screenshot.
      // Since this is in platform-dependent rendering, we match the Golden target.
      await expectLater(
        find.byType(MonitoringPage),
        matchesGoldenFile('goldens/monitoring_page_j6plus.png'),
      );

      // Reset test view modifications
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });
  });
}
