import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:lachancuocgoi_flutter/analysis/analysis_result.dart';
import 'package:lachancuocgoi_flutter/app/lachancuocgoi_app.dart';
import 'package:lachancuocgoi_flutter/core/risk_level.dart';
import 'package:lachancuocgoi_flutter/data/app_database.dart';
import 'package:lachancuocgoi_flutter/data/call_history.dart';
import 'package:lachancuocgoi_flutter/ui/home_page/home_page.dart';
import 'package:lachancuocgoi_flutter/ui/result_page/result_page.dart';
import 'package:lachancuocgoi_flutter/ui/simulation_page/simulation_page.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('host demo smoke: Home to Simulation to Result', (tester) async {
    debugDefaultTargetPlatformOverride = TargetPlatform.windows;
    try {
      tester.view
        ..physicalSize = const Size(1080, 1600)
        ..devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      SharedPreferences.setMockInitialValues({'onboarding_completed': true});
      final database = InMemoryAppDatabase();
      addTearDown(database.close);
      final historyId = await database.insert(
        CallHistory(
          dateTime: DateTime(2026, 7, 18, 9).toIso8601String(),
          riskLevel: RiskLevel.orange.storageName,
          summary: 'Phát hiện yêu cầu cung cấp mã OTP.',
          duration: '00:15',
          flagCount: 1,
          transcript: 'Đây là transcript mô phỏng, không phải cuộc gọi thật.',
          analysisType: 'simulation',
          analysisResult: jsonEncode(
            const AnalysisResult(
              overallRiskLevel: RiskLevel.orange,
              matches: <KeywordMatch>[
                KeywordMatch(
                  keyword: 'mã OTP',
                  level: RiskLevel.orange,
                  category: 'OTP',
                ),
              ],
              reason: 'Kịch bản mô phỏng yêu cầu mã xác thực.',
            ).toJson(),
          ),
        ),
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            appDatabaseFutureProvider.overrideWith((ref) async => database),
          ],
          child: const LachancuocgoiApp(),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.byType(HomePage), findsOneWidget);

      final simulationAction = find.text('Chế độ giả lập');
      expect(simulationAction, findsOneWidget);
      await tester.ensureVisible(simulationAction);
      await tester.tap(simulationAction);
      await tester.pumpAndSettle();
      expect(find.byType(SimulationPage), findsOneWidget);

      final simulationContext = tester.element(find.byType(SimulationPage));
      GoRouter.of(simulationContext).go('/result/$historyId');
      await tester.pumpAndSettle();

      expect(find.byType(ResultPage), findsOneWidget);
      expect(find.textContaining('OTP'), findsWidgets);
      expect(tester.takeException(), isNull);
    } finally {
      debugDefaultTargetPlatformOverride = null;
    }
  });
}
