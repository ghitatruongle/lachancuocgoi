import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lachancuocgoi_flutter/ui/simulation_page/simulation_controller.dart';
import 'package:lachancuocgoi_flutter/ui/simulation_page/simulation_data.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  ProviderContainer createContainer() {
    final container = ProviderContainer();
    addTearDown(container.dispose);
    return container;
  }

  // ─── Initial state ───────────────────────────────────────────────────
  group('SimulationController — initial state', () {
    test('has null scenarios before loadData', () {
      final container = createContainer();
      final state = container.read(simulationControllerProvider);

      expect(state.scenarios, isNull);
      expect(state.filteredScenarios, isEmpty);
      expect(state.categories, isEmpty);
      expect(state.searchQuery, '');
      expect(state.selectedCategory, isNull);
      expect(state.isDevMode, false);
    });

    test('updateSearchQuery before loadData resets state', () {
      final container = createContainer();
      final notifier = container.read(simulationControllerProvider.notifier);

      // Before loadData, _allScenarios is null, so _recompute resets state
      notifier.updateSearchQuery('OTP');
      final state = container.read(simulationControllerProvider);

      expect(state.searchQuery, '');
      expect(state.filteredScenarios, isEmpty);
    });

    test('updateSelectedCategory before loadData resets state', () {
      final container = createContainer();
      final notifier = container.read(simulationControllerProvider.notifier);

      notifier.updateSelectedCategory('Lừa đảo');
      final state = container.read(simulationControllerProvider);

      expect(state.selectedCategory, isNull);
    });
  });

  // ─── Scenario data models ────────────────────────────────────────────
  group('SimulationScenarioData', () {
    test('fromJson parses correctly', () {
      final json = {
        'title': 'Test Scenario',
        'description': 'A test scenario',
        'category': 'Lừa đảo',
        'riskLevel': 'RED',
        'iconEmoji': '🔴',
        'script': [
          {'speaker': 'Kẻ lừa đảo', 'line': 'Xin chào', 'delay': 1000},
        ],
      };

      final data = SimulationScenarioData.fromJson(json);

      expect(data.title, 'Test Scenario');
      expect(data.description, 'A test scenario');
      expect(data.category, 'Lừa đảo');
      expect(data.riskLevel, 'RED');
      expect(data.iconEmoji, '🔴');
      expect(data.script, hasLength(1));
      expect(data.script.first.speaker, 'Kẻ lừa đảo');
      expect(data.script.first.line, 'Xin chào');
      expect(data.script.first.delay, 1000);
    });

    test('fromJson handles missing fields with defaults', () {
      final json = <String, dynamic>{};
      final data = SimulationScenarioData.fromJson(json);

      expect(data.title, '');
      expect(data.description, '');
      expect(data.category, 'Chung');
      expect(data.riskLevel, 'GREEN');
      expect(data.iconEmoji, '📞');
      expect(data.script, isEmpty);
    });

    test('fromJson handles empty script list', () {
      final json = {'title': 'Test', 'script': <dynamic>[]};
      final data = SimulationScenarioData.fromJson(json);
      expect(data.script, isEmpty);
    });

    test('fromJson handles null script', () {
      final json = {'title': 'Test'};
      final data = SimulationScenarioData.fromJson(json);
      expect(data.script, isEmpty);
    });
  });

  group('SimulationScriptLine', () {
    test('fromJson parses correctly', () {
      final json = {
        'speaker': 'Nạn nhân',
        'line': 'Tôi sẽ chuyển tiền',
        'delay': 2000,
      };

      final line = SimulationScriptLine.fromJson(json);

      expect(line.speaker, 'Nạn nhân');
      expect(line.line, 'Tôi sẽ chuyển tiền');
      expect(line.delay, 2000);
    });

    test('fromJson handles missing delay with default 2000', () {
      final json = {'speaker': 'Speaker', 'line': 'Line'};

      final line = SimulationScriptLine.fromJson(json);
      expect(line.delay, 2000);
    });

    test('fromJson handles missing speaker', () {
      final json = {'line': 'Line'};

      final line = SimulationScriptLine.fromJson(json);
      expect(line.speaker, '');
    });
  });
}
