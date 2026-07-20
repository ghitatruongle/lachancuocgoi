import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../services/developer_mode_manager.dart';
import 'simulation_data.dart';

// ─── State ─────────────────────────────────────────────────────────────
class SimulationUiState {
  const SimulationUiState({
    this.scenarios,
    this.categories = const [],
    this.filteredScenarios = const [],
    this.searchQuery = '',
    this.selectedCategory,
    this.isDevMode = false,
  });

  final List<SimulationScenarioData>? scenarios;
  final List<String> categories;
  final List<SimulationScenarioData> filteredScenarios;
  final String searchQuery;
  final String? selectedCategory;
  final bool isDevMode;
}

// ─── Controller ────────────────────────────────────────────────────────
final simulationControllerProvider =
    NotifierProvider<SimulationController, SimulationUiState>(
      SimulationController.new,
    );

class SimulationController extends Notifier<SimulationUiState> {
  List<SimulationScenarioData>? _allScenarios;
  String _searchQuery = '';
  String? _selectedCategory;

  @override
  SimulationUiState build() {
    ref.listen<DeveloperModeState>(developerModeProvider, (_, next) {
      _recompute(isDevMode: next.isActive);
    });
    return const SimulationUiState();
  }

  Future<void> loadData() async {
    if (_allScenarios != null) return;
    try {
      final jsonStr = await rootBundle.loadString('assets/situation_test.json');
      final decoded = jsonDecode(jsonStr);
      final raw = decoded is List
          ? decoded
          : decoded is Map && decoded['scenarios'] is List
          ? decoded['scenarios'] as List
          : const <dynamic>[];
      final seen = <String>{};
      _allScenarios = raw
          .whereType<Map>()
          .map(
            (entry) => SimulationScenarioData.fromJson(
              entry.map((key, value) => MapEntry(key.toString(), value)),
            ),
          )
          .where(
            (scenario) =>
                scenario.title.trim().isNotEmpty &&
                scenario.script.isNotEmpty &&
                seen.add(scenario.id),
          )
          .toList(growable: false);
    } on Object catch (_) {
      _allScenarios = [];
    }
    _recompute();
  }

  void updateSearchQuery(String query) {
    _searchQuery = query;
    _recompute();
  }

  void updateSelectedCategory(String? category) {
    _selectedCategory = category;
    _recompute();
  }

  void _recompute({bool? isDevMode}) {
    if (!ref.mounted) return;
    final scenarios = _allScenarios;
    if (scenarios == null) {
      state = const SimulationUiState();
      return;
    }

    final effectiveDevMode =
        isDevMode ?? ref.read(developerModeProvider).isActive;

    final sourceList = effectiveDevMode ? scenarios : _normalCatalog(scenarios);

    final categories = sourceList.map((s) => s.category).toSet().toList()
      ..sort();
    if (_selectedCategory != null && !categories.contains(_selectedCategory)) {
      _selectedCategory = null;
    }

    final filtered = sourceList.where((s) {
      final matchesSearch =
          _searchQuery.isEmpty ||
          s.title.toLowerCase().contains(_searchQuery.toLowerCase()) ||
          s.description.toLowerCase().contains(_searchQuery.toLowerCase());
      final matchesCategory =
          _selectedCategory == null || s.category == _selectedCategory;
      return matchesSearch && matchesCategory;
    }).toList();

    state = SimulationUiState(
      scenarios: sourceList,
      categories: categories,
      filteredScenarios: filtered,
      searchQuery: _searchQuery,
      selectedCategory: _selectedCategory,
      isDevMode: effectiveDevMode,
    );
  }

  List<SimulationScenarioData> _normalCatalog(
    List<SimulationScenarioData> scenarios,
  ) {
    final featured = scenarios
        .where((scenario) => scenario.isFeatured)
        .toList();
    if (featured.isNotEmpty) {
      return featured.take(normalSimulationCatalogSize).toList(growable: false);
    }

    final result = <SimulationScenarioData>[];
    void addFirstWhere(bool Function(SimulationScenarioData) predicate) {
      for (final scenario in scenarios) {
        if (result.length >= normalSimulationCatalogSize) return;
        if (predicate(scenario) && !result.contains(scenario)) {
          result.add(scenario);
          return;
        }
      }
    }

    addFirstWhere((scenario) => scenario.riskLevel == 'GREEN');
    while (result.length < normalSimulationCatalogSize) {
      final before = result.length;
      addFirstWhere((scenario) => scenario.riskLevel == 'RED');
      if (result.length == before) break;
    }
    for (final scenario in scenarios) {
      if (result.length >= normalSimulationCatalogSize) break;
      if (!result.contains(scenario)) result.add(scenario);
    }
    return List.unmodifiable(result);
  }
}
