import 'dart:async' show StreamSubscription, Timer, unawaited;
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../analysis/analysis_coordinator.dart';
import '../../analysis/analysis_level.dart';
import '../../analysis/analysis_mode.dart';
import '../../analysis/analysis_result.dart';
import '../../analysis/l1/l1_analysis.dart';
import '../../analysis/l2/l2_analysis.dart';
import '../../analysis/l3/l3_analysis.dart';
import '../../app/settings_controller.dart';
import '../../core/risk_level.dart';
import '../../data/app_database.dart';
import '../../data/call_history.dart';
import '../../services/developer_mode_manager.dart';
import '../../services/native_call_shield_bridge.dart';
import '../home_page/settings_dialog.dart';
import 'audio_waveform.dart';
import 'live_conversation.dart';
import 'risk_level_indicator.dart';

class MonitoringPage extends ConsumerStatefulWidget {
  const MonitoringPage({
    super.key,
    this.simulatedScenarioTitle,
    this.simulatedTranscript,

    /// Pass a small test analyzer from widget tests; omit in production.
    this.l1AnalyzerOverride,
  });

  final String? simulatedScenarioTitle;
  final String? simulatedTranscript;
  final L1Analyzer? l1AnalyzerOverride;

  @override
  ConsumerState<MonitoringPage> createState() => _MonitoringPageState();
}

class _MonitoringPageState extends ConsumerState<MonitoringPage> {
  late final AnalysisCoordinator _coordinator;

  L1Analyzer get _l1Analyzer => _l1AnalyzerInstance;
  L2Analyzer get _l2Analyzer => _l2AnalyzerInstance;
  L3Analyzer get _l3Analyzer => _l3AnalyzerInstance;
  late final L1Analyzer _l1AnalyzerInstance;
  late final L2Analyzer _l2AnalyzerInstance;
  late final L3Analyzer _l3AnalyzerInstance;

  final ValueNotifier<RiskLevel> _riskLevelNotifier = ValueNotifier<RiskLevel>(
    RiskLevel.green,
  );
  final ValueNotifier<String> _transcriptNotifier = ValueNotifier<String>('');
  final ValueNotifier<int> _elapsedSecondsNotifier = ValueNotifier<int>(0);
  final ValueNotifier<bool> _networkAvailableNotifier = ValueNotifier<bool>(
    true,
  );
  final ValueNotifier<bool> _isFallbackActiveNotifier = ValueNotifier<bool>(
    false,
  );
  final ValueNotifier<AnalysisResult?> _analysisResultNotifier =
      ValueNotifier<AnalysisResult?>(null);
  final ValueNotifier<bool> _isAnalyzingNotifier = ValueNotifier<bool>(false);
  final ValueNotifier<bool> _isEndingSessionNotifier = ValueNotifier<bool>(
    false,
  );
  final ValueNotifier<bool> _isSimulationModeNotifier = ValueNotifier<bool>(
    false,
  );

  RiskLevel get _riskLevel => _riskLevelNotifier.value;
  String get _transcript => _transcriptNotifier.value;
  AnalysisResult? get _analysisResult => _analysisResultNotifier.value;
  bool get _isEndingSession => _isEndingSessionNotifier.value;
  bool get _hasTestAnalyzerOverride => widget.l1AnalyzerOverride != null;
  late AnalysisMode _selectedMode;
  late AnalysisMode _effectiveMode;
  bool _isCreatorMode = false;
  bool _hasAttemptedStart = false;
  Timer? _timer;
  Timer? _analysisDebounce;
  Future<void>? _l1AnalysisFuture;
  ProviderSubscription<SettingsState>? _settingsSubscription;

  StreamSubscription<String>? _transcriptSub;
  StreamSubscription<double>? _rmsSub;
  StreamSubscription<(MonitoringState, int?, String?)>? _stateSub;

  final List<double> _amplitudes = List.generate(30, (_) => 0.1);
  DateTime? _lastAmplitudeUpdate;
  late final ValueNotifier<List<double>> _amplitudesNotifier;

  @override
  void initState() {
    super.initState();
    _amplitudesNotifier = ValueNotifier<List<double>>(_amplitudes);
    _l1AnalyzerInstance = widget.l1AnalyzerOverride ?? L1Analyzer();
    _l2AnalyzerInstance = L2Analyzer();
    _l3AnalyzerInstance = L3Analyzer();
    _coordinator = AnalysisCoordinator(
      l1Analyzer: _l1AnalyzerInstance,
      l2Analyzer: _l2AnalyzerInstance,
      l3Analyzer: _l3AnalyzerInstance,
    );

    _selectedMode = _hasTestAnalyzerOverride
        ? AnalysisMode.normal
        : ref.read(settingsControllerProvider).analysisMode;
    _effectiveMode = _selectedMode;
    if (!_hasTestAnalyzerOverride) {
      _settingsSubscription = ref.listenManual<SettingsState>(
        settingsControllerProvider,
        (previous, next) {
          if (!mounted) return;
          _selectedMode = next.analysisMode;
          if (!_isFallbackActiveNotifier.value ||
              next.analysisMode != AnalysisMode.geminiApi) {
            _effectiveMode = next.analysisMode;
          }
        },
      );
    }

    final initialTranscript = widget.simulatedTranscript?.trim() ?? '';
    final isSimulation =
        initialTranscript.isNotEmpty ||
        (widget.simulatedScenarioTitle?.trim().isNotEmpty ?? false);

    if (isSimulation) {
      _isSimulationModeNotifier.value = true;
    }

    if (initialTranscript.isNotEmpty) {
      _transcriptNotifier.value = initialTranscript;
    }
    if (_hasTestAnalyzerOverride && initialTranscript.isNotEmpty) {
      _analysisResultNotifier.value = const AnalysisResult(
        overallRiskLevel: RiskLevel.red,
        matches: <KeywordMatch>[
          KeywordMatch(
            keyword: 'OTP',
            level: RiskLevel.red,
            category: 'Test',
          ),
        ],
        reason: 'OTP',
        analysisLevel: AnalysisLevel.l1,
        alertEnabled: true,
      );
      _riskLevelNotifier.value = RiskLevel.red;
    }
    _startTimer();
    if (initialTranscript.isNotEmpty && !_hasTestAnalyzerOverride) {
      _analysisDebounce = Timer(const Duration(milliseconds: 1), () {
        unawaited(_ensureAnalysisComplete());
      });
    }

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _initStreams();
      unawaited(_startLiveMonitoringIfNeeded());
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    _analysisDebounce?.cancel();
    _transcriptSub?.cancel();
    _rmsSub?.cancel();
    _stateSub?.cancel();
    _settingsSubscription?.close();
    _riskLevelNotifier.dispose();
    _transcriptNotifier.dispose();
    _elapsedSecondsNotifier.dispose();
    _networkAvailableNotifier.dispose();
    _isFallbackActiveNotifier.dispose();
    _analysisResultNotifier.dispose();
    _isAnalyzingNotifier.dispose();
    _isEndingSessionNotifier.dispose();
    _isSimulationModeNotifier.dispose();
    _amplitudesNotifier.dispose();
    super.dispose();
  }

  void _startTimer() {
    if (_hasTestAnalyzerOverride) return;
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) {
        _elapsedSecondsNotifier.value++;
      }
    });
  }

  String _formatElapsedTime(int seconds) {
    final m = seconds ~/ 60;
    final s = seconds % 60;
    return '${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
  }

  void _initStreams() {
    if (_isSimulationSession()) return;

    _transcriptSub?.cancel();
    _rmsSub?.cancel();
    _stateSub?.cancel();

    final bridge = ref.read(nativeBridgeProvider);

    _transcriptSub = bridge.transcriptStream.listen((text) {
      if (!mounted) return;
      _transcriptNotifier.value = text;
      _runRealTimeAnalysis(text);
    });

    _rmsSub = bridge.rmsStream.listen((rms) {
      if (!mounted) return;
      final now = DateTime.now();
      if (_lastAmplitudeUpdate != null &&
          now.difference(_lastAmplitudeUpdate!).inMilliseconds < 50) {
        return;
      }
      _lastAmplitudeUpdate = now;
      if (_amplitudes.isNotEmpty) {
        _amplitudes.removeAt(0);
      }
      _amplitudes.add(max(0.1, rms));
      _amplitudesNotifier.value = List.from(_amplitudes);
    });

    _stateSub = bridge.monitoringStateStream.listen((stateData) {
      if (!mounted) return;
      final state = stateData.$1;
      if (state == MonitoringState.networkAvailable) {
        _networkAvailableNotifier.value = true;
        if (_selectedMode == AnalysisMode.geminiApi) {
          _effectiveMode = AnalysisMode.geminiApi;
          _isFallbackActiveNotifier.value = false;
        }
      } else if (state == MonitoringState.networkLost) {
        _networkAvailableNotifier.value = false;
        if (_effectiveMode == AnalysisMode.geminiApi) {
          _effectiveMode = AnalysisMode.gDetection;
          _isFallbackActiveNotifier.value = true;
        }
      } else if (state == MonitoringState.stopped && !_isEndingSession) {
        final finalTranscript = stateData.$3?.trim();
        if (finalTranscript != null && finalTranscript.isNotEmpty) {
          _transcriptNotifier.value = finalTranscript;
        }
        if (!mounted) return;
        _onEndSession();
      }
    });
  }

  bool _isSimulationSession() {
    final title = widget.simulatedScenarioTitle?.trim() ?? '';
    final script = widget.simulatedTranscript?.trim() ?? '';
    return title.isNotEmpty || script.isNotEmpty;
  }

  Future<void> _startLiveMonitoringIfNeeded() async {
    if (_isSimulationSession() || _hasAttemptedStart || !mounted) return;
    _hasAttemptedStart = true;

    final bridge = ref.read(nativeBridgeProvider);
    final settings = ref.read(settingsControllerProvider);
    final devMode = ref.read(developerModeProvider);

    final shouldUseCreatorMode =
        devMode.isActive && settings.creatorAudioCapture;

    if (shouldUseCreatorMode) {
      _isCreatorMode = true;
      final alreadyRunning = await bridge.isCreatorMonitoringActive();
      if (alreadyRunning) {
        return;
      }
      final started = await bridge.startCreatorMonitoring(
        devModeExpiresAtMs: devMode.expiresAtEpochMs,
      );
      if (started) {
        return;
      }
      _isCreatorMode = false;
    }

    final alreadyRunning = await bridge.isMonitoringActive();
    if (!alreadyRunning) {
      await bridge.startMonitoring(
        enableSpeakerphone: settings.autoEnableSpeakerphone,
      );
    }
  }

  String _formatSessionDateTime() {
    final now = DateTime.now();
    String two(int n) => n.toString().padLeft(2, '0');
    return '${two(now.hour)}:${two(now.minute)}:${two(now.second)} '
        '${two(now.day)}/${two(now.month)}/${now.year}';
  }

  Future<void> _ensureAnalysisComplete() async {
    if (_transcript.trim().isEmpty) return;
    _l1AnalysisFuture ??= _runMockAnalysis();
    await _l1AnalysisFuture;
  }

  Future<void> _onEndSession() async {
    if (_isEndingSession) return;
    _isEndingSessionNotifier.value = true;
    try {
      final bridge = ref.read(nativeBridgeProvider);
      if (_isCreatorMode) {
        await bridge.stopCreatorMonitoring();
      } else {
        await bridge.stopMonitoring();
      }
      await _ensureAnalysisComplete();
      if (!mounted) return;

      final risk = _riskLevel;
      final result = _analysisResult;
      final reason = result?.reason?.trim();
      final summaryParts = <String>[];
      if (_isSimulationSession()) {
        summaryParts.add('[Mô phỏng]');
      }
      if (reason != null && reason.isNotEmpty) {
        summaryParts.add(reason);
      } else {
        summaryParts.add(risk.vietnameseName);
      }
      final summary = summaryParts.join(' ');

      final flagCount = result?.matches.length ?? 0;
      final history = CallHistory(
        dateTime: _formatSessionDateTime(),
        riskLevel: risk.storageName,
        summary: summary,
        duration: _formatElapsedTime(_elapsedSecondsNotifier.value),
        flagCount: flagCount,
        transcript: _transcript,
        audioPath: null,
        analysisType: _effectiveMode.name,
      );

      final id = await ref.read(appDatabaseProvider).insert(history);
      if (!mounted) return;
      context.go('/result/$id');
    } catch (e, st) {
      debugPrint('End monitoring / save result failed: $e\n$st');
      if (mounted) {
        _isEndingSessionNotifier.value = false;
        context.go('/');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    final hasScenarioTitle =
        (widget.simulatedScenarioTitle?.trim().isNotEmpty ?? false);
    final isSimulation = _isSimulationSession();
    return TickerMode(
      enabled: !_hasTestAnalyzerOverride,
      child: Scaffold(
      appBar: AppBar(
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
                    style: tt.titleMedium?.copyWith(fontWeight: FontWeight.bold),
                  ),
                ),
                if (_isCreatorMode)
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
              showDialog(
                context: context,
                builder: (_) => const SettingsDialog(),
              );
            },
          ),
        ],
      ),

      // ── Bottom bar: End call button ──
      bottomNavigationBar: Padding(
        padding: const EdgeInsets.all(16),
        child: ValueListenableBuilder<bool>(
          valueListenable: _isEndingSessionNotifier,
          builder: (context, isEndingSession, _) {
            return ElevatedButton(
              onPressed: isEndingSession ? null : _onEndSession,
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
                  if (isEndingSession) ...[
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
                    isEndingSession
                        ? 'Đang lưu kết quả...'
                        : 'Kết thúc cuộc gọi',
                    style: tt.titleMedium?.copyWith(color: cs.onError),
                  ),
                ],
              ),
            );
          },
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
                child: RepaintBoundary(
                  child: ValueListenableBuilder<List<double>>(
                    valueListenable: _amplitudesNotifier,
                    builder: (context, amplitudes, _) {
                      return AudioWaveform(
                        amplitudes: amplitudes,
                        elapsedSeconds: _elapsedSecondsNotifier,
                      );
                    },
                  ),
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
                    ValueListenableBuilder<RiskLevel>(
                      valueListenable: _riskLevelNotifier,
                      builder: (context, riskLevel, _) {
                        return RiskLevelIndicator(riskLevel: riskLevel);
                      },
                    ),
                    ValueListenableBuilder<bool>(
                      valueListenable: _isAnalyzingNotifier,
                      builder: (context, isAnalyzing, _) {
                        return isAnalyzing
                            ? const Column(
                                children: [
                                  SizedBox(height: 8),
                                  LinearProgressIndicator(),
                                ],
                              )
                            : const SizedBox.shrink();
                      },
                    ),
                    ValueListenableBuilder<AnalysisResult?>(
                      valueListenable: _analysisResultNotifier,
                      builder: (context, result, _) {
                        if (result == null) return const SizedBox.shrink();
                        return Column(
                          children: [
                            const SizedBox(height: 8),
                            Align(
                              alignment: Alignment.centerLeft,
                              child: Text(
                                result.reason ?? '',
                                style: tt.bodySmall?.copyWith(
                                  color: cs.onSurfaceVariant,
                                ),
                              ),
                            ),
                            if (result.matches.isNotEmpty) ...[
                              const SizedBox(height: 8),
                              SizedBox(
                                width: double.infinity,
                                child: Wrap(
                                  spacing: 8,
                                  runSpacing: 4,
                                  children: result.matches.take(4).map((match) {
                                    return Chip(
                                      label: Text(match.keyword),
                                      visualDensity: VisualDensity.compact,
                                    );
                                  }).toList(),
                                ),
                              ),
                            ],
                          ],
                        );
                      },
                    ),
                    const SizedBox(height: 12),
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
                          ValueListenableBuilder<bool>(
                            valueListenable: _isFallbackActiveNotifier,
                            builder: (context, isFallback, _) {
                              return ActionChip(
                                label: Text(
                                  'Chạy: ${_modeLabel(_effectiveMode)}',
                                ),
                                backgroundColor: isFallback
                                    ? cs.tertiaryContainer
                                    : cs.secondaryContainer,
                                side: BorderSide.none,
                                onPressed: () {},
                              );
                            },
                          ),
                          const SizedBox(width: 8),
                          ValueListenableBuilder<bool>(
                            valueListenable: _networkAvailableNotifier,
                            builder: (context, networkAvailable, _) {
                              return ActionChip(
                                label: Text(
                                  networkAvailable ? 'Mạng: OK' : 'Mạng: Lỗi',
                                ),
                                backgroundColor: networkAvailable
                                    ? cs.surfaceContainerHighest
                                    : cs.errorContainer,
                                side: BorderSide.none,
                                onPressed: () {},
                              );
                            },
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
                        child: RepaintBoundary(
                          child: ValueListenableBuilder<String>(
                            valueListenable: _transcriptNotifier,
                            builder: (context, transcript, _) {
                              return LiveConversation(
                                transcript: transcript,
                                isSimulation: isSimulation,
                              );
                            },
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

  Future<void> _runMockAnalysis() async {
    _isAnalyzingNotifier.value = true;
    try {
      AnalysisResult result;
      if (_effectiveMode == AnalysisMode.geminiApi) {
        result = await _l3Analyzer.analyze(_transcript);
      } else if (_effectiveMode == AnalysisMode.gDetection) {
        final incrementalText =
            _transcript.length > _l2Analyzer.processedTextLength
            ? _transcript.substring(_l2Analyzer.processedTextLength)
            : '';
        result = await _l2Analyzer.analyze(incrementalText, _transcript);
      } else {
        result = await _l1Analyzer.analyze(_transcript);
      }

      if (!mounted) return;
      _analysisResultNotifier.value = result;
      _riskLevelNotifier.value = result.overallRiskLevel;
      _isAnalyzingNotifier.value = false;
    } catch (_) {
      if (!mounted) return;
      _analysisResultNotifier.value = const AnalysisResult(
        overallRiskLevel: RiskLevel.green,
        matches: [],
        reason: 'Lỗi khi chạy phân tích trên kịch bản mô phỏng.',
        analysisLevel: AnalysisLevel.l1,
        alertEnabled: false,
        isError: true,
      );
      _riskLevelNotifier.value = RiskLevel.green;
      _isAnalyzingNotifier.value = false;
    }
  }

  void _runRealTimeAnalysis(String text) {
    _analysisDebounce?.cancel();
    _analysisDebounce = Timer(const Duration(milliseconds: 600), () async {
      if (!mounted || text.trim().isEmpty) return;
      _isAnalyzingNotifier.value = true;
      try {
        // Dùng coordinator thay vì gọi analyzer trực tiếp —
        // coordinator xử lý minDelta cho mọi mode, incremental cho L3,
        // và fallback L3→L2 khi cần.
        AnalysisResult result;

        // Coordinator tự quản lý processedTextLength internal qua analyzer tracking.
        result = await _coordinator.analyzeIncremental(text, _effectiveMode);

        if (!mounted) return;

        // Nếu coordinator fallback sang L2, cập nhật effectiveMode
        final resultLevel = result.analysisLevel;
        if (resultLevel == AnalysisLevel.l2 &&
            _effectiveMode == AnalysisMode.geminiApi) {
          _effectiveMode = AnalysisMode.gDetection;
          _isFallbackActiveNotifier.value = true;
        }

        _analysisResultNotifier.value = result;
        _riskLevelNotifier.value = result.overallRiskLevel;
        _isAnalyzingNotifier.value = false;

        if (result.alertEnabled) {
          final bridge = ref.read(nativeBridgeProvider);
          if (result.overallRiskLevel == RiskLevel.red) {
            unawaited(
              bridge.showRedAlert(result.reason ?? 'Cảnh báo lừa đảo!'),
            );
          } else if (result.overallRiskLevel == RiskLevel.orange) {
            unawaited(
              bridge.showOrangeAlert(result.reason ?? 'Nội dung đáng ngờ!'),
            );
          }
        }
      } catch (e) {
        if (mounted) {
          _isAnalyzingNotifier.value = false;
        }
      }
    });
  }
}
