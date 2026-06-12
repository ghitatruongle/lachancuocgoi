/// Riverpod Providers for analysis singletons.
///
/// Fixes CRITICAL Bug #2: L1/L2/L3 Analyzers and AnalysisCoordinator
/// were instantiated every time MonitoringPage was navigated to,
/// causing repeated JSON/TFLite/Trie loading (500ms-2s CPU spike,
/// ~20MB RAM waste per navigation).
///
/// Now they are singletons managed by Riverpod — created once,
/// reused across all navigation events.
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'analysis_coordinator.dart';
import 'l1/l1_analysis.dart';
import 'l2/g_detection/g_detection_engine.dart';
import 'l2/l2_analysis.dart';
import 'l3/l3_analysis.dart';

/// Singleton L1Analyzer — keyword trie is built once on first use.
final l1AnalyzerProvider = Provider<L1Analyzer>((ref) {
  return L1Analyzer();
});

/// Phase 2.4: Singleton GDetectionEngine — loads 8 JSON files once,
/// survives L2Analyzer recreation.
final gDetectionEngineProvider = Provider<GDetectionEngine>((ref) {
  return GDetectionEngine();
});

/// Singleton L2Analyzer — uses the singleton GDetectionEngine.
final l2AnalyzerProvider = Provider<L2Analyzer>((ref) {
  return L2Analyzer(
    gDetectionEngine: ref.read(gDetectionEngineProvider),
  );
});

/// Singleton L3Analyzer — Gemini client & key health tracker are
/// initialized once.
final l3AnalyzerProvider = Provider<L3Analyzer>((ref) {
  return L3Analyzer();
});

/// Singleton AnalysisCoordinator — uses the singleton analyzers above.
final analysisCoordinatorProvider = Provider<AnalysisCoordinator>((ref) {
  return AnalysisCoordinator(
    l1Analyzer: ref.read(l1AnalyzerProvider),
    l2Analyzer: ref.read(l2AnalyzerProvider),
    l3Analyzer: ref.read(l3AnalyzerProvider),
  );
});
