import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../analysis/l1/l1_analysis.dart';
import '../../l10n/app_localizations.dart';
import '../home_page/settings_dialog.dart';
import '../theme/risk_level_colors.dart';
import 'audio_waveform.dart';
import 'live_conversation.dart';
import 'system_log_view.dart';
import 'alert_history_section.dart';
import 'monitoring_controller.dart';
import 'monitoring_status_banners.dart';
import 'risk_level_indicator.dart';

class MonitoringPage extends ConsumerStatefulWidget {
  const MonitoringPage({
    super.key,
    this.simulatedScenarioTitle,
    this.simulatedTranscript,
    this.simulatedScriptLines,
    this.l1AnalyzerOverride,
    this.initialMaskedNumber,
  });

  final String? simulatedScenarioTitle;
  final String? simulatedTranscript;
  final List<Map<String, dynamic>>? simulatedScriptLines;
  final L1Analyzer? l1AnalyzerOverride;
  final String? initialMaskedNumber;

  @override
  ConsumerState<MonitoringPage> createState() => _MonitoringPageState();
}

class _MonitoringPageState extends ConsumerState<MonitoringPage>
    with WidgetsBindingObserver {
  late final _ElapsedNotifier _elapsedNotifier = _ElapsedNotifier();
  int _activeTab = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);

    WidgetsBinding.instance.addPostFrameCallback((_) {
      final controller = ref.read(monitoringControllerProvider.notifier);
      controller.init(
        simulatedScenarioTitle: widget.simulatedScenarioTitle,
        simulatedTranscript: widget.simulatedTranscript,
        simulatedScriptLines: widget.simulatedScriptLines,
        l1AnalyzerOverride: widget.l1AnalyzerOverride,
      );
      controller.maskedNumber = widget.initialMaskedNumber;
      controller.initAfterFrame();

      _elapsedNotifier.value = ref
          .read(monitoringControllerProvider)
          .elapsedSeconds;
    });
  }

  @override
  void dispose() {
    _elapsedNotifier.dispose();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didUpdateWidget(MonitoringPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.simulatedScenarioTitle != oldWidget.simulatedScenarioTitle ||
        widget.simulatedTranscript != oldWidget.simulatedTranscript ||
        widget.simulatedScriptLines != oldWidget.simulatedScriptLines ||
        widget.l1AnalyzerOverride != oldWidget.l1AnalyzerOverride ||
        widget.initialMaskedNumber != oldWidget.initialMaskedNumber) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        final controller = ref.read(monitoringControllerProvider.notifier);
        controller.init(
          simulatedScenarioTitle: widget.simulatedScenarioTitle,
          simulatedTranscript: widget.simulatedTranscript,
          simulatedScriptLines: widget.simulatedScriptLines,
          l1AnalyzerOverride: widget.l1AnalyzerOverride,
        );
        controller.maskedNumber = widget.initialMaskedNumber;
        controller.initAfterFrame();
      });
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    ref.read(monitoringControllerProvider.notifier).onLifecycleChanged(state);

    if (state == AppLifecycleState.resumed) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        _consumeNavigationIntent();
      });
    }
  }

  void _consumeNavigationIntent() {
    final intent = ref.read(monitoringControllerProvider).navigationIntent;
    if (intent == null) return;
    ref.read(monitoringControllerProvider.notifier).clearNavigationIntent();
    switch (intent) {
      case NavigateToResult(:final historyId):
        context.go('/result/$historyId');
      case NavigateToHome():
        context.go('/');
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;

    ref.listen<MonitoringPageState>(monitoringControllerProvider, (prev, next) {
      if (next.navigationIntent == null) return;

      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        _consumeNavigationIntent();
      });
    });

    ref.listen<MonitoringPageState>(monitoringControllerProvider, (prev, next) {
      if (prev?.elapsedSeconds != next.elapsedSeconds) {
        _elapsedNotifier.value = next.elapsedSeconds;
      }
    });

    final state = ref.watch(monitoringControllerProvider);
    final controller = ref.read(monitoringControllerProvider.notifier);

    controller.alertManager.reduceMotion =
        MediaQuery.disableAnimationsOf(context) ||
        MediaQuery.accessibleNavigationOf(context);

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
    final l10n = AppLocalizations.of(context)!;
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
                            ? l10n.monitoringSimulationPrefix(
                                widget.simulatedScenarioTitle!,
                              )
                            : l10n.monitoringSimulationDefault)
                      : l10n.appTitle,
                  style: tt.titleMedium?.copyWith(fontWeight: FontWeight.bold),
                ),
              ),
              if (state.isCreatorMode)
                Container(
                  margin: const EdgeInsets.only(left: 8),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 6,
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    color: cs.tertiary,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.developer_mode,
                        size: 12,
                        color: cs.onTertiary,
                      ),
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
          Text(l10n.monitoringSubtitle, style: tt.bodySmall),
        ],
      ),
      actions: [
        IconButton(
          icon: const Icon(Icons.settings),
          tooltip: l10n.settings,
          onPressed: () {
            showDialog<void>(
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
    final l10n = AppLocalizations.of(context)!;
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Semantics(
        button: true,
        label: l10n.monitoringEndCallSemantic,
        child: ElevatedButton(
          onPressed:
              state.phase == MonitoringPhase.idle ||
                  state.phase == MonitoringPhase.starting ||
                  state.phase == MonitoringPhase.stopping ||
                  state.phase == MonitoringPhase.saved
              ? null
              : () => controller.endSession(),
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
                    ? l10n.monitoringSavingResult
                    : l10n.monitoringEndCall,
                style: tt.titleMedium?.copyWith(color: cs.onError),
              ),
            ],
          ),
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
    final l10n = AppLocalizations.of(context)!;
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

                  Semantics(
                    label: l10n.monitoringWaveformSemantic,
                    child: Card(
                      elevation: 2,
                      child: Padding(
                        padding: const EdgeInsets.all(8),
                        child: RepaintBoundary(
                          child: AnimatedBuilder(
                            animation: controller.waveformNotifier,
                            builder: (context, _) {
                              return AudioWaveform(
                                amplitudes: controller.currentAmplitudes,
                                writeIndex:
                                    controller.currentAmplitudeWriteIndex,
                                elapsedSeconds: _elapsedNotifier,
                                phase: state.phase,
                              );
                            },
                          ),
                        ),
                      ),
                    ),
                  ),

                  const SizedBox(height: 8),

                  Card(
                    elevation: 4,
                    child: Semantics(
                      label: l10n.monitoringRiskSemantic(
                        state.availability.canShowRisk
                            ? state.riskLevel.vietnameseName
                            : state.availability.vietnameseName,
                      ),
                      liveRegion: true,
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 12,
                        ),
                        child: Column(
                          children: [
                            RiskLevelIndicator(
                              riskLevel: state.riskLevel,
                              availability: state.availability,
                            ),
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
                                    children: state.analysisResult!.matches
                                        .take(5)
                                        .map((match) {
                                          return Chip(
                                            label: Text(
                                              match.keyword,
                                              style: TextStyle(
                                                color:
                                                    match.level.color
                                                            .computeLuminance() >
                                                        0.5
                                                    ? Colors.black
                                                    : Colors.white,
                                                fontSize: 12,
                                                fontWeight: FontWeight.bold,
                                              ),
                                            ),
                                            backgroundColor: match.level.color
                                                .withValues(alpha: 0.8),
                                            visualDensity:
                                                VisualDensity.compact,
                                            padding: EdgeInsets.zero,
                                            materialTapTargetSize:
                                                MaterialTapTargetSize
                                                    .shrinkWrap,
                                          );
                                        })
                                        .toList(),
                                  ),
                                ),
                              ],
                            ],
                            const SizedBox(height: 8),
                            SingleChildScrollView(
                              scrollDirection: Axis.horizontal,
                              child: Row(
                                children: [
                                  MonitoringStatusBadge(
                                    label: l10n.monitoringModeTarget(
                                      MonitoringController.modeLabel(
                                        state.selectedMode,
                                      ),
                                    ),
                                    backgroundColor: cs.surfaceContainerHighest,
                                    textColor: cs.onSurfaceVariant,
                                  ),
                                  const SizedBox(width: 8),
                                  MonitoringStatusBadge(
                                    label: l10n.monitoringModeRunning(
                                      MonitoringController.modeLabel(
                                        state.effectiveMode,
                                      ),
                                    ),
                                    backgroundColor: state.isFallbackActive
                                        ? cs.tertiaryContainer
                                        : cs.secondaryContainer,
                                    textColor: state.isFallbackActive
                                        ? cs.onTertiaryContainer
                                        : cs.onSecondaryContainer,
                                  ),
                                  const SizedBox(width: 8),
                                  MonitoringStatusBadge(
                                    label: state.networkAvailable
                                        ? l10n.monitoringNetworkOk
                                        : l10n.monitoringNetworkError,
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
                  ),

                  const SizedBox(height: 8),

                  if (state.monitoringErrorMessage != null)
                    MonitoringStatusBanner(
                      icon: Icons.error_outline,
                      background: cs.errorContainer,
                      foreground: cs.onErrorContainer,
                      message: state.monitoringErrorMessage!,
                      onDismiss: controller.dismissMonitoringError,
                    ),

                  if (state.isSttUnavailable)
                    MonitoringStatusBanner(
                      icon: Icons.mic_off,
                      background: cs.errorContainer,
                      foreground: cs.onErrorContainer,
                      message:
                          state.sttUnavailableReason != null &&
                              state.sttUnavailableReason!.isNotEmpty
                          ? l10n.monitoringSttFatalWithReason(
                              state.sttUnavailableReason!,
                            )
                          : l10n.monitoringSttFatal,
                      onDismiss: controller.dismissSttUnavailableBanner,
                    ),

                  if (state.isDegradedNoNotification)
                    MonitoringStatusBanner(
                      icon: Icons.notifications_off_outlined,
                      background: cs.tertiaryContainer,
                      foreground: cs.onTertiaryContainer,
                      message: l10n.monitoringNotificationDegraded,
                      onDismiss: controller.dismissDegradedNotificationBanner,
                    ),

                  if (state.isWatchdogRestartFailed)
                    MonitoringStatusBanner(
                      icon: Icons.restart_alt,
                      background: cs.errorContainer,
                      foreground: cs.onErrorContainer,
                      message: l10n.monitoringWatchdogFailed,
                      onDismiss: controller.dismissWatchdogBanner,
                    ),

                  if (state.isSttFallback)
                    MonitoringSttFallbackBanner(
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

          Expanded(
            child: Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Row(
                        children: [
                          _buildTabButton(
                            0,
                            isSimulation
                                ? l10n.monitoringSimulationTranscript
                                : l10n.monitoringLiveConversation,
                            cs,
                            tt,
                          ),
                          const SizedBox(width: 20),
                          _buildTabButton(1, l10n.monitoringSystemLog, cs, tt),
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),
                    Expanded(
                      child: RepaintBoundary(
                        child: _activeTab == 0
                            ? LiveConversation(
                                transcript: state.transcript,
                                isSimulation: isSimulation,
                              )
                            : const SystemLogView(),
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

  Widget _buildTabButton(
    int index,
    String label,
    ColorScheme cs,
    TextTheme tt,
  ) {
    final isSelected = _activeTab == index;
    return GestureDetector(
      onTap: () => setState(() => _activeTab = index),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            label,
            style: tt.titleSmall?.copyWith(
              color: isSelected ? cs.primary : cs.onSurfaceVariant,
              fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
            ),
          ),
          const SizedBox(height: 4),
          AnimatedContainer(
            duration: const Duration(milliseconds: 150),
            height: 2,
            width: isSelected ? 40 : 0,
            color: isSelected ? cs.primary : Colors.transparent,
          ),
        ],
      ),
    );
  }
}

class _ElapsedNotifier extends ValueNotifier<int> {
  _ElapsedNotifier() : super(0);
}
