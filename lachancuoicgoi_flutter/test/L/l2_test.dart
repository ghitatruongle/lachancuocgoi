import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:lachancuocgoi_flutter/analysis/analysis_level.dart';
import 'package:lachancuocgoi_flutter/analysis/l2/g_detection/g_detection_engine.dart';
import 'package:lachancuocgoi_flutter/analysis/l2/g_detection/g_flash.dart';
import 'package:lachancuocgoi_flutter/analysis/l2/intent/intent_classifier.dart';
import 'package:lachancuocgoi_flutter/analysis/l2/intent/scam_intent.dart';
import 'package:lachancuocgoi_flutter/analysis/l2/l2_analysis.dart';
import 'package:lachancuocgoi_flutter/analysis/l2/l2_result.dart';
import 'package:lachancuocgoi_flutter/analysis/health_check.dart';
import 'package:lachancuocgoi_flutter/core/risk_level.dart';

import 'package:lachancuocgoi_flutter/services/flutter_services_impl.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('GDetection tokenizer and engine', () {
    test('GFlash applies slang with Kotlin-compatible SPACE noise mode', () {
      GFlash.loadSlangConfig({'ck': 'chuyen khoan', 'stk': 'so tai khoan'});

      expect(GFlash.tokenize('gui ck vao stk ngay!'), [
        'gui',
        'chuyen',
        'khoan',
        'vao',
        'so',
        'tai',
        'khoan',
        'ngay',
      ]);
      GFlash.loadSlangConfig({});
    });

    test(
      'detects pattern, scenario, sentence, and safe text from injected JSON',
      () async {
        final engine = _newTestEngine();
        await engine.initialize();

        expect(engine.isReady, isTrue);

        final pattern = await engine.performFullAnalysis(
          'Anh phai chuyen tien gap de xu ly ho so.',
        );
        expect(pattern.riskLevel, RiskLevel.red);
        expect(pattern.matchedPatterns.single.patternId, 'transfer_now');
        expect(pattern.alertEnabled, isTrue);

        final scenario = await engine.performFullAnalysis(
          'Toi la cong an, chung toi dang dieu tra va co lenh bat.',
        );
        expect(scenario.riskLevel, RiskLevel.red);
        expect(scenario.mostLikelyScenario?.situationName, 'Gia danh cong an');

        final sentence = await engine.performFullAnalysis(
          'Vui long doc ma otp vua gui cho chung toi.',
        );
        expect(sentence.riskLevel, RiskLevel.red);
        expect(sentence.sentenceMatch?.isSafe, isFalse);

        final safe = await engine.performFullAnalysis(
          'Xin chao, hom nay minh di an com nhe.',
        );
        expect(safe.riskLevel, RiskLevel.green);
        expect(safe.alertEnabled, isFalse);
      },
    );

    test('L2ResultParser preserves evidence and confidence', () async {
      final engine = _newTestEngine();
      final gResult = await engine.performFullAnalysis(
        'Toi la cong an, chung toi dang dieu tra va co lenh bat.',
      );
      final result = L2ResultParser.parse(gResult);

      expect(result.analysisLevel, AnalysisLevel.l2);
      expect(result.overallRiskLevel, RiskLevel.red);
      expect(result.alertEnabled, isTrue);
      expect(result.confidence, greaterThan(0));
      expect(
        result.matches.map((match) => match.keyword),
        contains('Gia danh cong an'),
      );
    });

    test(
      'loads bundled assets and returns a non-green fraud benchmark',
      () async {
        final engine = GDetectionEngine(assetLoader: const FlutterAssetLoader());
        await engine.initialize();

        final result = await engine.performFullAnalysis(
          'Toi la cong an dieu tra, anh can chuyen tien vao tai khoan de xac minh.',
        );

        expect(engine.isReady, isTrue);
        expect(
          result.riskLevel.index,
          greaterThanOrEqualTo(RiskLevel.orange.index),
        );
        expect(result.alertEnabled, isTrue);
        expect(result.allMatchedKeywords, isNotEmpty);
      },
    );
  });

  group('L2 fusion', () {
    test(
      'falls back to GDetection and WFSA when intent classifier is disabled',
      () async {
        final analyzer = L2Analyzer(
          assetLoader: const FlutterAssetLoader(),
          gDetectionEngine: _newTestEngine(),
        );
        await analyzer.initialize();

        final result = await analyzer.analyze(
          'cục cảnh sát đang điều tra',
          'Tôi là công an, chúng tôi đang điều tra và có lệnh bắt.',
        );

        expect(result.analysisLevel, AnalysisLevel.l2);
        expect(result.overallRiskLevel, RiskLevel.red);
        expect(result.matches.first.category, 'Analysis Fallback');
        expect(result.alertEnabled, isTrue);
        expect(analyzer.healthCheck().status, isNot(HealthStatus.down));
      },
    );

    test('GDetection overrides SAFE AI when context is red', () async {
      final analyzer = L2Analyzer(
        assetLoader: const FlutterAssetLoader(),
        gDetectionEngine: _newTestEngine(),
        intentClassifier: _FakeIntentClassifier(<IntentPrediction>[
          const IntentPrediction(intent: ScamIntent.safe, confidence: 0.90),
          const IntentPrediction(
            intent: ScamIntent.bankCardFraud,
            confidence: 0.01,
          ),
        ]),
      );
      await analyzer.initialize();

      final result = await analyzer.analyze(
        'công an điều tra',
        'Tôi là công an, chúng tôi đang điều tra và có lệnh bắt.',
      );

      expect(result.analysisLevel, AnalysisLevel.l2Fused);
      expect(result.overallRiskLevel, RiskLevel.red);
      expect(result.matches.first.category, 'Cross-validation Override');
    });
  });
}

class _FakeIntentClassifier implements IntentClassifier {
  _FakeIntentClassifier(this.predictions);

  final List<IntentPrediction> predictions;
  bool _isReady = false;

  @override
  Future<void> initialize() async {
    _isReady = true;
  }

  @override
  bool get isReady => _isReady;

  @override
  Future<List<IntentPrediction>> predictIntent(String transcript) async {
    return predictions;
  }

  @override
  void close() {
    _isReady = false;
  }
}

GDetectionEngine _newTestEngine() {
  final assets = <String, Object?>{
    GDetectionEngine.vocabularyFile: _testVocabulary,
    GDetectionEngine.scoringConfigFile: _testScoringConfig,
    GDetectionEngine.patternsFile: _testPatterns,
    GDetectionEngine.situationFile: _testScenarios,
    GDetectionEngine.sentencesFile: _testSentences,
    GDetectionEngine.slangFile: _testSlang,
    GDetectionEngine.tierConfigFile: _testTierConfig,
    GDetectionEngine.aiCheckFile: <String, Object?>{'situations': <Object?>[]},
  };

  return GDetectionEngine(
    assetProvider: (fileName) =>
        jsonEncode(assets[fileName] ?? <String, Object?>{}),
  );
}

const Map<String, Object?> _testVocabulary = <String, Object?>{
  'riskLevels': <Object?>[
    <String, Object?>{
      'level': 0,
      'keywords': <String>['xin chào', 'ăn cơm'],
    },
    <String, Object?>{
      'level': 2,
      'threats': <String, Object?>{
        'URGENCY': <String>['gấp', 'lệnh bắt'],
      },
    },
    <String, Object?>{
      'level': 3,
      'threats': <String, Object?>{
        'AUTHORITY': <String>['công an'],
        'MONEY': <String>['chuyển tiền'],
        'ACCOUNT': <String>['tài khoản ngân hàng'],
        'PII': <String>['mã otp'],
      },
    },
  ],
};

const Map<String, Object?> _testScoringConfig = <String, Object?>{
  'scenario_alert_threshold': 0.6,
  'weights': <String, Object?>{
    'keyword': 0.25,
    'topic': 0.20,
    'pattern': 0.25,
    'scenario': 0.20,
    'context': 0.10,
  },
};

const Map<String, Object?> _testPatterns = <String, Object?>{
  'patterns': <Object?>[
    <String, Object?>{
      'id': 'transfer_now',
      'description': 'Chuyen tien gap',
      'risk_bonus': 0.8,
      'max_gap': 5,
      'template': <Object?>[
        <String, Object?>{'type': 'keyword', 'value': 'chuyển'},
        <String, Object?>{'type': 'keyword', 'value': 'tiền'},
        <String, Object?>{'type': 'keyword', 'value': 'gấp'},
      ],
    },
  ],
};

const Map<String, Object?> _testScenarios = <String, Object?>{
  'title': 'Test Scenarios',
  'version': '1.0',
  'total_scenarios': 1,
  'scenarios': <Object?>[
    <String, Object?>{
      'id': 'S1',
      'name': 'Giả danh công an',
      'risk_level': 3,
      'category': 'AUTH_POLICE_LAWSUIT',
      'trigger_phrases': <String>['công an', 'viện kiểm sát'],
      'required_context': <String>['điều tra', 'lệnh bắt'],
      'l2_analysis_hints': <String, Object?>{
        'urgency_level': 'medium',
        'authority_claim': true,
        'financial_request': false,
      },
    },
  ],
};

const Map<String, Object?> _testSentences = <String, Object?>{
  'riskLevels': <Object?>[
    <String, Object?>{
      'level': 0,
      'sentences': <String>['xin chào hôm nay mình đi ăn cơm nhé'],
    },
    <String, Object?>{
      'level': 3,
      'threats': <String, Object?>{
        'PII': <String>['đọc mã otp vừa gửi'],
      },
    },
  ],
};

const Map<String, Object?> _testSlang = <String, Object?>{
  'slang_map': <String, String>{
    'ck': 'chuyển khoản',
    'stk': 'số tài khoản',
  },
};

const Map<String, Object?> _testTierConfig = <String, Object?>{
  'tier1_topics': <String>['công an'],
  'tier2_urgency': <String>['gấp', 'ngay lập tức', 'lệnh bắt'],
  'tier3_pii': <String>['mã otp', 'tài khoản ngân hàng'],
};