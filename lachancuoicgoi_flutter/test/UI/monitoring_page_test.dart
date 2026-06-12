import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lachancuocgoi_flutter/analysis/l1/l1_analysis.dart';
import 'package:lachancuocgoi_flutter/services/native_call_shield_bridge.dart';
import 'package:lachancuocgoi_flutter/ui/monitoring_page/monitoring_page.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../helpers/fake_native_bridge.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late FakeNativeBridge fakeBridge;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    fakeBridge = FakeNativeBridge();
  });

  tearDown(() {
    fakeBridge.dispose();
  });

  /// Build the MonitoringPage widget tree.
  ///
  /// Uses [tester.runAsync] for L1Analyzer.initialize() because it calls
  /// Future.delayed(Duration.zero) internally, which hangs in the fake
  /// async zone that testWidgets uses.
  Future<void> pumpPage({
    required WidgetTester tester,
    String? scenarioTitle,
    String? transcript,
  }) async {
    final analyzer = _emptyL1Analyzer();
    // runAsync escapes the fake async zone so Future.delayed fires.
    await tester.runAsync(() => analyzer.initialize());

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          nativeBridgeProvider.overrideWithValue(fakeBridge),
        ],
        child: MaterialApp(
          home: MonitoringPage(
            l1AnalyzerOverride: analyzer,
            simulatedScenarioTitle: scenarioTitle,
            simulatedTranscript: transcript,
          ),
        ),
      ),
    );
    // Let addPostFrameCallback (init + initAfterFrame) fire and state
    // changes rebuild.
    await tester.pump();
    await tester.pump();
  }

  // ─── Basic rendering ─────────────────────────────────────────────────
  group('MonitoringPage — rendering', () {
    testWidgets('shows app bar with title', (tester) async {
      await pumpPage(tester: tester);
      expect(find.text('Lá chắn cuộc gọi'), findsOneWidget);
      expect(find.text('Phát hiện Lừa đảo & Bạo lực'), findsOneWidget);
    });

    testWidgets('shows waveform section', (tester) async {
      await pumpPage(tester: tester);
      expect(find.text('Đang giám sát'), findsOneWidget);
      expect(find.text('00:00'), findsOneWidget);
    });

    testWidgets('shows risk level indicator', (tester) async {
      await pumpPage(tester: tester);
      expect(find.text('Mức độ rủi ro'), findsOneWidget);
      expect(find.text('An toàn'), findsOneWidget);
    });

    testWidgets('shows conversation card', (tester) async {
      await pumpPage(tester: tester);
      expect(find.text('Cuộc hội thoại trực tiếp'), findsOneWidget);
    });

    testWidgets('shows end call button', (tester) async {
      await pumpPage(tester: tester);
      expect(find.text('Kết thúc cuộc gọi'), findsOneWidget);
      expect(find.byIcon(Icons.call_end), findsOneWidget);
    });

    testWidgets('shows settings button', (tester) async {
      await pumpPage(tester: tester);
      expect(find.byIcon(Icons.settings), findsOneWidget);
    });
  });

  // ─── Simulation mode ─────────────────────────────────────────────────
  group('MonitoringPage — simulation mode', () {
    testWidgets('shows simulation title when provided', (tester) async {
      await pumpPage(tester: tester, scenarioTitle: 'Test Scenario');
      expect(find.text('Mô phỏng: Test Scenario'), findsOneWidget);
      expect(find.text('Kịch bản mô phỏng'), findsOneWidget);
    });

    testWidgets('shows generic simulation title', (tester) async {
      await pumpPage(tester: tester, transcript: 'Hello world');
      expect(find.text('Mô phỏng'), findsOneWidget);
    });
  });

  // ─── Risk level display ──────────────────────────────────────────────
  group('MonitoringPage — risk level', () {
    testWidgets('shows green risk by default', (tester) async {
      await pumpPage(tester: tester);
      expect(find.text('An toàn'), findsOneWidget);
    });
  });

  // ─── End call button ─────────────────────────────────────────────────
  group('MonitoringPage — end call', () {
    testWidgets('end call button is tappable', (tester) async {
      await pumpPage(tester: tester);
      final elevatedButton = tester.widget<ElevatedButton>(
        find.byType(ElevatedButton),
      );
      expect(elevatedButton.onPressed, isNotNull);
    });
  });

  // ─── Status chips ────────────────────────────────────────────────────
  group('MonitoringPage — status chips', () {
    testWidgets('shows analysis mode chips', (tester) async {
      await pumpPage(tester: tester);
      expect(find.textContaining('Đích:'), findsOneWidget);
      expect(find.textContaining('Chạy:'), findsOneWidget);
      expect(find.textContaining('Mạng:'), findsOneWidget);
    });
  });

  // ─── Transcript display ──────────────────────────────────────────────
  group('MonitoringPage — transcript', () {
    testWidgets('shows simulated transcript in live conversation',
        (tester) async {
      await pumpPage(
        tester: tester,
        transcript: 'Nhân viên ngân hàng yêu cầu OTP',
      );
      expect(
        find.text('Nhân viên ngân hàng yêu cầu OTP'),
        findsOneWidget,
      );
    });
  });

  // ─── Risk level from test analyzer override ──────────────────────────
  group('MonitoringPage — test analyzer override', () {
    testWidgets('shows red risk when test analyzer with transcript',
        (tester) async {
      await pumpPage(
        tester: tester,
        transcript: 'Nhân viên ngân hàng yêu cầu OTP',
      );
      // With l1AnalyzerOverride + non-empty transcript, controller sets
      // hardcoded red result.
      expect(find.text('Nguy hiểm'), findsOneWidget);
    });
  });
}

L1Analyzer _emptyL1Analyzer() {
  return L1Analyzer(
    vocabularyProvider: () => '{"riskLevels": []}',
    bigramCorrectionsProvider: () => '{"corrections": []}',
  );
}
