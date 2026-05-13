import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../analysis/analysis_mode.dart';
import '../../services/monitoring_controller.dart';
import '../../services/settings_controller.dart';
import 'audio_waveform.dart';
import 'live_conversation.dart';
import 'risk_level_indicator.dart';
import 'warning/orange_warning.dart';
import 'warning/red_warning.dart';

class MonitoringPage extends ConsumerStatefulWidget {
  const MonitoringPage({
    super.key,
    this.simulatedScenarioTitle,
    this.simulatedTranscript,
  });

  final String? simulatedScenarioTitle;
  final String? simulatedTranscript;

  @override
  ConsumerState<MonitoringPage> createState() => _MonitoringPageState();
}

class _MonitoringPageState extends ConsumerState<MonitoringPage> {
  bool _isAnalyzing = false;

  @override
  void initState() {
    super.initState();
    // Start monitoring when page loads (for real calls, not simulation)
    if (widget.simulatedScenarioTitle == null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _startRealMonitoring();
      });
    }
  }

  Future<void> _startRealMonitoring() async {
    final settingsController = ref.read(settingsControllerProvider);
    final monitoringController = ref.read(monitoringControllerProvider);
    
    final mode = switch (settingsController.settings.analysisMode) {
      AnalysisMode.normal => AnalysisMode.normal,
      AnalysisMode.gDetection => AnalysisMode.gDetection,
      AnalysisMode.geminiApi => AnalysisMode.geminiApi,
    };

    await monitoringController.startMonitoring(mode: mode);
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    final monitoringState = ref.watch(monitoringControllerProvider);
    final isSimulation = widget.simulatedScenarioTitle != null;

    return Stack(
      children: [
        Scaffold(
          appBar: AppBar(
            title: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  isSimulation
                      ? 'Mô phỏng: ${widget.simulatedScenarioTitle}'
                      : 'Lá chắn cuộc gọi',
                  style: tt.titleMedium?.copyWith(fontWeight: FontWeight.bold),
                ),
                Text(
                  'Phát hiện Lừa đảo & Bạo lực',
                  style: tt.bodySmall,
                ),
              ],
            ),
            actions: [
              IconButton(
                icon: const Icon(Icons.settings),
                tooltip: 'Cài đặt',
                onPressed: () {},
              ),
            ],
          ),

          // ── Bottom bar: End call button ──
          bottomNavigationBar: Padding(
            padding: const EdgeInsets.all(16),
            child: ElevatedButton(
              onPressed: () async {
                if (!isSimulation) {
                  final controller = ref.read(monitoringControllerProvider);
                  await controller.stopMonitoring();
                }
                context.go('/');
              },
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
                  const Icon(Icons.call_end),
                  const SizedBox(width: 8),
                  Text(
                    'Kết thúc cuộc gọi',
                    style: tt.titleMedium?.copyWith(color: cs.onError),
                  ),
                ],
              ),
            ),
          ),

          body: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Column(
              children: [
                const SizedBox(height: 4),

                // ── Waveform card ──
                Card(
                  elevation: 2,
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: AudioWaveform(
                      amplitudes: isSimulation 
                          ? _mockAmplitudes 
                          : monitoringState.amplitudes,
                      elapsedSeconds: monitoringState.elapsedSeconds,
                    ),
                  ),
                ),

                const SizedBox(height: 12),

                // ── Risk level card ──
                Card(
                  elevation: 4,
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      children: [
                        RiskLevelIndicator(
                          riskLevel: monitoringState.analysisResult.overallRiskLevel,
                        ),
                        if (_isAnalyzing) ...[
                          const SizedBox(height: 8),
                          const LinearProgressIndicator(),
                        ],
                        if (monitoringState.analysisResult.reason != null &&
                            monitoringState.analysisResult.reason!.isNotEmpty) ...[
                          const SizedBox(height: 8),
                          Align(
                            alignment: Alignment.centerLeft,
                            child: Text(
                              monitoringState.analysisResult.reason ?? '',
                              style: tt.bodySmall?.copyWith(
                                color: cs.onSurfaceVariant,
                              ),
                            ),
                          ),
                        ],
                        if (monitoringState.analysisResult.matches.isNotEmpty) ...[
                          const SizedBox(height: 8),
                          SizedBox(
                            width: double.infinity,
                            child: Wrap(
                              spacing: 8,
                              runSpacing: 4,
                              children: [
                                for (final match
                                    in monitoringState.analysisResult.matches.take(4))
                                  Chip(
                                    label: Text(match.keyword),
                                    visualDensity: VisualDensity.compact,
                                  ),
                              ],
                            ),
                          ),
                        ],
                        const SizedBox(height: 12),

                        // ── Mode/Network chips ──
                        SingleChildScrollView(
                          scrollDirection: Axis.horizontal,
                          child: Row(
                            children: [
                              ActionChip(
                                label: Text('Đích: ${_modeLabel(monitoringState.selectedMode)}'),
                                backgroundColor: cs.surfaceContainerHighest,
                                side: BorderSide.none,
                                onPressed: () {},
                              ),
                              const SizedBox(width: 8),
                              ActionChip(
                                label: Text('Chạy: ${_modeLabel(monitoringState.effectiveMode)}'),
                                backgroundColor: monitoringState.isFallbackActive
                                    ? cs.tertiaryContainer
                                    : cs.secondaryContainer,
                                side: BorderSide.none,
                                onPressed: () {},
                              ),
                              const SizedBox(width: 8),
                              ActionChip(
                                label: Text(
                                    monitoringState.networkAvailable ? 'Mạng: OK' : 'Mạng: Lỗi'),
                                backgroundColor: monitoringState.networkAvailable
                                    ? cs.surfaceContainerHighest
                                    : cs.errorContainer,
                                side: BorderSide.none,
                                onPressed: () {},
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

                const SizedBox(height: 12),

                // ── Live conversation card ──
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
                            child: LiveConversation(
                              transcript: isSimulation 
                                  ? (widget.simulatedTranscript ?? '')
                                  : monitoringState.transcript,
                              isSimulation: isSimulation,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),

        // ── Alert Overlays ──
        if (monitoringState.currentAlert != null) ...[
          if (monitoringState.currentAlert!.level == RiskLevel.red)
            RedWarning(
              title: monitoringState.currentAlert!.reason,
              onDismiss: () {
                ref.read(monitoringControllerProvider).dismissAlert();
              },
            )
          else if (monitoringState.currentAlert!.level == RiskLevel.orange)
            OrangeWarning(
              title: monitoringState.currentAlert!.reason,
              onDismiss: () {
                ref.read(monitoringControllerProvider).dismissAlert();
              },
            ),
        ],
      ],
    );
  }

  List<double> get _mockAmplitudes {
    return List.generate(30, (index) => (index % 5 + 1) / 10.0);
  }

  String _modeLabel(AnalysisMode mode) {
    return switch (mode) {
      AnalysisMode.normal => 'L1',
      AnalysisMode.gDetection => 'L2',
      AnalysisMode.geminiApi => 'L3',
    };
  }
}
