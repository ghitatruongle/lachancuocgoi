import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../analysis/l1/l1_analysis.dart';
import '../home_page/settings_dialog.dart';
import 'audio_waveform.dart';
import 'live_conversation.dart';
import 'alert_history_section.dart';
import 'monitoring_controller.dart';
import 'risk_level_indicator.dart';

class MonitoringPage extends ConsumerStatefulWidget {
  const MonitoringPage({
    super.key,
    this.simulatedScenarioTitle,
    this.simulatedTranscript,
    this.simulatedScriptLines,
    this.l1AnalyzerOverride,
  });

  final String? simulatedScenarioTitle;
  final String? simulatedTranscript;
  final List<Map<String, dynamic>>? simulatedScriptLines;
  final L1Analyzer? l1AnalyzerOverride;

  @override
  ConsumerState<MonitoringPage> createState() => _MonitoringPageState();
}

class _MonitoringPageState extends ConsumerState<MonitoringPage>
    with WidgetsBindingObserver {
  late final _ElapsedNotifier _elapsedNotifier = _ElapsedNotifier();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);

    // Deferred init — must not modify provider state during initState.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(monitoringControllerProvider.notifier).init(
            simulatedScenarioTitle: widget.simulatedScenarioTitle,
            simulatedTranscript: widget.simulatedTranscript,
            simulatedScriptLines: widget.simulatedScriptLines,
            l1AnalyzerOverride: widget.l1AnalyzerOverride,
          );
      ref.read(monitoringControllerProvider.notifier).initAfterFrame();
    });
  }

  @override
  void dispose() {
    _elapsedNotifier.dispose();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    ref
        .read(monitoringControllerProvider.notifier)
        .onLifecycleChanged(state);

    // Bug #5 fix: check for pending navigation intents when the app resumes.
    // ref.listen in build() doesn't fire while the widget tree is inactive,
    // so navigation intents set while backgrounded would be lost.
    if (state == AppLifecycleState.resumed) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        final currentState = ref.read(monitoringControllerProvider);
        final intent = currentState.navigationIntent;
        if (intent != null) {
          ref
              .read(monitoringControllerProvider.notifier)
              .clearNavigationIntent();
          switch (intent) {
            case NavigateToResult(:final historyId):
              context.go('/result/$historyId');
            case NavigateToHome():
              context.go('/');
          }
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;

    // Listen for navigation intents.
    ref.listen<MonitoringPageState>(monitoringControllerProvider, (prev, next) {
      final intent = next.navigationIntent;
      if (intent != null) {
        ref
            .read(monitoringControllerProvider.notifier)
            .clearNavigationIntent();
        switch (intent) {
          case NavigateToResult(:final historyId):
            context.go('/result/$historyId');
          case NavigateToHome():
            context.go('/');
        }
      }
    });

    final state = ref.watch(monitoringControllerProvider);
    final controller = ref.read(monitoringControllerProvider.notifier);
    _elapsedNotifier.value = state.elapsedSeconds;

    final hasScenarioTitle =
        (widget.simulatedScenarioTitle?.trim().isNotEmpty ?? false);
    final isSimulation = state.isSimulationMode;

    return Scaffold(
      appBar: _buildAppBar(cs, tt, isSimulation, hasScenarioTitle, state),
      bottomNavigationBar: _buildBottomBar(cs, tt, state, controller),
      body: SafeArea(
        child: _buildBody(context, cs, tt, isSimulation, state, controller),
      ),
    );
  }

  PreferredSizeWidget _buildAppBar(
    ColorScheme cs,
    TextTheme tt,
    bool isSimulation,
    bool hasScenarioTitle,
    MonitoringPageState state,
  ) {
    return AppBar(
      title: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  isSimulation
                      ? (hasScenarioTitle
                          ? 'Mô phỏng: ${widget.simulatedScenarioTitle}'
                          : 'Mô phỏng')
                      : 'Lá chắn cuộc gọi',
                  style:
                      tt.titleMedium?.copyWith(fontWeight: FontWeight.bold),
                ),
              ),
              if (state.isCreatorMode)
                Container(
                  margin: const EdgeInsets.only(left: 8),
                  padding: const EdgeInsets.symmetric(
                      horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: cs.tertiary,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.developer_mode,
                          size: 12, color: cs.onTertiary),
                      const SizedBox(width: 3),
                      Text(
                        'CREATOR',
                        style: TextStyle(
                          fontSize: 9,
                          fontWeight: FontWeight.w900,
                          color: cs.onTertiary,
                          letterSpacing: 1.2,
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ),
          Text('Phát hiện Lừa đảo & Bạo lực', style: tt.bodySmall),
        ],
      ),
      actions: [
        IconButton(
          icon: const Icon(Icons.settings),
          tooltip: 'Cài đặt',
          onPressed: () {
            // Import kept in controller for dialog, but we show from page
            // since it needs context.
            showDialog(
              context: context,
              builder: (_) => const SettingsDialog(),
            );
          },
        ),
      ],
    );
  }

  Widget _buildBottomBar(
    ColorScheme cs,
    TextTheme tt,
    MonitoringPageState state,
    MonitoringController controller,
  ) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: ElevatedButton(
        onPressed:
            state.isEndingSession ? null : () => controller.endSession(),
        style: ElevatedButton.styleFrom(
          backgroundColor: cs.error,
          foregroundColor: cs.onError,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          padding: const EdgeInsets.symmetric(vertical: 12),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (state.isEndingSession) ...[
              SizedBox(
                width: 22,
                height: 22,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: cs.onError,
                ),
              ),
              const SizedBox(width: 10),
            ] else
              const Icon(Icons.call_end),
            const SizedBox(width: 8),
            Text(
              state.isEndingSession
                  ? 'Đang lưu kết quả...'
                  : 'Kết thúc cuộc gọi',
              style: tt.titleMedium?.copyWith(color: cs.onError),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBody(
    BuildContext context,
    ColorScheme cs,
    TextTheme tt,
    bool isSimulation,
    MonitoringPageState state,
    MonitoringController controller,
  ) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        children: [
          Flexible(
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const SizedBox(height: 4),

                  // Waveform card
                  Card(
                    elevation: 2,
                    child: Padding(
                      padding: const EdgeInsets.all(8),
                      child: RepaintBoundary(
                        child: ValueListenableBuilder<List<double>>(
                          valueListenable: controller.amplitudesListenable,
                          builder: (context, amplitudes, _) {
                            return AudioWaveform(
                              amplitudes: amplitudes,
                              elapsedSeconds: _elapsedNotifier,
                            );
                          },
                        ),
                      ),
                    ),
                  ),

                  const SizedBox(height: 8),

                  // Risk level card
                  Card(
                    elevation: 4,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      child: Column(
                        children: [
                          RiskLevelIndicator(riskLevel: state.riskLevel),
                          if (state.isAnalyzing)
                            const Column(
                              children: [
                                SizedBox(height: 8),
                                LinearProgressIndicator(),
                              ],
                            ),
                          if (state.analysisResult != null) ...[
                            const SizedBox(height: 8),
                            Align(
                              alignment: Alignment.centerLeft,
                              child: Text(
                                state.analysisResult!.reason ?? '',
                                style: tt.bodySmall?.copyWith(
                                  color: cs.onSurfaceVariant,
                                ),
                              ),
                            ),
                            if (state.analysisResult!.matches.isNotEmpty) ...[
                              const SizedBox(height: 8),
                              SizedBox(
                                width: double.infinity,
                                child: Wrap(
                                  spacing: 8,
                                  runSpacing: 4,
                                  children:
                                      state.analysisResult!.matches.take(5).map((match) {
                                    return Chip(
                                      label: Text(
                                        match.keyword,
                                        style: TextStyle(
                                          color: match.level.color.computeLuminance() > 0.5
                                              ? Colors.black
                                              : Colors.white,
                                          fontSize: 12,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                      backgroundColor: match.level.color.withValues(alpha: 0.8),
                                      visualDensity: VisualDensity.compact,
                                      padding: EdgeInsets.zero,
                                      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                    );
                                  }).toList(),
                                ),
                              ),
                            ],
                          ],
                          const SizedBox(height: 8),
                          SingleChildScrollView(
                            scrollDirection: Axis.horizontal,
                            child: Row(
                              children: [
                                _StatusBadge(
                                  label:
                                      'Đích: ${MonitoringController.modeLabel(state.selectedMode)}',
                                  backgroundColor: cs.surfaceContainerHighest,
                                  textColor: cs.onSurfaceVariant,
                                ),
                                const SizedBox(width: 8),
                                _StatusBadge(
                                  label:
                                      'Chạy: ${MonitoringController.modeLabel(state.effectiveMode)}',
                                  backgroundColor: state.isFallbackActive
                                      ? cs.tertiaryContainer
                                      : cs.secondaryContainer,
                                  textColor: state.isFallbackActive
                                      ? cs.onTertiaryContainer
                                      : cs.onSecondaryContainer,
                                ),
                                const SizedBox(width: 8),
                                _StatusBadge(
                                  label: state.networkAvailable
                                      ? 'Mạng: OK'
                                      : 'Mạng: Lỗi',
                                  backgroundColor: state.networkAvailable
                                      ? cs.surfaceContainerHighest
                                      : cs.errorContainer,
                                  textColor: state.networkAvailable
                                      ? cs.onSurfaceVariant
                                      : cs.onErrorContainer,
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),

                  const SizedBox(height: 8),

                  // STT fallback banner
                  if (state.isSttFallback)
                    _SttFallbackBanner(
                      reason: state.sttFallbackReason,
                      onDismiss: controller.dismissSttFallbackBanner,
                    ),

                  if (state.alertHistory.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    AlertHistorySection(alertHistory: state.alertHistory),
                  ],
                ],
              ),
            ),
          ),

          const SizedBox(height: 8),

          // Live conversation card
          Expanded(
            child: Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      isSimulation
                          ? 'Kịch bản mô phỏng'
                          : 'Cuộc hội thoại trực tiếp',
                      style: tt.titleSmall?.copyWith(
                        color: cs.onSurfaceVariant,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Expanded(
                      child: RepaintBoundary(
                        child: LiveConversation(
                          transcript: state.transcript,
                          isSimulation: isSimulation,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Adapter that exposes elapsed seconds as a ValueListenable
/// for the AudioWaveform widget, which expects one.
class _ElapsedNotifier extends ValueNotifier<int> {
  _ElapsedNotifier() : super(0);
}

class _StatusBadge extends StatelessWidget {
  const _StatusBadge({
    required this.label,
    required this.backgroundColor,
    required this.textColor,
  });

  final String label;
  final Color backgroundColor;
  final Color textColor;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        label,
        style: Theme.of(context).textTheme.labelMedium?.copyWith(
              color: textColor,
              fontWeight: FontWeight.w600,
            ),
      ),
    );
  }
}

class _SttFallbackBanner extends StatelessWidget {
  const _SttFallbackBanner({
    required this.reason,
    required this.onDismiss,
  });

  final String? reason;
  final VoidCallback onDismiss;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Material(
        color: cs.tertiaryContainer,
        borderRadius: BorderRadius.circular(10),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          child: Row(
            children: [
              Icon(Icons.mic_off, size: 18, color: cs.onTertiaryContainer),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  reason != null && reason!.isNotEmpty
                      ? 'STT offline (Vosk): $reason'
                      : 'STT đã chuyển sang chế độ offline (Vosk)',
                  style: TextStyle(
                    fontSize: 12,
                    color: cs.onTertiaryContainer,
                  ),
                ),
              ),
              InkWell(
                onTap: onDismiss,
                borderRadius: BorderRadius.circular(16),
                child: Padding(
                  padding: const EdgeInsets.all(4),
                  child: Icon(Icons.close, size: 16, color: cs.onTertiaryContainer),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

