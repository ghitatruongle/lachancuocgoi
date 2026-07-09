import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:lachancuocgoi_flutter/analysis/analysis_level.dart';
import 'package:lachancuocgoi_flutter/analysis/l2/g_detection/g_detection_engine.dart';
import 'package:lachancuocgoi_flutter/analysis/l2/intent/bert_intent_tokenizer.dart';
import 'package:lachancuocgoi_flutter/analysis/l2/intent/intent_classifier.dart';
import 'package:lachancuocgoi_flutter/analysis/l2/intent/intent_output_mapper.dart';
import 'package:lachancuocgoi_flutter/analysis/l2/intent/scam_intent.dart';
import 'package:lachancuocgoi_flutter/analysis/l2/l2_analysis.dart';
import 'package:lachancuocgoi_flutter/analysis/l2/safety/safety_filter.dart';
import 'package:lachancuocgoi_flutter/analysis/l2/wfsa/scam_graph_builder.dart';
import 'package:lachancuocgoi_flutter/analysis/l2/wfsa/wfsa_engine.dart';
import 'package:lachancuocgoi_flutter/analysis/health_check.dart';
import 'package:lachancuocgoi_flutter/core/risk_level.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Phase 6 TFLite intent support', () {
    test('WordPiece tokenizer builds Kotlin-compatible BERT inputs', () {
      final tokenizer = BertIntentTokenizer(<String, int>{
        '[PAD]': 0,
        '[UNK]': 100,
        '[CLS]': 101,
        '[SEP]': 102,
        'chuyen': 201,
        '##khoan': 202,
        'tien': 203,
      });

      expect(tokenizer.tokenize('chuyenkhoan tien!!!'), <String>[
        'chuyen',
        '##khoan',
        'tien',
      ]);

      final inputs = tokenizer.buildInputs(tokenizer.tokenize('chuyen tien'));
      expect(inputs.inputIds.length, BertIntentTokenizer.maxSeqLen);
      expect(inputs.inputIds.take(4), <int>[101, 201, 203, 102]);
      expect(inputs.attentionMask.take(4), <int>[1, 1, 1, 1]);
      expect(inputs.tokenTypeIds.toSet(), <int>{0});
    });

    test('WordPiece tokenizer handles out-of-vocabulary words and casing', () {
      final tokenizer = BertIntentTokenizer(<String, int>{
        '[PAD]': 0,
        '[UNK]': 100,
        '[CLS]': 101,
        '[SEP]': 102,
        'chuyen': 201,
      });

      expect(tokenizer.tokenize('CHUYEN la hoan-toan-la'), <String>[
        'chuyen',
        '[UNK]',
        '[UNK]',
        '[UNK]',
        '[UNK]',
      ]);
    });

    test('decodes quantized outputs and sorts intent probabilities', () {
      final raw = List<num>.filled(intentLabels.length, 128);
      raw[ScamIntent.bankCardFraud.index] = 168;

      final logits = IntentOutputMapper.decodeFlatOutput(
        raw,
        outputType: IntentOutputType.uint8,
        scale: 0.1,
        zeroPoint: 128,
      );
      final predictions = IntentOutputMapper.predictionsFromLogits(logits);

      expect(predictions.first.intent, ScamIntent.bankCardFraud);
      expect(predictions.first.confidence, greaterThan(0.60));
      // Very short tensor: graceful mismatch fills remaining with 0.
      expect(
        IntentOutputMapper.decodeFlatOutput(<num>[1, 2, 3]).length,
        intentLabels.length,
      );
    });

    test('softmax computes correct probabilities and handles edge cases', () {
      final probs = IntentOutputMapper.softmax(<double>[1.0, 2.0, 3.0]);
      expect(probs.length, 3);
      expect(probs[2], greaterThan(probs[1]));
      expect(probs[1], greaterThan(probs[0]));
      expect(probs.reduce((a, b) => a + b), closeTo(1.0, 0.0001));

      expect(IntentOutputMapper.softmax(<double>[]), isEmpty);

      final extreme = IntentOutputMapper.softmax(<double>[
        1000.0,
        1000.0,
        1000.0,
      ]);
      expect(extreme, <double>[1 / 3, 1 / 3, 1 / 3]);
    });

    test(
      'decodeFlatOutput supports int8 quantization and float32 pass-through',
      () {
        final rawFloat = List<num>.filled(intentLabels.length, 2.5);
        final decodedFloat = IntentOutputMapper.decodeFlatOutput(
          rawFloat,
          outputType: IntentOutputType.float32,
        );
        expect(decodedFloat.every((x) => x == 2.5), isTrue);

        final rawInt8 = List<num>.filled(intentLabels.length, -10);
        rawInt8[0] = 50;
        final decodedInt8 = IntentOutputMapper.decodeFlatOutput(
          rawInt8,
          outputType: IntentOutputType.int8,
          scale: 0.5,
          zeroPoint: 10,
        );
        expect(decodedInt8[0], (50 - 10) * 0.5); // 20.0
        expect(decodedInt8[1], (-10 - 10) * 0.5); // -10.0
      },
    );
  });

  group('Phase 6 WFSA and SafetyFilter', () {
    test('default graph set tracks 38 scam scenarios with active stage', () {
      final engine = WfsaEngine(ScamGraphBuilder.buildDefaultGraphs());

      expect(engine.graphs.length, 38);
      final firstScore = engine.analyzeSegment(
        'cục cảnh sát đang điều tra',
        const <IntentPrediction>[],
      );
      final secondScore = engine.analyzeSegment(
        'đường dây ma túy và lệnh bắt khẩn cấp',
        const <IntentPrediction>[],
      );

      expect(firstScore, greaterThan(0));
      expect(secondScore, greaterThan(firstScore));
      expect(engine.activeScenarioName, 'Giả danh cơ quan pháp luật');
      expect(engine.activeScenarioStage, 2);
    });

    test(
      'SafetyFilter discounts only safe openings without danger later',
      () async {
        await SafetyFilter.loadConfig(
          assetProvider: (_) => jsonEncode(<String, Object?>{
            'openingSectionLength': 12,
            'casualPhrases': <String>['alo'],
            'standardTransactions': <String>['tiền trọ'],
            'dangerOverrides': <String>['otp'],
            'casualReductionPerMatch': 0.15,
            'transactionReductionPerMatch': 0.30,
            'minMultiplier': 0.4,
          }),
        );

        expect(
          SafetyFilter.calculateSafetyDiscount('alo bạn khỏe không'),
          0.85,
        );
        expect(
          SafetyFilter.calculateSafetyDiscount(
            'alo bạn ơi sau đó đọc mã otp cho tôi',
          ),
          1.0,
        );
        expect(SafetyFilter.calculateSafetyDiscount('chuyển tiền trọ'), 0.70);
      },
    );
  });

  group('Phase 6 L2 fusion', () {
    test(
      'falls back to GDetection and WFSA when intent classifier is disabled',
      () async {
        final analyzer = L2Analyzer(gDetectionEngine: _newTestEngine());
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

    test('uses high-confidence AI intent as L2-AI winner', () async {
      final analyzer = L2Analyzer(
        gDetectionEngine: _newTestEngine(),
        intentClassifier: _FakeIntentClassifier(<IntentPrediction>[
          const IntentPrediction(
            intent: ScamIntent.bankCardFraud,
            confidence: 0.90,
          ),
          const IntentPrediction(intent: ScamIntent.safe, confidence: 0.02),
        ]),
      );
      await analyzer.initialize();

      final result = await analyzer.analyze(
        'xin chào',
        'Xin chào, hôm nay mình đi ăn cơm nhé. Nhưng thực ra tôi rất muốn nói chuyện với bạn nhiều hơn nữa để xem bạn có khỏe không nhé.',
      );

      expect(result.analysisLevel, AnalysisLevel.l2Ai);
      expect(result.overallRiskLevel, RiskLevel.red);
      expect(result.matches.first.keyword, contains('NGÂN HÀNG'));
    });

    test('GDetection overrides SAFE AI when context is red', () async {
      final analyzer = L2Analyzer(
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
        'AUTHORITY': <String>['tôi là công an'],
        'PII': <String>['đọc mã otp vừa gửi'],
      },
    },
  ],
};

const Map<String, Object?> _testSlang = <String, Object?>{
  'slang_map': <String, Object?>{'ck': 'chuyển khoản', 'stk': 'số tài khoản'},
};

const Map<String, Object?> _testTierConfig = <String, Object?>{
  'tier1_topics': <String>['công an'],
  'tier2_urgency': <String>['gấp', 'lệnh bắt'],
  'tier3_pii': <String>['mã otp', 'tài khoản ngân hàng'],
};
