import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../analysis/analysis_coordinator.dart';
import '../analysis/analysis_level.dart';
import '../analysis/analysis_mode.dart';
import '../analysis/analysis_result.dart';
import '../core/risk_level.dart';
import '../services/native_call_shield_bridge.dart';
import '../data/alert_history_entry.dart';

/// State for the monitoring session
class MonitoringState {
  const MonitoringState({
    this.isListening = false,
    this.transcript = '',
    this.analysisResult = const AnalysisResult(
      overallRiskLevel: RiskLevel.green,
      matches: [],
    ),
    this.currentAlert,
    this.elapsedSeconds = 0,
    this.amplitudes = const [],
    this.networkAvailable = true,
    this.isFallbackActive = false,
    this.selectedMode = AnalysisMode.normal,
    this.effectiveMode = AnalysisMode.normal,
    this.alertHistory = const [],
  });

  final bool isListening;
  final String transcript;
  final AnalysisResult analysisResult;
  final AlertInfo? currentAlert;
  final int elapsedSeconds;
  final List<double> amplitudes;
  final bool networkAvailable;
  final bool isFallbackActive;
  final AnalysisMode selectedMode;
  final AnalysisMode effectiveMode;
  final List<AlertHistoryEntry> alertHistory;

  MonitoringState copyWith({
    bool? isListening,
    String? transcript,
    AnalysisResult? analysisResult,
    AlertInfo? currentAlert,
    int? elapsedSeconds,
    List<double>? amplitudes,
    bool? networkAvailable,
    bool? isFallbackActive,
    AnalysisMode? selectedMode,
    AnalysisMode? effectiveMode,
    List<AlertHistoryEntry>? alertHistory,
  }) {
    return MonitoringState(
      isListening: isListening ?? this.isListening,
      transcript: transcript ?? this.transcript,
      analysisResult: analysisResult ?? this.analysisResult,
      currentAlert: currentAlert ?? this.currentAlert,
      elapsedSeconds: elapsedSeconds ?? this.elapsedSeconds,
      amplitudes: amplitudes ?? this.amplitudes,
      networkAvailable: networkAvailable ?? this.networkAvailable,
      isFallbackActive: isFallbackActive ?? this.isFallbackActive,
      selectedMode: selectedMode ?? this.selectedMode,
      effectiveMode: effectiveMode ?? this.effectiveMode,
      alertHistory: alertHistory ?? this.alertHistory,
    );
  }
}

class AlertInfo {
  const AlertInfo({required this.level, required this.reason});
  final RiskLevel level;
  final String reason;
}

/// Controller for managing the monitoring session
class MonitoringController extends StateNotifier<MonitoringState> {
  MonitoringController(this._bridge) : super(const MonitoringState()) {
    _setupListeners();
  }

  final NativeCallShieldBridge _bridge;
  final AnalysisCoordinator _analysisCoordinator = AnalysisCoordinator();
  
  StreamSubscription<String>? _transcriptSub;
  StreamSubscription<double>? _rmsSub;
  StreamSubscription<(MonitoringState, int?, String?)>? _monitoringStateSub;
  Timer? _elapsedTimer;
  
  static const int _waveformSize = 100;
  final List<double> _amplitudes = List.filled(_waveformSize, 0.0);

  /// Settings for the monitoring session
  AnalysisMode _selectedMode = AnalysisMode.normal;
  bool _networkAvailable = true;

  void _setupListeners() {
    // Listen to transcript stream from native
    _transcriptSub = _bridge.transcriptStream.listen((transcript) {
      if (transcript.isNotEmpty) {
        state = state.copyWith(transcript: transcript);
        _analyzeTranscript(transcript);
      }
    });

    // Listen to RMS stream for waveform
    _rmsSub = _bridge.rmsStream.listen((rms) {
      _updateAmplitudes(rms);
    });

    // Listen to monitoring state changes
    _monitoringStateSub = _bridge.monitoringStateStream.listen((event) {
      final (monitoringState, duration, finalTranscript) = event;
      debugPrint('Monitoring state changed: $monitoringState');
      
      switch (monitoringState) {
        case MonitoringState.started:
          debugPrint('Monitoring started');
          break;
        case MonitoringState.stopped:
          debugPrint('Monitoring stopped. Duration: $duration, Transcript: $finalTranscript');
          stopMonitoring();
          break;
        case MonitoringState.networkAvailable:
          _networkAvailable = true;
          state = state.copyWith(
            networkAvailable: true,
            isFallbackActive: false,
            effectiveMode: _selectedMode,
          );
          break;
        case MonitoringState.networkLost:
          _networkAvailable = false;
          if (_selectedMode == AnalysisMode.geminiApi) {
            state = state.copyWith(
              networkAvailable: false,
              isFallbackActive: true,
              effectiveMode: AnalysisMode.gDetection,
              currentAlert: AlertInfo(
                level: RiskLevel.yellow,
                reason: 'Mất kết nối mạng. Hệ thống tạm chuyển sang L2 để duy trì bảo vệ.',
              ),
            );
          }
          break;
        default:
          break;
      }
    });
  }

  void _updateAmplitudes(double rms) {
    final normalized = ((rms / 15.0) + 0.1).clamp(0.0, 1.0);
    _amplitudes.add(normalized);
    if (_amplitudes.length > _waveformSize) {
      _amplitudes.removeAt(0);
    }
    state = state.copyWith(amplitudes: List.unmodifiable(_amplitudes));
  }

  Future<void> _analyzeTranscript(String transcript) async {
    try {
      final result = await _analysisCoordinator.analyzeIncremental(
        transcript,
        state.effectiveMode,
      );
      state = state.copyWith(
        analysisResult: result,
        currentAlert: _shouldShowAlert(result) 
            ? AlertInfo(level: result.overallRiskLevel, reason: result.reason ?? '')
            : null,
      );
    } catch (e) {
      debugPrint('Analysis error: $e');
    }
  }

  bool _shouldShowAlert(AnalysisResult result) {
    return result.alertEnabled && 
           result.overallRiskLevel.index >= RiskLevel.orange.index;
  }

  /// Start monitoring service
  Future<bool> startMonitoring({
    AnalysisMode mode = AnalysisMode.normal,
    String? phoneNumber,
  }) async {
    debugPrint('Starting monitoring with mode: $mode');
    
    _selectedMode = mode;
    _networkAvailable = true;
    
    // Reset state
    _amplitudes.clear();
    _amplitudes.addAll(List.filled(_waveformSize, 0.0));
    
    state = state.copyWith(
      isListening: true,
      transcript: '',
      analysisResult: const AnalysisResult(
        overallRiskLevel: RiskLevel.green,
        matches: [],
      ),
      currentAlert: null,
      elapsedSeconds: 0,
      amplitudes: List.unmodifiable(_amplitudes),
      networkAvailable: true,
      isFallbackActive: false,
      selectedMode: mode,
      effectiveMode: mode,
      alertHistory: [],
    );

    // Start timer
    _elapsedTimer?.cancel();
    _elapsedTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      state = state.copyWith(elapsedSeconds: state.elapsedSeconds + 1);
    });

    // Start native monitoring
    final success = await _bridge.startMonitoring(
      phoneNumber: phoneNumber,
    );

    if (success) {
      debugPrint('Monitoring started successfully');
    } else {
      debugPrint('Failed to start monitoring');
    }

    return success;
  }

  /// Stop monitoring service
  Future<void> stopMonitoring() async {
    debugPrint('Stopping monitoring...');
    
    _elapsedTimer?.cancel();
    _transcriptSub?.cancel();
    _rmsSub?.cancel();
    _monitoringStateSub?.cancel();

    await _bridge.stopMonitoring();
    await _bridge.dismissAlert();

    state = state.copyWith(
      isListening: false,
      currentAlert: null,
    );

    debugPrint('Monitoring stopped');
  }

  /// Dismiss current alert
  Future<void> dismissAlert() async {
    await _bridge.dismissAlert();
    state = state.copyWith(currentAlert: null);
  }

  /// Show red alert
  Future<void> showRedAlert(String reason) async {
    await _bridge.showRedAlert(reason);
  }

  /// Show orange alert
  Future<void> showOrangeAlert(String reason) async {
    await _bridge.showOrangeAlert(reason);
  }

  @override
  void dispose() {
    _elapsedTimer?.cancel();
    _transcriptSub?.cancel();
    _rmsSub?.cancel();
    _monitoringStateSub?.cancel();
    super.dispose();
  }
}

// ─── Riverpod Providers ───────────────────────────────────────────────────────

final monitoringControllerProvider = StateNotifierProvider<MonitoringController, MonitoringState>((ref) {
  final bridge = ref.watch(nativeBridgeProvider);
  return MonitoringController(bridge);
});
