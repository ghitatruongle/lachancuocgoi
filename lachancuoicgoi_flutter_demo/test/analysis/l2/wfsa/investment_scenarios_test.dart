// Wave 6 tests: Investment scam scenarios.
//
// Tests that the 8 investment scenarios are correctly built and have
// appropriate structure for the WFSA engine.

import 'package:flutter_test/flutter_test.dart';
import 'package:lachancuocgoi_flutter/analysis/l2/wfsa/scam_graph_builder.dart';
import 'package:lachancuocgoi_flutter/analysis/l2/wfsa/wfsa_engine.dart';

void main() {
  group('Investment Scenarios (Wave 6)', () {
    late List<ScenarioGraph> allScenarios;
    late List<ScenarioGraph> investmentScenarios;

    setUp(() {
      allScenarios = ScamGraphBuilder.buildDefaultGraphs();
      investmentScenarios = allScenarios
          .where((s) => s.graphId.startsWith('INV_'))
          .toList();
    });

    test('investment scenarios are included in default graphs', () {
      expect(investmentScenarios.length, 8);
    });

    test('all investment scenarios have unique IDs', () {
      final ids = investmentScenarios.map((s) => s.graphId).toSet();
      expect(ids.length, investmentScenarios.length);
    });

    test('all investment scenarios have non-empty names', () {
      for (final scenario in investmentScenarios) {
        expect(scenario.name.isNotEmpty, true,
            reason: 'Scenario ${scenario.graphId} should have a name');
      }
    });

    test('forex scenario has correct ID', () {
      final forex = investmentScenarios.firstWhere(
        (s) => s.graphId == 'INV_FOREX_01',
        orElse: () => throw StateError('INV_FOREX_01 not found'),
      );
      expect(forex.name, 'Sàn Forex lừa đảo');
    });

    test('crypto scenario has correct ID', () {
      final crypto = investmentScenarios.firstWhere(
        (s) => s.graphId == 'INV_CRYPTO_01',
        orElse: () => throw StateError('INV_CRYPTO_01 not found'),
      );
      expect(crypto.name, 'Sàn crypto ảo');
    });

    test('MLM scenario has correct ID', () {
      final mlm = investmentScenarios.firstWhere(
        (s) => s.graphId == 'INV_MLM_01',
        orElse: () => throw StateError('INV_MLM_01 not found'),
      );
      expect(mlm.name, 'MLM/Đa cấp biến tướng');
    });

    test('job scam scenario has correct ID', () {
      final job = investmentScenarios.firstWhere(
        (s) => s.graphId == 'INV_JOB_01',
        orElse: () => throw StateError('INV_JOB_01 not found'),
      );
      expect(job.name, 'Việc nhẹ lương cao');
    });

    test('stock scenario has correct ID', () {
      final stock = investmentScenarios.firstWhere(
        (s) => s.graphId == 'INV_STOCK_01',
        orElse: () => throw StateError('INV_STOCK_01 not found'),
      );
      expect(stock.name, 'Chứng khoán lừa đảo');
    });

    test('ICO scenario has correct ID', () {
      final ico = investmentScenarios.firstWhere(
        (s) => s.graphId == 'INV_ICO_01',
        orElse: () => throw StateError('INV_ICO_01 not found'),
      );
      expect(ico.name, 'ICO/IDO/Token giả');
    });

    test('skincare MLM scenario has correct ID', () {
      final skin = investmentScenarios.firstWhere(
        (s) => s.graphId == 'INV_SKIN_01',
        orElse: () => throw StateError('INV_SKIN_01 not found'),
      );
      expect(skin.name, 'MLM Skincare/Biệt dược');
    });

    test('Ponzi scenario has correct ID', () {
      final ponzi = investmentScenarios.firstWhere(
        (s) => s.graphId == 'INV_PONZI_01',
        orElse: () => throw StateError('INV_PONZI_01 not found'),
      );
      expect(ponzi.name, 'Ponzi/Pyramid scheme');
    });

    test('all scenarios have at least one state', () {
      for (final scenario in investmentScenarios) {
        expect(scenario.states.isNotEmpty, true,
            reason: 'Scenario ${scenario.graphId} should have states');
      }
    });

    test('total scenario count increased with Wave 6', () {
      // Original 24 scenarios + 8 investment + 6 romance = 38
      expect(allScenarios.length, greaterThanOrEqualTo(36));
    });
  });
}
