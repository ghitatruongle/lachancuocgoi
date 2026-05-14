import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lachancuocgoi_flutter/analysis/common/fuzzy_matcher.dart';
import 'package:lachancuocgoi_flutter/analysis/common/text_normalizer.dart';
import 'package:lachancuocgoi_flutter/analysis/l1/l1_analysis.dart';
import 'package:lachancuocgoi_flutter/core/risk_level.dart';
import 'package:lachancuocgoi_flutter/ui/monitoring_page/monitoring_page.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Phase 4 common analysis parity', () {
    test('normalizes Vietnamese, leetspeak, punctuation, and combining marks',
        () {
      expect(
        TextNormalizer.normalize('T1ền C.ông an yêu cầu mã OTP!!!'),
        'tien cong an yeu cau ma otp',
      );
      expect(
        TextNormalizer.normalize(
          'C.ông an',
          noiseMode: NoiseMode.space,
        ),
        'c ong an',
      );
      expect(TextNormalizer.normalize('ma\u0303 OTP'), 'ma otp');
    });

    test('uses Kotlin-compatible Damerau-Levenshtein transposition', () {
      expect(
        FuzzyMatcher.damerauLevenshtein('ab', 'ba', maxDistance: 1),
        1,
      );
      expect(
        FuzzyMatcher.findClosest(
          'viettei',
          ['viettel', 'nganhang'],
          maxDistance: 1,
        ),
        'viettel',
      );
    });
  });

  group('Phase 4 L1 analyzer', () {
    test('loads test vocabulary and does not alert on level-0 safe words',
        () async {
      final analyzer = _newTestAnalyzer();
      await analyzer.initialize();

      final result = await analyzer.analyze('xin chào bạn bè, hôm nay ổn chứ');

      expect(result.overallRiskLevel, RiskLevel.green);
      expect(result.alertEnabled, isFalse);
      expect(result.matches, isEmpty);
    });

    test('detects Aho-Corasick phrase matches and weighted category risk',
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
    });

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

    test('does not flicker to GREEN when stream receives no new tokens',
        () async {
      final analyzer = _newTestAnalyzer();
      await analyzer.initialize();

      const transcript = 'Vui lòng gửi mã OTP để xác minh.';
      final first = await analyzer.analyzeStream(transcript);
      final repeated = await analyzer.analyzeStream(transcript);

      expect(first.overallRiskLevel, RiskLevel.red);
      expect(repeated.overallRiskLevel, RiskLevel.red);
      expect(analyzer.processedTextLength, transcript.length);
    });

    test('loads bundled JSON assets and runs real L1 vocabulary', () async {
      final analyzer = L1Analyzer();
      await analyzer.initialize();

      final health = analyzer.healthCheck();
      final result = await analyzer.analyze(
        'Tôi là nhân viên ngân hàng, anh hãy đọc mã OTP để xác minh.',
      );

      expect(health.isHealthy, isTrue);
      expect(result.overallRiskLevel, RiskLevel.red);
      expect(result.matches, isNotEmpty);
    });
  });

  group('Phase 4 Monitoring mock integration', () {
    testWidgets('feeds simulated transcript through L1', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: MonitoringPage(
            simulatedScenarioTitle: 'OTP test',
            simulatedTranscript:
                'Nhân viên ngân hàng yêu cầu anh đọc mã OTP để xác minh.',
          ),
        ),
      );

      await tester.pump();
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 500)),
      );
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
