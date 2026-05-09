import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/risk_level.dart';
import '../theme/app_theme.dart';
import 'simulation_controller.dart';
import 'simulation_data.dart';

class SimulationPage extends ConsumerStatefulWidget {
  const SimulationPage({super.key});

  @override
  ConsumerState<SimulationPage> createState() => _SimulationPageState();
}

class _SimulationPageState extends ConsumerState<SimulationPage> {
  final _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    // Schedule load after first frame to avoid provider mutation during build.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(simulationControllerProvider.notifier).loadData();
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    final uiState = ref.watch(simulationControllerProvider);
    final controller = ref.read(simulationControllerProvider.notifier);

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.go('/'),
        ),
        title: const Text('Tình huống giả lập'),
        actions: [
          if (uiState.isDevMode)
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: Chip(
                label: const Text('DEV'),
                backgroundColor: cs.errorContainer,
                labelStyle: TextStyle(color: cs.onErrorContainer, fontSize: 11),
                side: BorderSide.none,
              ),
            ),
        ],
      ),
      body: Column(
        children: [
          // ── Search bar ──
          Padding(
            padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.sm, vertical: 8),
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: 'Tìm kịch bản...',
                prefixIcon: const Icon(Icons.search),
                suffixIcon: uiState.searchQuery.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.close),
                        onPressed: () {
                          _searchController.clear();
                          controller.updateSearchQuery('');
                        },
                      )
                    : null,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(24),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(24),
                  borderSide: BorderSide(color: cs.outlineVariant),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(24),
                  borderSide: BorderSide(color: cs.primary),
                ),
              ),
              onChanged: controller.updateSearchQuery,
            ),
          ),

          // ── Category chips ──
          if (uiState.categories.isNotEmpty)
            SizedBox(
              height: 48,
              child: ListView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm),
                children: [
                  Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: FilterChip(
                      label: const Text('Tất cả'),
                      selected: uiState.selectedCategory == null,
                      onSelected: (_) =>
                          controller.updateSelectedCategory(null),
                    ),
                  ),
                  for (final cat in uiState.categories)
                    Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: FilterChip(
                        label: Text(cat),
                        selected: uiState.selectedCategory == cat,
                        onSelected: (_) => controller.updateSelectedCategory(
                            uiState.selectedCategory == cat ? null : cat),
                      ),
                    ),
                ],
              ),
            ),

          const SizedBox(height: 8),

          // ── Scenarios list ──
          Expanded(
            child: _buildBody(uiState, cs, tt),
          ),
        ],
      ),
    );
  }

  Widget _buildBody(SimulationUiState uiState, ColorScheme cs, TextTheme tt) {
    // Loading
    if (uiState.scenarios == null) {
      return ListView.builder(
        padding: const EdgeInsets.all(AppSpacing.sm),
        itemCount: 4,
        itemBuilder: (_, __) => _SkeletonCard(cs: cs),
      );
    }

    // Empty
    if (uiState.scenarios!.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.science_outlined, size: 64, color: cs.onSurfaceVariant),
            const SizedBox(height: 16),
            Text('Không có tình huống', style: tt.titleLarge),
          ],
        ),
      );
    }

    // No results
    if (uiState.filteredScenarios.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.search_off, size: 64, color: cs.onSurfaceVariant),
            const SizedBox(height: 16),
            Text('Không tìm thấy kết quả', style: tt.titleLarge),
          ],
        ),
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.all(AppSpacing.sm),
      itemCount: uiState.filteredScenarios.length,
      separatorBuilder: (_, __) => const SizedBox(height: 12),
      itemBuilder: (context, index) {
        final scenario = uiState.filteredScenarios[index];
        return _ScenarioCard(
          scenario: scenario,
          onStart: () {
            context.push(
              '/monitoring',
              extra: {
                'scenarioTitle': scenario.title,
                'scenarioTranscript': scenario.script
                    .map((line) => '${line.speaker}: ${line.line}')
                    .join('\n'),
              },
            );
          },
        );
      },
    );
  }
}

// ─── Scenario Card ─────────────────────────────────────────────────────
class _ScenarioCard extends StatefulWidget {
  const _ScenarioCard({
    required this.scenario,
    required this.onStart,
  });

  final SimulationScenarioData scenario;
  final VoidCallback onStart;

  @override
  State<_ScenarioCard> createState() => _ScenarioCardState();
}

class _ScenarioCardState extends State<_ScenarioCard> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    final risk = RiskLevel.fromString(widget.scenario.riskLevel);
    final riskColor = switch (risk) {
      RiskLevel.green => const Color(0xFF4CAF50),
      RiskLevel.yellow => const Color(0xFFFFEB3B),
      RiskLevel.orange => const Color(0xFFFF9800),
      RiskLevel.red => const Color(0xFFF44336),
    };

    return Card(
      clipBehavior: Clip.antiAlias,
      child: IntrinsicHeight(
        child: Row(
          children: [
            Container(width: 4, color: riskColor),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(widget.scenario.iconEmoji,
                            style: const TextStyle(fontSize: 28)),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                widget.scenario.title,
                                style: tt.titleMedium
                                    ?.copyWith(fontWeight: FontWeight.bold),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                widget.scenario.description,
                                style: tt.bodySmall
                                    ?.copyWith(color: cs.onSurfaceVariant),
                                maxLines: _expanded ? null : 2,
                                overflow:
                                    _expanded ? null : TextOverflow.ellipsis,
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),

                    // Script preview (expanded)
                    if (_expanded && widget.scenario.script.isNotEmpty) ...[
                      const SizedBox(height: 12),
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: cs.surfaceContainerHighest,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            for (final line in widget.scenario.script.take(4))
                              Padding(
                                padding: const EdgeInsets.only(bottom: 4),
                                child: Text(
                                  '${line.speaker}: ${line.line}',
                                  style: tt.bodySmall,
                                ),
                              ),
                            if (widget.scenario.script.length > 4)
                              Text(
                                '... và ${widget.scenario.script.length - 4} dòng nữa',
                                style: tt.labelSmall
                                    ?.copyWith(color: cs.onSurfaceVariant),
                              ),
                          ],
                        ),
                      ),
                    ],

                    const SizedBox(height: 12),

                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        TextButton(
                          onPressed: () =>
                              setState(() => _expanded = !_expanded),
                          child: Text(_expanded ? 'Thu gọn' : 'Xem chi tiết'),
                        ),
                        ElevatedButton(
                          onPressed: widget.onStart,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: cs.primary,
                            foregroundColor: cs.onPrimary,
                          ),
                          child: const Text('Bắt đầu mô phỏng'),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Skeleton ──────────────────────────────────────────────────────────
class _SkeletonCard extends StatelessWidget {
  const _SkeletonCard({required this.cs});
  final ColorScheme cs;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 200,
              height: 20,
              decoration: BoxDecoration(
                color: cs.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(4),
              ),
            ),
            const SizedBox(height: 8),
            Container(
              width: double.infinity,
              height: 14,
              decoration: BoxDecoration(
                color: cs.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(4),
              ),
            ),
            const SizedBox(height: 4),
            Container(
              width: 160,
              height: 14,
              decoration: BoxDecoration(
                color: cs.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(4),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
