// Wave 6 tests: Romance scam scenarios.
//
// Tests that the 6 romance scenarios are correctly built and have
// appropriate structure for the WFSA engine.

import 'package:flutter_test/flutter_test.dart';
import 'package:lachancuocgoi_flutter/analysis/l2/wfsa/scam_graph_builder.dart';
import 'package:lachancuocgoi_flutter/analysis/l2/wfsa/wfsa_engine.dart';

void main() {
  group('Romance Scenarios (Wave 6)', () {
    late List<ScenarioGraph> allScenarios;
    late List<ScenarioGraph> romanceScenarios;

    setUp(() {
      allScenarios = ScamGraphBuilder.buildDefaultGraphs();
      romanceScenarios = allScenarios
          .where((s) => s.graphId.startsWith('ROM_'))
          .toList();
    });

    test('romance scenarios are included in default graphs', () {
      expect(romanceScenarios.length, 6);
    });

    test('all romance scenarios have unique IDs', () {
      final ids = romanceScenarios.map((s) => s.graphId).toSet();
      expect(ids.length, romanceScenarios.length);
    });

    test('all romance scenarios have non-empty names', () {
      for (final scenario in romanceScenarios) {
        expect(
          scenario.name.isNotEmpty,
          true,
          reason: 'Scenario ${scenario.graphId} should have a name',
        );
      }
    });

    test('dating scenario has correct ID', () {
      final dating = romanceScenarios.firstWhere(
        (s) => s.graphId == 'ROM_DATING_01',
        orElse: () => throw StateError('ROM_DATING_01 not found'),
      );
      expect(dating.name, 'Lừa tình qua mạng xã hội');
    });

    test('gift card scenario has correct ID', () {
      final gift = romanceScenarios.firstWhere(
        (s) => s.graphId == 'ROM_GIFT_01',
        orElse: () => throw StateError('ROM_GIFT_01 not found'),
      );
      expect(gift.name, 'Quà tặng kẹt hải quan');
    });

    test('investment together scenario has correct ID', () {
      final invest = romanceScenarios.firstWhere(
        (s) => s.graphId == 'ROM_INVEST_01',
        orElse: () => throw StateError('ROM_INVEST_01 not found'),
      );
      expect(invest.name, 'Đầu tư cùng nhau');
    });

    test('emergency scenario has correct ID', () {
      final emergency = romanceScenarios.firstWhere(
        (s) => s.graphId == 'ROM_EMERGENCY_01',
        orElse: () => throw StateError('ROM_EMERGENCY_01 not found'),
      );
      expect(emergency.name, 'Khẩn cấp gửi tiền');
    });

    test('passport scenario has correct ID', () {
      final passport = romanceScenarios.firstWhere(
        (s) => s.graphId == 'ROM_PASSPORT_01',
        orElse: () => throw StateError('ROM_PASSPORT_01 not found'),
      );
      expect(passport.name, 'Passport bị giữ');
    });

    test('customs scenario has correct ID', () {
      final customs = romanceScenarios.firstWhere(
        (s) => s.graphId == 'ROM_CUSTOMS_01',
        orElse: () => throw StateError('ROM_CUSTOMS_01 not found'),
      );
      expect(customs.name, 'Bưu kiện hải quan (loại 2)');
    });

    test('all scenarios have at least one state', () {
      for (final scenario in romanceScenarios) {
        expect(
          scenario.states.isNotEmpty,
          true,
          reason: 'Scenario ${scenario.graphId} should have states',
        );
      }
    });

    test('total scenario count is correct with Wave 6', () {
      // Original 24 + 8 investment + 6 romance = 38
      expect(allScenarios.length, 38);
    });
  });
}
