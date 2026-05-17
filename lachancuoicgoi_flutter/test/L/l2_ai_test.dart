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
import 'package:lachancuocgoi_flutter/core/risk_level.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('TFLite intent support', () {
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
      expect(IntentOutputMapper.decodeFlatOutput(<num>[1, 2, 3]), isEmpty);
    });
  });

  group('WFSA and SafetyFilter', () {
    test('default graph set tracks 22 scam scenarios with active stage', () {
      final engine = WfsaEngine(ScamGraphBuilder.buildDefaultGraphs());

      expect(engine.graphs.length, 22);
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

  group('L2 AI intent fusion', () {
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
        'Xin chào, hôm nay mình đi ăn cơm nhé.',
      );

      expect(result.analysisLevel, AnalysisLevel.l2Ai);
      expect(result.overallRiskLevel, RiskLevel.red);
      expect(result.matches.first.keyword, contains('NGÂN HÀNG'));
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
  return GDetectionEngine(
    assetProvider: (fileName) => jsonEncode(_testAssets[fileName] ?? {}),
  );
}

const Map<String, Object> _testAssets = {
  'vocabulary.json': {
    'riskLevels': [
      {'level': 0, 'keywords': ['xin chào', 'ăn cơm']},
      {
        'level': 2,
        'threats': {
          'URGENCY': ['gấp', 'lệnh bắt'],
        }
      },
      {
        'level': 3,
        'threats': {
          'AUTHORITY': ['công an'],
          'MONEY': ['chuyển tiền'],
          'ACCOUNT': ['tài khoản ngân hàng'],
          'PII': ['mã otp'],
        }
      },
    ],
  },
  'scoring_config.json': {
    'scenario_alert_threshold': 0.6,
    'weights': {
      'keyword': 0.25,
      'topic': 0.20,
      'pattern': 0.25,
      'scenario': 0.20,
      'context': 0.10,
    },
  },
  'patterns.json': {
    'patterns': [
      {
        'id': 'transfer_now',
        'description': 'Chuyển tiền gấp',
        'risk_bonus': 0.8,
        'max_gap': 5,
        'template': [
          {'type': 'keyword', 'value': 'chuyển'},
          {'type': 'keyword', 'value': 'tiền'},
          {'type': 'keyword', 'value': 'gấp'},
        ],
      },
    ],
  },
  'situations.json': {
    'title': 'Test Scenarios',
    'version': '1.0',
    'total_scenarios': 1,
    'scenarios': [
      {
        'id': 'S1',
        'name': 'Giả danh công an',
        'risk_level': 3,
        'category': 'AUTH_POLICE_LAWSUIT',
        'trigger_phrases': ['công an', 'viện kiểm sát'],
        'required_context': ['điều tra', 'lệnh bắt'],
        'l2_analysis_hints': {
          'urgency_level': 'medium',
          'authority_claim': true,
          'financial_request': false,
        },
      },
    ],
  },
  'sentences.json': {
    'riskLevels': [
      {
        'level': 0,
        'sentences': ['xin chào hôm nay mình đi ăn cơm nhé'],
      },
      {
        'level': 3,
        'threats': {
          'PII': ['đọc mã otp vừa gửi'],
        },
      },
    ],
  },
  'slang.json': {
    'slang_map': {'ck': 'chuyển khoản', 'stk': 'số tài khoản'},
  },
  'tier_config.json': {
    'tier1_topics': ['công an'],
    'tier2_urgency': ['gấp', 'ngay lập tức', 'lệnh bắt'],
    'tier3_pii': ['mã otp', 'tài khoản ngân hàng'],
  },
  'ai_check_config.json': {'situations': []},
};