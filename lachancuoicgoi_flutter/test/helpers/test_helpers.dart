import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lachancuocgoi_flutter/l10n/app_localizations.dart';
import 'package:lachancuocgoi_flutter/analysis/analysis_level.dart';
import 'package:lachancuocgoi_flutter/analysis/analysis_result.dart';
import 'package:lachancuocgoi_flutter/analysis/l1/l1_analysis.dart';
import 'package:lachancuocgoi_flutter/core/risk_level.dart';
import 'package:lachancuocgoi_flutter/services/native_call_shield_bridge.dart';

L1Analyzer createEmptyL1Analyzer() {
  return L1Analyzer(
    vocabularyProvider: () => '{"riskLevels": []}',
    bigramCorrectionsProvider: () => '{"corrections": []}',
  );
}

List<Override> createCommonOverrides({L1Analyzer? l1AnalyzerOverride}) {
  return [
    nativeBridgeProvider.overrideWithValue(NativeBridgeInterface.create()),
  ];
}

Future<int> pumpAndSettleWithTimeout(
  WidgetTester tester, {
  Duration timeout = const Duration(seconds: 5),
  Duration interval = const Duration(milliseconds: 100),
  EnginePhase phase = EnginePhase.sendSemanticsUpdate,
}) async {
  return tester.pumpAndSettle(interval, phase, timeout);
}

Widget createTestApp({
  required Widget child,
  List<Override> overrides = const [],
  String? initialRoute,
}) {
  return ProviderScope(
    overrides: overrides,
    child: MaterialApp(
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: child,
    ),
  );
}

AnalysisResult createGreenResult() {
  return const AnalysisResult(
    overallRiskLevel: RiskLevel.green,
    matches: <KeywordMatch>[],
    reason: 'Không phát hiện rủi ro.',
    analysisLevel: AnalysisLevel.l1,
    alertEnabled: false,
  );
}

AnalysisResult createRedResult({
  String reason = 'Phát hiện lừa đảo OTP',
  List<KeywordMatch>? matches,
}) {
  return AnalysisResult(
    overallRiskLevel: RiskLevel.red,
    matches:
        matches ??
        const <KeywordMatch>[
          KeywordMatch(
            keyword: 'OTP',
            level: RiskLevel.red,
            category: 'Lừa đảo',
          ),
        ],
    reason: reason,
    analysisLevel: AnalysisLevel.l1,
    alertEnabled: true,
  );
}

AnalysisResult createOrangeResult({String reason = 'Nội dung đáng ngờ'}) {
  return AnalysisResult(
    overallRiskLevel: RiskLevel.orange,
    matches: const <KeywordMatch>[
      KeywordMatch(
        keyword: 'chuyển khoản',
        level: RiskLevel.orange,
        category: 'Tài chính',
      ),
    ],
    reason: reason,
    analysisLevel: AnalysisLevel.l1,
    alertEnabled: true,
  );
}

VoidCallback setupPermissionHandlerMock({Map<int, int>? statuses}) {
  const channel = MethodChannel('flutter.baseflow.com/permissions/methods');
  TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
      .setMockMethodCallHandler(channel, (call) async {
        if (call.method == 'checkPermissionStatus') {
          final permission = call.arguments as int?;
          if (statuses != null && permission != null) {
            return statuses[permission] ?? 0;
          }
          return 1;
        }
        if (call.method == 'requestPermissions') {
          final permissions = (call.arguments as List<dynamic>?) ?? [];
          return <int, int>{
            for (final p in permissions) p as int: statuses?[p] ?? 1,
          };
        }
        if (call.method == 'shouldShowRequestPermissionRationale') {
          return false;
        }
        if (call.method == 'openAppSettings') {
          return true;
        }
        return null;
      });
  return () {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, null);
  };
}
