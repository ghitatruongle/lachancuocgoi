import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lachancuocgoi_flutter/analysis/common/fuzzy_matcher.dart';
import 'package:lachancuocgoi_flutter/analysis/common/text_normalizer.dart';
import 'package:lachancuocgoi_flutter/analysis/l1/l1_analysis.dart';
import 'package:lachancuocgoi_flutter/core/risk_level.dart';
import 'package:lachancuocgoi_flutter/l10n/app_localizations.dart';
import 'package:lachancuocgoi_flutter/services/native_call_shield_bridge.dart';
import 'package:lachancuocgoi_flutter/ui/monitoring_page/monitoring_page.dart';

import 'package:lachancuocgoi_flutter/services/flutter_services_impl.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Phase 4 common analysis parity', () {
    test(
      'normalizes Vietnamese, leetspeak, punctuation, and combining marks',
      () {
        expect(
          TextNormalizer.normalize('T1ền C.ông an yêu cầu mã OTP!!!'),
          'tien cong an yeu cau ma otp',
        );
        expect(
          TextNormalizer.normalize('C.ông an', noiseMode: NoiseMode.space),
          'c ong an',
        );
        expect(TextNormalizer.normalize('ma\u0303 OTP'), 'ma otp');
      },
    );

    test('uses Kotlin-compatible Damerau-Levenshtein transposition', () {
      expect(FuzzyMatcher.damerauLevenshtein('ab', 'ba', maxDistance: 1), 1);
      expect(
        FuzzyMatcher.findClosest('viettei', [
          'viettel',
          'nganhang',
        ], maxDistance: 1),
        'viettel',
      );
    });
  });

  group('Phase 4 L1 analyzer', () {
    test(
      'loads test vocabulary and does not alert on level-0 safe words',
      () async {
        final analyzer = _newTestAnalyzer();
        await analyzer.initialize();

        final result = await analyzer.analyze(
          'xin chào bạn bè, hôm nay ổn chứ',
        );

        expect(result.overallRiskLevel, RiskLevel.green);
        expect(result.alertEnabled, isFalse);
        expect(result.matches, isEmpty);
      },
    );

    test(
      'detects Aho-Corasick phrase matches and weighted category risk',
      () async {
        final analyzer = _newTestAnalyzer();
        await analyzer.initialize();

        final result = await analyzer.analyze(
          'Yêu cầu chuyển tiền vào tài khoản ngân hàng ngay.',
        );

        expect(result.overallRiskLevel, RiskLevel.orange);
        expect(
          result.matches.map((match) => match.keyword),
          containsAll(['chuyển tiền', 'tài khoản ngân hàng']),
        );
        expect(result.reason, contains('Tài chính'));
      },
    );

    test('applies configured token corrections before matching', () async {
      final analyzer = _newTestAnalyzer();
      await analyzer.initialize();

      final result = await analyzer.analyze('Tôi là cán bộ quận gọi cho anh.');

      expect(result.overallRiskLevel, RiskLevel.yellow);
      expect(result.matches.single.keyword, 'công an');
    });

    test('keeps critical OTP keywords as RED', () async {
      final analyzer = _newTestAnalyzer();
      await analyzer.initialize();

      final result = await analyzer.analyze('Vui lòng gửi mã OTP để xác minh.');

      expect(result.overallRiskLevel, RiskLevel.red);
      expect(result.alertEnabled, isTrue);
      expect(result.reason, contains('OTP'));
    });

    test('supports fuzzy matching for long single-token STT errors', () async {
      final analyzer = _newTestAnalyzer();
      await analyzer.initialize();

      final result = await analyzer.analyze('Tôi gọi từ viette1 đây.');

      expect(result.overallRiskLevel, RiskLevel.yellow);
      expect(result.matches.single.keyword, 'viettel');
      expect(result.matches.single.isFuzzy, isTrue);
    });

    test(
      'detects level-2 normal keyword match (parity with Kotlin testAnalyze_NormalKeyword)',
      () async {
        final analyzer = _newTestAnalyzer();
        await analyzer.initialize();

        final result = await analyzer.analyze(
          'Chúc mừng anh đã nhận được khuyến mãi lớn.',
        );

        expect(result.overallRiskLevel, RiskLevel.yellow);
        expect(result.alertEnabled, isTrue);
        expect(result.matches.map((m) => m.keyword), contains('khuyến mãi'));
      },
    );

    test(
      'does not flicker to GREEN when stream receives no new tokens',
      () async {
        final analyzer = _newTestAnalyzer();
        await analyzer.initialize();

        const transcript = 'Vui lòng gửi mã OTP để xác minh.';
        final first = await analyzer.analyzeStream(transcript);
        final repeated = await analyzer.analyzeStream(transcript);

        expect(first.overallRiskLevel, RiskLevel.red);
        expect(repeated.overallRiskLevel, RiskLevel.red);
        expect(analyzer.processedTextLength, transcript.length);
      },
    );

    test('loads bundled JSON assets and runs real L1 vocabulary', () async {
      final analyzer = L1Analyzer(assetLoader: const FlutterAssetLoader());
      await analyzer.initialize();

      final health = analyzer.healthCheck();
      final result = await analyzer.analyze(
        'Tôi là nhân viên ngân hàng, anh hãy đọc mã OTP để xác minh.',
      );

      expect(health.isHealthy, isTrue);
      expect(result.overallRiskLevel, RiskLevel.red);
      expect(result.matches, isNotEmpty);
    });

    test('uses fallback vocabulary when initialization fails', () async {
      final analyzer = L1Analyzer(
        vocabularyProvider: () => throw const FormatException('Invalid JSON'),
      );
      await analyzer.initialize();

      expect(analyzer.isReady, isTrue);

      final result1 = await analyzer.analyze('đây là trò lừa đảo');
      expect(result1.overallRiskLevel, RiskLevel.yellow);

      final result2 = await analyzer.analyze('tôi đi chuyển tiền');
      expect(result2.overallRiskLevel, RiskLevel.yellow);

      final result3 = await analyzer.analyze('yêu cầu nhập mã otp');
      expect(
        result3.overallRiskLevel,
        RiskLevel.red,
      ); // critical OTP keyword forces RED
    });

    test(
      'applies negative lookahead context filtering to reduce false alarms',
      () async {
        final analyzer = _newTestAnalyzer();
        await analyzer.initialize();

        final alertNormal = await analyzer.analyze('tôi thấy công an');
        expect(alertNormal.overallRiskLevel, RiskLevel.yellow);

        final alertNegated = await analyzer.analyze('không phải công an đâu');
        expect(alertNegated.overallRiskLevel, RiskLevel.green);

        final transNormal = await analyzer.analyze('yêu cầu chuyển tiền ngay');
        expect(transNormal.overallRiskLevel, RiskLevel.yellow);

        final transSafe = await analyzer.analyze('tôi đi chuyển tiền cho mẹ');
        expect(transSafe.overallRiskLevel, RiskLevel.green);

        final resultNormal = await analyzer.analyze('tôi là công an đây');
        expect(resultNormal.overallRiskLevel, RiskLevel.yellow);

        final resultTroll = await analyzer.analyze(
          'tôi là công an đây nói đùa thôi',
        );
        expect(resultTroll.overallRiskLevel, RiskLevel.green);
      },
    );
  });

  group('Phase 4 Monitoring mock integration', () {
    testWidgets('feeds simulated transcript through L1', (tester) async {
      const methodChannel = MethodChannel('com.lachancuocgoi/native_bridge');
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(methodChannel, (call) async {
            return switch (call.method) {
              'stopMonitoring' => true,
              'getPermissionSnapshot' => <String, bool>{
                'recordAudio': true,
                'phoneState': true,
                'callLog': true,
                'overlay': true,
                'notification': true,
                'accessibility': true,
                'callScreening': true,
              },
              _ => null,
            };
          });
      addTearDown(() {
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
            .setMockMethodCallHandler(methodChannel, null);
      });

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            nativeBridgeProvider.overrideWithValue(
              NativeBridgeInterface.create(),
            ),
          ],
          child: MaterialApp(
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: MonitoringPage(
              l1AnalyzerOverride: _newTestAnalyzer(),
              simulatedScenarioTitle: 'OTP test',
              simulatedTranscript:
                  'Nhân viên ngân hàng yêu cầu anh đọc mã OTP để xác minh.',
            ),
          ),
        ),
      );

      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));
      await tester.pump(const Duration(seconds: 1));

      expect(find.text('Nguy hiểm'), findsOneWidget);
      expect(find.textContaining('OTP'), findsWidgets);
      await tester.pumpWidget(const SizedBox.shrink());
    });
  });
}

L1Analyzer _newTestAnalyzer() {
  return L1Analyzer(
    vocabularyProvider: () => jsonEncode(_testVocabulary),
    bigramCorrectionsProvider: () => jsonEncode(_testCorrections),
  );
}

const Map<String, Object?> _testVocabulary = {
  'riskLevels': [
    {
      'level': 0,
      'keywords': ['xin chào', 'bạn bè'],
    },
    {
      'level': 3,
      'threats': {
        'Tài chính': ['chuyển tiền', 'tài khoản ngân hàng'],
        'Giả danh': ['công an', 'viện kiểm sát'],
      },
      'keywords': ['mã otp'],
    },
    {
      'level': 2,
      'keywords': ['khuyến mãi', 'trúng thưởng', 'viettel'],
    },
  ],
};

const Map<String, Object?> _testCorrections = {
  'corrections': [
    {
      'from': ['can', 'bo'],
      'to': ['cong', 'an'],
    },
    {
      'from': ['ma', 'ot'],
      'to': ['ma', 'otp'],
    },
  ],
};
