import 'dart:math';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../analysis/analysis_mode.dart';
import '../../core/risk_level.dart';
import 'audio_waveform.dart';
import 'live_conversation.dart';
import 'risk_level_indicator.dart';

class MonitoringPage extends StatefulWidget {
  const MonitoringPage({super.key, this.simulatedScenarioTitle});

  final String? simulatedScenarioTitle;

  @override
  State<MonitoringPage> createState() => _MonitoringPageState();
}

class _MonitoringPageState extends State<MonitoringPage> {
  // Mock state — will be replaced by MonitoringController in Phase 4+.
  final RiskLevel _riskLevel = RiskLevel.green;
  final String _transcript = '';
  final int _elapsedSeconds = 0;
  final bool _networkAvailable = true;
  final bool _isFallbackActive = false;
  final AnalysisMode _selectedMode = AnalysisMode.gDetection;
  final AnalysisMode _effectiveMode = AnalysisMode.gDetection;

  List<double> get _mockAmplitudes {
    final rng = Random(42);
    return List.generate(30, (_) => rng.nextDouble() * 0.6 + 0.1);
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    final isSimulation = widget.simulatedScenarioTitle != null;

    return Scaffold(
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
          onPressed: () => context.go('/'),
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
                  amplitudes: _mockAmplitudes,
                  elapsedSeconds: _elapsedSeconds,
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
                    RiskLevelIndicator(riskLevel: _riskLevel),
                    const SizedBox(height: 12),

                    // ── Mode/Network chips ──
                    SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Row(
                        children: [
                          ActionChip(
                            label: Text('Đích: ${_modeLabel(_selectedMode)}'),
                            backgroundColor: cs.surfaceContainerHighest,
                            side: BorderSide.none,
                            onPressed: () {},
                          ),
                          const SizedBox(width: 8),
                          ActionChip(
                            label: Text('Chạy: ${_modeLabel(_effectiveMode)}'),
                            backgroundColor: _isFallbackActive
                                ? cs.tertiaryContainer
                                : cs.secondaryContainer,
                            side: BorderSide.none,
                            onPressed: () {},
                          ),
                          const SizedBox(width: 8),
                          ActionChip(
                            label: Text(
                                _networkAvailable ? 'Mạng: OK' : 'Mạng: Lỗi'),
                            backgroundColor: _networkAvailable
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
                          transcript: _transcript,
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
    );
  }

  String _modeLabel(AnalysisMode mode) {
    return switch (mode) {
      AnalysisMode.normal => 'L1',
      AnalysisMode.gDetection => 'L2',
      AnalysisMode.geminiApi => 'L3',
    };
  }
}
