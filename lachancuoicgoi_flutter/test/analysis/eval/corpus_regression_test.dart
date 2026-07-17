import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:lachancuocgoi_flutter/analysis/analysis_coordinator.dart';
import 'package:lachancuocgoi_flutter/analysis/analysis_mode.dart';
import 'package:lachancuocgoi_flutter/analysis/analysis_result.dart';
import 'package:lachancuocgoi_flutter/analysis/l1/l1_analysis.dart';
import 'package:lachancuocgoi_flutter/analysis/l2/g_detection/g_detection_engine.dart';
import 'package:lachancuocgoi_flutter/analysis/l2/g_detection/g_models.dart';
import 'package:lachancuocgoi_flutter/analysis/l2/intent/intent_classifier.dart';
import 'package:lachancuocgoi_flutter/analysis/l2/l2_analysis.dart';
import 'package:lachancuocgoi_flutter/analysis/l2/wfsa/wfsa_engine.dart';
import 'package:lachancuocgoi_flutter/analysis/l3/core/api_key_provider.dart';
import 'package:lachancuocgoi_flutter/analysis/l3/l3_analysis.dart';
import 'package:lachancuocgoi_flutter/core/risk_level.dart';

import 'eval_case.dart';
import 'eval_runner.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('corpus_v1 regression gate', () async {
    final jsonl = await File('test/fixtures/eval/corpus_v1.jsonl').readAsString();
    final cases = parseEvalJsonl(jsonl);
    expect(cases.length, greaterThanOrEqualTo(30));

    final l1 = L1Analyzer(
      vocabularyProvider: () => jsonEncode(_evalVocabulary),
      bigramCorrectionsProvider: () => jsonEncode(_evalCorrections),
      criticalKeywordsProvider: () => jsonEncode(_criticalKeywords),
    );
    await l1.initialize();

    final l2 = L2Analyzer(
      gDetectionEngine: _RuleBasedEvalGDetectionEngine(),
      intentClassifier: const DisabledIntentClassifier(),
      wfsaEngine: WfsaEngine(const <ScenarioGraph>[]),
    );
    await l2.initialize();

    final coordinator = AnalysisCoordinator(
      l1Analyzer: l1,
      l2Analyzer: l2,
      l3Analyzer: L3Analyzer(
        apiKeyProvider: StaticApiKeyProvider(const <String>[]),
      ),
      networkAvailable: () => false,
    );

    final report = await const EvalRunner().run(
      cases: cases,
      mode: AnalysisMode.parallel,
      coordinator: coordinator,
    );

    // ignore: avoid_print
    print(report.toMarkdownTable());

    expect(report.precision, greaterThanOrEqualTo(0.85));
    expect(report.recall, greaterThanOrEqualTo(0.80));
    expect(report.f1, greaterThanOrEqualTo(0.82));
    expect(report.falseRedOnGreen, 0);
  }, tags: ['eval']);
}

class _RuleBasedEvalGDetectionEngine extends GDetectionEngine {
  @override
  Future<void> initialize() async {}

  @override
  bool get isReady => true;

  @override
  Future<GResult> performFullAnalysis(String text) async {
    final normalized = text.toLowerCase();
    final redTerms = <String>[
      'otp',
      'mã xác thực',
      'mật khẩu',
      'internet banking',
      'tài khoản an toàn',
      'cơ quan điều tra',
      'bắt tạm giam',
      'rửa tiền',
      'thẻ cào',
    ];
    final orangeTerms = <String>[
      'chuyển tiền',
      'chuyển khoản',
      'phí xử lý',
      'phí bảo hiểm',
      'trúng thưởng',
      'giải ngân',
      'phong tỏa',
      'giữ bí mật',
      'không được báo',
      'tiền ảo',
      'không lỗ',
      'cấp cứu',
      'phí hải quan',
      'phí phạt',
    ];

    final redMatch = redTerms.firstWhere(
      normalized.contains,
      orElse: () => '',
    );
    if (redMatch.isNotEmpty) {
      return GResult(
        riskLevel: RiskLevel.red,
        reason: 'Eval L2 red: $redMatch',
        allMatchedKeywords: {
          KeywordMatch(
            keyword: redMatch,
            level: RiskLevel.red,
            category: 'Eval',
          ),
        },
        alertEnabled: true,
      );
    }

    final orangeMatch = orangeTerms.firstWhere(
      normalized.contains,
      orElse: () => '',
    );
    if (orangeMatch.isNotEmpty) {
      return GResult(
        riskLevel: RiskLevel.orange,
        reason: 'Eval L2 orange: $orangeMatch',
        allMatchedKeywords: {
          KeywordMatch(
            keyword: orangeMatch,
            level: RiskLevel.orange,
            category: 'Eval',
          ),
        },
        alertEnabled: true,
      );
    }

    return const GResult(
      riskLevel: RiskLevel.green,
      reason: 'Eval L2 green',
      allMatchedKeywords: <KeywordMatch>{},
      alertEnabled: false,
    );
  }
}

const Map<String, Object?> _evalVocabulary = {
  'riskLevels': [
    {
      'level': 0,
      'keywords': ['xin chào'],
    },
    {
      'level': 2,
      'threats': {
        'authority': ['công an', 'cơ quan điều tra'],
        'money': ['chuyển tiền', 'chuyển khoản', 'phong tỏa'],
        'promo': ['trúng thưởng'],
      },
      'keywords': ['phí xử lý', 'phí bảo hiểm'],
    },
    {
      'level': 3,
      'threats': {
        'credential': ['mã otp', 'otp', 'mã xác thực', 'mật khẩu'],
        'threat': ['bắt tạm giam', 'rửa tiền'],
      },
      'keywords': ['tài khoản an toàn', 'thẻ cào'],
    },
  ],
};

const Map<String, Object?> _evalCorrections = {'corrections': <Object?>[]};

const Map<String, Object?> _criticalKeywords = {
  'criticalKeywords': ['otp', 'mã otp', 'mật khẩu', 'thẻ cào'],
};
