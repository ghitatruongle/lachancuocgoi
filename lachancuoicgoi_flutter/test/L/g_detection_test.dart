import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:lachancuocgoi_flutter/analysis/analysis_level.dart';
import 'package:lachancuocgoi_flutter/analysis/l2/g_detection/g_detection_engine.dart';
import 'package:lachancuocgoi_flutter/analysis/l2/g_detection/g_flash.dart';
import 'package:lachancuocgoi_flutter/analysis/l2/l2_result.dart';
import 'package:lachancuocgoi_flutter/core/risk_level.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Phase 5 GDetection tokenizer and engine', () {
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
        final engine = GDetectionEngine();
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
    GDetectionEngine.aiCheckFile: {'situations': []},
  };

  return GDetectionEngine(
    assetProvider: (fileName) => jsonEncode(assets[fileName] ?? {}),
  );
}

const Map<String, Object?> _testVocabulary = {
  'riskLevels': [
    {
      'level': 0,
      'keywords': ['xin chao', 'an com'],
    },
    {
      'level': 2,
      'threats': {
        'URGENCY': ['gap', 'ngay lap tuc'],
      },
    },
    {
      'level': 3,
      'threats': {
        'AUTHORITY': ['cong an'],
        'MONEY': ['chuyen tien'],
        'ACCOUNT': ['tai khoan ngan hang'],
        'PII': ['ma otp'],
      },
    },
  ],
};

const Map<String, Object?> _testScoringConfig = {
  'scenario_alert_threshold': 0.6,
  'weights': {
    'keyword': 0.25,
    'topic': 0.20,
    'pattern': 0.25,
    'scenario': 0.20,
    'context': 0.10,
  },
};

const Map<String, Object?> _testPatterns = {
  'patterns': [
    {
      'id': 'transfer_now',
      'description': 'Chuyen tien gap',
      'risk_bonus': 0.8,
      'max_gap': 5,
      'template': [
        {'type': 'keyword', 'value': 'chuyen'},
        {'type': 'keyword', 'value': 'tien'},
        {'type': 'keyword', 'value': 'gap'},
      ],
    },
  ],
};

const Map<String, Object?> _testScenarios = {
  'title': 'Test Scenarios',
  'version': '1.0',
  'total_scenarios': 1,
  'scenarios': [
    {
      'id': 'S1',
      'name': 'Gia danh cong an',
      'risk_level': 3,
      'category': 'AUTH_POLICE_LAWSUIT',
      'trigger_phrases': ['cong an', 'vien kiem sat'],
      'required_context': ['dieu tra', 'lenh bat'],
      'l2_analysis_hints': {
        'urgency_level': 'medium',
        'authority_claim': true,
        'financial_request': false,
      },
    },
  ],
};

const Map<String, Object?> _testSentences = {
  'riskLevels': [
    {
      'level': 0,
      'sentences': ['xin chao hom nay minh di an com nhe'],
    },
    {
      'level': 3,
      'threats': {
        'PII': ['doc ma otp vua gui'],
      },
    },
  ],
};

const Map<String, Object?> _testSlang = {
  'slang_map': {'ck': 'chuyen khoan', 'stk': 'so tai khoan'},
};

const Map<String, Object?> _testTierConfig = {
  'tier1_topics': ['cong an'],
  'tier2_urgency': ['gap', 'ngay lap tuc', 'lenh bat'],
  'tier3_pii': ['ma otp', 'tai khoan ngan hang'],
};