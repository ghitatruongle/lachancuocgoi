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
        SimulationController.new);

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
      final jsonStr =
          await rootBundle.loadString('assets/situation_test.json');
      final raw = jsonDecode(jsonStr) as List<dynamic>;
      _allScenarios = raw
          .map((e) =>
              SimulationScenarioData.fromJson(e as Map<String, dynamic>))
          .map((s) => SimulationScenarioData(
                title: s.title,
                description: s.description,
                category: s.category.isEmpty ? 'Chung' : s.category,
                riskLevel: s.riskLevel,
                script: s.script,
                iconEmoji: s.iconEmoji,
              ))
          .toList();
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
    final scenarios = _allScenarios;
    if (scenarios == null) {
      state = const SimulationUiState();
      return;
    }

    final effectiveDevMode = isDevMode ?? ref.read(developerModeProvider).isActive;

    final sourceList = effectiveDevMode
        ? scenarios
        : scenarios.where((s) => normalModeTitles.contains(s.title)).toList();

    final categories = sourceList.map((s) => s.category).toSet().toList();

    final filtered = sourceList.where((s) {
      final matchesSearch = _searchQuery.isEmpty ||
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
}
