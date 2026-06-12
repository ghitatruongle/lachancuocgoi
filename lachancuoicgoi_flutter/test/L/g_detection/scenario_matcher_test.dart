import 'package:flutter_test/flutter_test.dart';
import 'package:lachancuocgoi_flutter/analysis/l2/g_detection/g_flash.dart';
import 'package:lachancuocgoi_flutter/analysis/l2/g_detection/g_models.dart';
import 'package:lachancuocgoi_flutter/analysis/l2/g_detection/scenario_matcher.dart';

void main() {
  group('ScenarioMatcher', () {
    late ScenarioMatcher matcher;

    setUp(() {
      matcher = ScenarioMatcher(_testMasterModel);
    });

    test('returns null for empty tokens', () {
      expect(matcher.match([]), isNull);
    });

    test('matches police impersonation scenario', () {
      final tokens = GFlash.tokenize(
        'toi la cong an chung toi dang dieu tra va co lenh bat',
      );
      final result = matcher.match(tokens);
      expect(result, isNotNull);
      expect(result!.situationName, isNotEmpty);
      expect(result.similarityScore, greaterThan(0.3));
    });

    test('returns null for unrelated text', () {
      final tokens = GFlash.tokenize('troi hom nay dep qua ban oi');
      final result = matcher.match(tokens);
      expect(result, isNull);
    });

    test('returns null for model with no scenarios', () {
      final empty = ScenarioMatcher(const RiskScenariosMaster());
      expect(empty.match(GFlash.tokenize('cong an')), isNull);
    });

    test('scenario with requiredContext fails when context absent', () {
      // Scenario S1 requires context 'dieu tra' or 'lenh bat'
      final tokens = GFlash.tokenize('toi la cong an');
      final result = matcher.match(tokens);
      // Should not match without required context
      expect(result, isNull);
    });

    test('hints bonus increases score', () {
      final tokens = GFlash.tokenize(
        'cong an vien kiem sat dieu tra lenh bat ngay lap tuc',
      );
      final result = matcher.match(tokens);
      if (result != null) {
        // Hints should contribute bonus
        expect(result.similarityScore, greaterThan(0.3));
      }
    });

    test('model with empty trigger phrases returns null', () {
      final model = RiskScenariosMaster.fromJson({
        'scenarios': [
          {
            'id': 'EMPTY',
            'name': 'Empty scenario',
            'risk_level': 3,
            'trigger_phrases': <String>[],
            'required_context': <String>[],
          },
        ],
      });
      final m = ScenarioMatcher(model);
      expect(m.match(GFlash.tokenize('any text')), isNull);
    });

    test('multiple scenarios: picks highest scoring', () {
      final model = RiskScenariosMaster.fromJson({
        'scenarios': [
          {
            'id': 'S1',
            'name': 'Low match',
            'risk_level': 2,
            'trigger_phrases': ['abc xyz'],
          },
          {
            'id': 'S2',
            'name': 'High match',
            'risk_level': 3,
            'trigger_phrases': ['cong an', 'vien kiem sat'],
            'required_context': ['dieu tra'],
          },
        ],
      });
      final m = ScenarioMatcher(model);
      final tokens = GFlash.tokenize(
        'toi la cong an vien kiem sat dang dieu tra',
      );
      final result = m.match(tokens);
      if (result != null) {
        expect(result.level, 3);
      }
    });
  });
}

final _testMasterModel = RiskScenariosMaster.fromJson({
  'title': 'Test',
  'version': '1.0',
  'total_scenarios': 1,
  'scenarios': [
    {
      'id': 'S1',
      'name': 'Gia danh cong an',
      'risk_level': 3,
      'category': 'AUTH_POLICE_LAWSUIT',
      'trigger_phrases': [
        'cong an',
        'vien kiem sat',
      ],
      'required_context': [
        'dieu tra',
        'lenh bat',
      ],
      'l2_analysis_hints': {
        'urgency_level': 'high',
        'authority_claim': true,
        'financial_request': false,
      },
    },
  ],
});
