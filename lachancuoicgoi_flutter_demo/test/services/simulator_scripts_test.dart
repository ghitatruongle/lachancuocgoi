import 'package:flutter_test/flutter_test.dart';
import 'package:lachancuocgoi_flutter/services/simulator/simulator_scripts.dart';

void main() {
  group('SimulatorScriptCatalog', () {
    test('exposes at least 3 scenarios', () {
      expect(SimulatorScriptCatalog.all.length, greaterThanOrEqualTo(3));
    });

    test('each script has non-empty id, title, and >=3 lines', () {
      for (final s in SimulatorScriptCatalog.all) {
        expect(s.id, isNotEmpty);
        expect(s.title, isNotEmpty);
        expect(s.lines.length, greaterThanOrEqualTo(3));
      }
    });

    test('catalog can look up by id', () {
      final first = SimulatorScriptCatalog.all.first;
      expect(SimulatorScriptCatalog.byId(first.id), same(first));
    });

    test('byId returns null for unknown id', () {
      expect(SimulatorScriptCatalog.byId('nonexistent'), isNull);
    });

    test('all ids are unique', () {
      final ids = SimulatorScriptCatalog.all.map((s) => s.id).toList();
      expect(ids.toSet().length, ids.length);
    });
  });
}
