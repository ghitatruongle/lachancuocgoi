import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lachancuocgoi_flutter/analysis/l1/l1_analysis.dart';
import 'package:lachancuocgoi_flutter/core/risk_level.dart';
import 'package:lachancuocgoi_flutter/services/native_call_shield_bridge.dart';
import 'package:lachancuocgoi_flutter/ui/monitoring_page/monitoring_page.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  // ─── Helper: pump MonitoringPage with test override ───────────────────
  Future<void> pumpPage({
    required WidgetTester tester,
    String? scenarioTitle,
    String? transcript,
    L1Analyzer Function()? analyzerFactory,
  }) async {
    final analyzer = analyzerFactory?.call() ?? _emptyL1Analyzer();
    await analyzer.initialize();

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          nativeBridgeProvider.overrideWithValue(
            NativeCallShieldBridge.instance,
          ),
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
  }

  // ─── Basic rendering ─────────────────────────────────────────────────
  group('MonitoringPage — rendering', () {
    testWidgets('shows app bar with title', (tester) async {
      await pumpPage(tester: tester);

      expect(find.text('Lá chắn cuộc gọi'), findsOneWidget);
      expect(
        find.text('Phát hiện Lừa đảo & Bạo lực'),
        findsOneWidget,
      );
    });

    testWidgets('shows waveform section', (tester) async {
      await pumpPage(tester: tester);

      expect(find.text('Đang giám sát'), findsOneWidget);
      expect(find.text('00:00'), findsOneWidget);
    });

    testWidgets('shows risk level indicator', (tester) async {
      await pumpPage(tester: tester);

      expect(find.text('Mức độ rủi ro'), findsOneWidget);
      // Default is green (no transcript with override)
      expect(find.text('An toàn'), findsOneWidget);
    });

    testWidgets('shows live conversation waiting message', (tester) async {
      await pumpPage(tester: tester);

      expect(find.text('Đang lắng nghe...'), findsOneWidget);
    });

    testWidgets('shows end call button', (tester) async {
      await pumpPage(tester: tester);

      expect(find.text('Kết thúc cuộc gọi'), findsOneWidget);
      expect(find.byIcon(Icons.call_end), findsOneWidget);
    });

    testWidgets('shows settings button in app bar', (tester) async {
      await pumpPage(tester: tester);

      expect(find.byTooltip('Cài đặt'), findsOneWidget);
      expect(find.byIcon(Icons.settings), findsOneWidget);
    });

    testWidgets('shows analysis mode chips', (tester) async {
      await pumpPage(tester: tester);

      // With l1AnalyzerOverride + no transcript, should show L1 mode
      expect(find.textContaining('Đích:'), findsOneWidget);
      expect(find.textContaining('Chạy:'), findsOneWidget);
      expect(find.textContaining('Mạng:'), findsOneWidget);
    });
  });

  // ─── Simulation mode ─────────────────────────────────────────────────
  group('MonitoringPage — simulation mode', () {
    testWidgets('shows simulation title when scenario provided', (tester) async {
      await pumpPage(
        tester: tester,
        scenarioTitle: 'Test lừa đảo',
        transcript: '',
      );

      expect(find.textContaining('Mô phỏng'), findsOneWidget);
      expect(find.textContaining('Test lừa đảo'), findsOneWidget);
    });

    testWidgets('shows simulation waiting message', (tester) async {
      await pumpPage(
        tester: tester,
        scenarioTitle: 'Test',
        transcript: '',
      );

      // LiveConversation with isSimulation=true + empty transcript shows 'Đang chờ kịch bản...'
      await tester.pump();
      expect(find.text('Đang chờ kịch bản...'), findsOneWidget);
      expect(find.text('Đang lắng nghe...'), findsNothing);
    });

    testWidgets('shows simulation label for conversation card', (tester) async {
      await pumpPage(
        tester: tester,
        scenarioTitle: 'Test',
        transcript: 'Nội dung mô phỏng',
      );

      expect(find.text('Kịch bản mô phỏng'), findsOneWidget);
      expect(find.text('Cuộc hội thoại trực tiếp'), findsNothing);
    });
  });

  // ─── Risk level display ──────────────────────────────────────────────
  group('MonitoringPage — risk level', () {
    testWidgets('displays RED risk with pre-loaded simulated transcript',
        (tester) async {
      await pumpPage(
        tester: tester,
        scenarioTitle: 'OTP test',
        transcript: 'Vui lòng cung cấp mã OTP để xác minh',
      );

      // With l1AnalyzerOverride + non-empty transcript, risk is pre-set to RED
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));
      await tester.pump(const Duration(seconds: 1));

      expect(find.text('Nguy hiểm'), findsOneWidget);
    });

    testWidgets('shows OTP keyword match chips in red state', (tester) async {
      await pumpPage(
        tester: tester,
        scenarioTitle: 'OTP test',
        transcript: 'Vui lòng cung cấp mã OTP',
      );

      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));
      await tester.pump(const Duration(seconds: 1));

      // The result has a match with keyword 'OTP'
      expect(find.text('OTP'), findsAtLeast(1));
    });

    testWidgets('shows reason text for the analysis', (tester) async {
      await pumpPage(
        tester: tester,
        scenarioTitle: 'OTP test',
        transcript: 'Vui lòng cung cấp mã OTP',
      );

      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));
      await tester.pump(const Duration(seconds: 1));

      // The pre-loaded result has reason 'OTP'
      expect(find.text('OTP'), findsAtLeast(1));
    });

    testWidgets('shows green risk when no transcript provided',
        (tester) async {
      await pumpPage(tester: tester);

      expect(find.text('An toàn'), findsOneWidget);
      expect(find.text('Nguy hiểm'), findsNothing);
    });
  });

  // ─── End call button ─────────────────────────────────────────────────
  group('MonitoringPage — end call button', () {
    testWidgets('end call button is enabled initially', (tester) async {
      await pumpPage(tester: tester);

      final button = tester.widget<ElevatedButton>(
        find.byType(ElevatedButton),
      );
      expect(button.onPressed, isNotNull);
    });

    testWidgets('tapping end call shows saving indicator', (tester) async {
      await pumpPage(tester: tester);

      await tester.tap(find.byType(ElevatedButton));
      await tester.pump();

      // Should show saving state
      expect(find.text('Đang lưu kết quả...'), findsOneWidget);
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
    });
  });

  // ─── Settings dialog ──────────────────────────────────────────────────
  group('MonitoringPage — settings', () {
    testWidgets('tapping settings icon opens SettingsDialog', (tester) async {
      await pumpPage(tester: tester);

      await tester.tap(find.byIcon(Icons.settings));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      expect(find.text('Cài đặt'), findsAtLeast(1));
      expect(find.byIcon(Icons.close), findsOneWidget);
    });
  });

  // ─── Network and mode chips ───────────────────────────────────────────
  group('MonitoringPage — status chips', () {
    testWidgets('shows target analysis mode chip', (tester) async {
      await pumpPage(tester: tester);

      // Default with test override is AnalysisMode.normal → label "L1"
      expect(find.textContaining('L1'), findsWidgets);
    });

    testWidgets('shows network status chip', (tester) async {
      await pumpPage(tester: tester);

      expect(find.textContaining('Mạng:'), findsOneWidget);
    });

    testWidgets('shows running mode chip', (tester) async {
      await pumpPage(tester: tester);

      expect(find.textContaining('Chạy:'), findsOneWidget);
    });
  });
}/// Create an L1Analyzer with empty assets for tests that don't need full vocabulary.
L1Analyzer _emptyL1Analyzer() {
  return L1Analyzer(
    vocabularyProvider: () => '{"riskLevels": []}',
    bigramCorrectionsProvider: () => '{"corrections": []}',
  );
}
