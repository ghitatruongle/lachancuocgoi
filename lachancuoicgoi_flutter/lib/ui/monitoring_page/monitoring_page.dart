import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../analysis/analysis_level.dart';
import '../../analysis/analysis_mode.dart';
import '../../analysis/analysis_result.dart';
import '../../analysis/l1/l1_analysis.dart';
import '../../core/risk_level.dart';
import 'audio_waveform.dart';
import 'live_conversation.dart';
import 'risk_level_indicator.dart';

class MonitoringPage extends StatefulWidget {
  const MonitoringPage({
    super.key,
    this.simulatedScenarioTitle,
    this.simulatedTranscript,
  });

  final String? simulatedScenarioTitle;
  final String? simulatedTranscript;

  @override
  State<MonitoringPage> createState() => _MonitoringPageState();
}

class _MonitoringPageState extends State<MonitoringPage> {
  late final L1Analyzer _l1Analyzer;
  RiskLevel _riskLevel = RiskLevel.green;
  String _transcript = '';
  int _elapsedSeconds = 0;
  bool _networkAvailable = true;
  bool _isFallbackActive = false;
  AnalysisMode _selectedMode = AnalysisMode.normal;
  AnalysisMode _effectiveMode = AnalysisMode.normal;
  AnalysisResult? _analysisResult;
  bool _isAnalyzing = false;
  Timer? _timer;
  String _displayedTime = '00:00';

  @override
  void initState() {
    super.initState();
    _l1Analyzer = L1Analyzer();
    _transcript = widget.simulatedTranscript?.trim() ?? '';
    _startTimer();
    if (_transcript.isNotEmpty) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _runMockL1Analysis();
      });
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  void _startTimer() {
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) {
        setState(() {
          _elapsedSeconds++;
          _displayedTime = _formatElapsedTime(_elapsedSeconds);
        });
      }
    });
  }

  String _formatElapsedTime(int seconds) {
    final m = seconds ~/ 60;
    final s = seconds % 60;
    return '${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
  }

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
            Text('Phát hiện Lừa đảo & Bạo lực', style: tt.bodySmall),
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
                  elapsedTime: _displayedTime,
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
                    if (_isAnalyzing) ...[
                      const SizedBox(height: 8),
                      const LinearProgressIndicator(),
                    ],
                    if (_analysisResult != null) ...[
                      const SizedBox(height: 8),
                      Align(
                        alignment: Alignment.centerLeft,
                        child: Text(
                          _analysisResult!.reason ?? '',
                          style: tt.bodySmall?.copyWith(
                            color: cs.onSurfaceVariant,
                          ),
                        ),
                      ),
                    ],
                    if ((_analysisResult?.matches ?? const []).isNotEmpty) ...[
                      const SizedBox(height: 8),
                      SizedBox(
                        width: double.infinity,
                        child: Wrap(
                          spacing: 8,
                          runSpacing: 4,
                          children: [
                            for (final match in _analysisResult!.matches.take(
                              4,
                            ))
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
                              _networkAvailable ? 'Mạng: OK' : 'Mạng: Lỗi',
                            ),
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

  Future<void> _runMockL1Analysis() async {
    setState(() => _isAnalyzing = true);
    try {
      final result = await _l1Analyzer.analyze(_transcript);
      if (!mounted) return;
      setState(() {
        _analysisResult = result;
        _riskLevel = result.overallRiskLevel;
        _isAnalyzing = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _analysisResult = const AnalysisResult(
          overallRiskLevel: RiskLevel.green,
          matches: [],
          reason: 'Không thể chạy L1 trên kịch bản mô phỏng.',
          analysisLevel: AnalysisLevel.l1,
          alertEnabled: false,
          isError: true,
        );
        _riskLevel = RiskLevel.green;
        _isAnalyzing = false;
      });
    }
  }
}
