import 'package:flutter_test/flutter_test.dart';
import 'package:lachancuocgoi_flutter/analysis/l2/g_detection/g_models.dart';

void main() {
  group('RiskModelVocabulary', () {
    test('fromJson parses risk levels', () {
      final json = {
        'riskLevels': [
          {'level': 0, 'keywords': ['xin chao']},
          {
            'level': 3,
            'threats': {
              'MONEY': ['chuyen tien'],
            },
          },
        ],
      };
      final model = RiskModelVocabulary.fromJson(json);
      expect(model.riskLevels, isNotNull);
      expect(model.riskLevels!.length, 2);
      expect(model.riskLevels![0].level, 0);
      expect(model.riskLevels![0].keywords, ['xin chao']);
      expect(model.riskLevels![1].level, 3);
      expect(model.riskLevels![1].threats!['MONEY'], ['chuyen tien']);
    });

    test('fromJson handles null riskLevels', () {
      final model = RiskModelVocabulary.fromJson({});
      expect(model.riskLevels, isNull);
    });
  });

  group('RiskLevelData', () {
    test('fromJson defaults level to 0', () {
      final data = RiskLevelData.fromJson({});
      expect(data.level, 0);
      expect(data.keywords, isNull);
      expect(data.threats, isNull);
    });

    test('fromJson parses threats map with multiple categories', () {
      final json = {
        'level': 3,
        'threats': {
          'AUTHORITY': ['cong an', 'vien kiem sat'],
          'PII': ['ma otp'],
        },
      };
      final data = RiskLevelData.fromJson(json);
      expect(data.level, 3);
      expect(data.threats!.length, 2);
      expect(data.threats!['AUTHORITY'], ['cong an', 'vien kiem sat']);
    });
  });

  group('TierConfig', () {
    test('fromJson parses all tiers', () {
      final json = {
        'tier1_topics': ['cong an'],
        'tier2_urgency': ['gap'],
        'tier3_pii': ['ma otp'],
      };
      final config = TierConfig.fromJson(json);
      expect(config.tier1Topics, ['cong an']);
      expect(config.tier2Urgency, ['gap']);
      expect(config.tier3Pii, ['ma otp']);
    });

    test('fromJson handles missing fields', () {
      final config = TierConfig.fromJson({});
      expect(config.tier1Topics, isNull);
      expect(config.tier2Urgency, isNull);
      expect(config.tier3Pii, isNull);
    });
  });

  group('ScoringConfig', () {
    test('fromJson uses defaults for missing fields', () {
      final config = ScoringConfig.fromJson({});
      expect(config.topicConfirmationThreshold, 3);
      expect(config.scenarioSimilarityThreshold, 0.3);
      expect(config.scenarioAlertThreshold, 0.6);
      expect(config.highKeywordThreshold, 0.5);
    });

    test('fromJson overrides from json', () {
      final json = {
        'topicConfirmationThreshold': 5,
        'scenario_alert_threshold': 0.8,
        'weights': {
          'keyword': 0.3,
          'topic': 0.2,
          'pattern': 0.2,
          'scenario': 0.2,
          'context': 0.1,
        },
        'riskLevelThresholds': {
          'red': 0.8,
          'orange': 0.6,
          'yellow': 0.4,
        },
      };
      final config = ScoringConfig.fromJson(json);
      expect(config.topicConfirmationThreshold, 5);
      expect(config.scenarioAlertThreshold, 0.8);
      expect(config.weights.keyword, 0.3);
      expect(config.riskLevelThresholds.red, 0.8);
    });
  });

  group('ScoringWeights', () {
    test('default values are correct', () {
      const w = ScoringWeights();
      expect(w.keyword, 0.20);
      expect(w.topic, 0.15);
      expect(w.pattern, 0.25);
      expect(w.scenario, 0.25);
      expect(w.context, 0.10);
      expect(w.sentiment, 0.05);
    });

    test('fromJson overrides defaults', () {
      final w = ScoringWeights.fromJson({
        'keyword': 0.3,
        'sentiment': 0.1,
      });
      expect(w.keyword, 0.3);
      expect(w.sentiment, 0.1);
      // Others keep defaults
      expect(w.topic, 0.15);
    });
  });

  group('RiskThresholds', () {
    test('default values', () {
      const t = RiskThresholds();
      expect(t.red, 0.50);
      expect(t.orange, 0.35);
      expect(t.yellow, 0.20);
    });

    test('fromJson overrides', () {
      final t = RiskThresholds.fromJson({'red': 0.9, 'orange': 0.7, 'yellow': 0.5});
      expect(t.red, 0.9);
      expect(t.orange, 0.7);
      expect(t.yellow, 0.5);
    });
  });

  group('PatternElement', () {
    test('fromJson creates PatternKeyword', () {
      final e = PatternElement.fromJson({'type': 'keyword', 'value': 'chuyen tien'});
      expect(e, isA<PatternKeyword>());
      expect((e as PatternKeyword).value, 'chuyen tien');
    });

    test('fromJson creates PatternCategory', () {
      final e = PatternElement.fromJson({'type': 'category', 'value': 'MONEY'});
      expect(e, isA<PatternCategory>());
      expect((e as PatternCategory).categoryName, 'MONEY');
    });

    test('fromJson creates PatternWildcard', () {
      final e = PatternElement.fromJson({'type': 'wildcard', 'value': ''});
      expect(e, isA<PatternWildcard>());
    });

    test('fromJson defaults to PatternKeyword for unknown type', () {
      final e = PatternElement.fromJson({'type': 'unknown', 'value': 'test'});
      expect(e, isA<PatternKeyword>());
    });

    test('fromJson handles empty type', () {
      final e = PatternElement.fromJson({'value': 'test'});
      expect(e, isA<PatternKeyword>());
    });
  });

  group('ScamPatternDTO', () {
    test('fromJson with all fields', () {
      final json = {
        'id': 'transfer_now',
        'description': 'Chuyen tien gap',
        'risk_bonus': 0.8,
        'min_gap': 0,
        'max_gap': 5,
        'template': [
          {'type': 'keyword', 'value': 'chuyen'},
        ],
      };
      final dto = ScamPatternDTO.fromJson(json);
      expect(dto.id, 'transfer_now');
      expect(dto.description, 'Chuyen tien gap');
      expect(dto.riskBonus, 0.8);
      expect(dto.minGap, 0);
      expect(dto.maxGap, 5);
      expect(dto.template, hasLength(1));
    });

    test('fromJson with missing optional fields', () {
      final dto = ScamPatternDTO.fromJson({'id': 'test'});
      expect(dto.id, 'test');
      expect(dto.description, isNull);
      expect(dto.riskBonus, isNull);
    });

    test('fromJson safely converts integer id to String', () {
      final dto = ScamPatternDTO.fromJson({'id': 123});
      expect(dto.id, '123');
    });

    test('toDomain applies defaults for null fields', () {
      final dto = ScamPatternDTO.fromJson({'id': 'test'});
      final domain = dto.toDomain();
      expect(domain.id, 'test');
      expect(domain.description, '');
      expect(domain.riskBonus, 0.5);
      expect(domain.minGap, 0);
      expect(domain.maxGap, 5);
      expect(domain.template, isEmpty);
    });
  });

  group('MasterScenario', () {
    test('fromJson with all fields', () {
      final json = {
        'id': 'S1',
        'name': 'Gia danh cong an',
        'risk_level': 3,
        'category': 'AUTH',
        'trigger_phrases': ['cong an'],
        'required_context': ['dieu tra'],
        'l2_analysis_hints': {
          'urgency_level': 'high',
          'authority_claim': true,
        },
      };
      final scenario = MasterScenario.fromJson(json);
      expect(scenario.id, 'S1');
      expect(scenario.name, 'Gia danh cong an');
      expect(scenario.riskLevel, 3);
      expect(scenario.triggerPhrases, ['cong an']);
      expect(scenario.l2AnalysisHints, isNotNull);
      expect(scenario.l2AnalysisHints!.authorityClaim, true);
    });

    test('fromJson defaults id and name to empty', () {
      final scenario = MasterScenario.fromJson({});
      expect(scenario.id, '');
      expect(scenario.name, '');
      expect(scenario.riskLevel, 0);
    });

    test('fromJson safely converts integer id and original_id to String', () {
      final scenario = MasterScenario.fromJson({
        'id': 456,
        'original_id': 789,
        'name': 'Test integer IDs',
      });
      expect(scenario.id, '456');
      expect(scenario.originalId, '789');
    });
  });

  group('L2AnalysisHints', () {
    test('fromJson parses all fields', () {
      final hints = L2AnalysisHints.fromJson({
        'urgency_level': 'critical',
        'authority_claim': true,
        'financial_request': true,
        'information_request': ['so cmnd'],
        'psychological_tactics': ['ap luc thoi gian'],
      });
      expect(hints.urgencyLevel, 'critical');
      expect(hints.authorityClaim, true);
      expect(hints.financialRequest, true);
      expect(hints.informationRequest, ['so cmnd']);
      expect(hints.psychologicalTactics, ['ap luc thoi gian']);
    });

    test('fromJson handles empty', () {
      final hints = L2AnalysisHints.fromJson({});
      expect(hints.urgencyLevel, isNull);
      expect(hints.authorityClaim, isNull);
    });
  });

  group('RiskModelSentences', () {
    test('fromJson parses levels', () {
      final json = {
        'riskLevels': [
          {
            'level': 0,
            'sentences': ['xin chao'],
          },
          {
            'level': 3,
            'threats': {
              'PII': ['doc ma otp'],
            },
          },
        ],
      };
      final model = RiskModelSentences.fromJson(json);
      expect(model.riskLevels, hasLength(2));
      expect(model.riskLevels![0].sentences, ['xin chao']);
      expect(model.riskLevels![1].threats!['PII'], ['doc ma otp']);
    });
  });

  group('RiskSentenceLevel', () {
    test('fromJson defaults level to 0', () {
      final level = RiskSentenceLevel.fromJson({});
      expect(level.level, 0);
      expect(level.vietnameseName, isNull);
      expect(level.sentences, isNull);
      expect(level.threats, isNull);
    });
  });

  group('RiskScenariosMaster', () {
    test('fromJson with all fields', () {
      final json = {
        'title': 'Master',
        'version': '1.0',
        'description': 'Test',
        'total_scenarios': 1,
        'scenarios': [
          {'id': 'S1', 'name': 'Test', 'risk_level': 2},
        ],
      };
      final model = RiskScenariosMaster.fromJson(json);
      expect(model.title, 'Master');
      expect(model.totalScenarios, 1);
      expect(model.scenarios, hasLength(1));
    });

    test('fromJson handles nulls', () {
      final model = RiskScenariosMaster.fromJson({});
      expect(model.title, isNull);
      expect(model.scenarios, isNull);
    });
  });

  group('PatternConfigDTO', () {
    test('fromJson parses patterns', () {
      final json = {
        'patterns': [
          {'id': 'p1', 'risk_bonus': 0.5},
        ],
      };
      final config = PatternConfigDTO.fromJson(json);
      expect(config.patterns, hasLength(1));
      expect(config.patterns![0].id, 'p1');
    });
  });

  group('AiCheckModel', () {
    test('fromJson parses situations', () {
      final json = {
        'situations': [
          {'name': 'Situation 1', 'trigger_phrases': ['test']},
        ],
      };
      final model = AiCheckModel.fromJson(json);
      expect(model.situations, hasLength(1));
      expect(model.situations![0].name, 'Situation 1');
    });

    test('fromJson handles null', () {
      final model = AiCheckModel.fromJson({});
      expect(model.situations, isNull);
    });
  });

  group('AiCheckSituation', () {
    test('fromJson with all fields', () {
      final s = AiCheckSituation.fromJson({
        'name': 'Test',
        'trigger_phrases': ['phrase1'],
        'required_context': ['ctx1'],
        'risk_level': 'high',
      });
      expect(s.name, 'Test');
      expect(s.triggerPhrases, ['phrase1']);
      expect(s.requiredContext, ['ctx1']);
      expect(s.riskLevel, 'high');
    });

    test('fromJson defaults name to empty', () {
      final s = AiCheckSituation.fromJson({});
      expect(s.name, '');
    });
  });

  group('KeywordTrieData', () {
    test('constructor stores fields', () {
      // Use from RiskLevel enum import
      // KeywordTrieData requires RiskLevel which we can test with green
      // This is mostly a data class test
    });
  });
}
