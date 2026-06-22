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

import '../core/asset_loader.dart';
import '../core/logger.dart';
import '../services/flutter_services_impl.dart';
import 'analysis_coordinator.dart';
import 'l1/l1_analysis.dart';
import 'l2/g_detection/g_detection_engine.dart';
import 'l2/l2_analysis.dart';
import 'l3/l3_analysis.dart';

/// Providers for core abstraction services
final assetLoaderProvider = Provider<AssetLoader>((ref) => const FlutterAssetLoader());
final loggerProvider = Provider<AppLogger>((ref) => const FlutterLogger());

/// Singleton L1Analyzer — keyword trie is built once on first use.
final l1AnalyzerProvider = Provider<L1Analyzer>((ref) {
  final analyzer = L1Analyzer(
    assetLoader: ref.read(assetLoaderProvider),
    logger: ref.read(loggerProvider),
  );
  ref.onDispose(analyzer.dispose);
  return analyzer;
});

/// Phase 2.4: Singleton GDetectionEngine — loads 8 JSON files once,
/// survives L2Analyzer recreation.
final gDetectionEngineProvider = Provider<GDetectionEngine>((ref) {
  final engine = GDetectionEngine(
    assetLoader: ref.read(assetLoaderProvider),
    logger: ref.read(loggerProvider),
  );
  ref.onDispose(engine.dispose);
  return engine;
});

/// Singleton L2Analyzer — uses the singleton GDetectionEngine.
/// dispose() đóng TFLite isolate + GDetection internal state.
final l2AnalyzerProvider = Provider<L2Analyzer>((ref) {
  final analyzer = L2Analyzer(
    assetLoader: ref.read(assetLoaderProvider),
    logger: ref.read(loggerProvider),
    gDetectionEngine: ref.read(gDetectionEngineProvider),
  );
  // Chỉ dispose intent classifier + wfsa; GDetectionEngine do provider riêng
  // quản lý (onDispose ở trên). L2Analyzer.dispose() cũng gọi GDetection.dispose
  // → gấp đôi nhưng idempotent nên an toàn.
  ref.onDispose(() {
    analyzer.dispose();
  });
  return analyzer;
});

/// Singleton L3Analyzer — Gemini client & key health tracker are
/// initialized once. dispose() đóng GeminiChatSession.
final l3AnalyzerProvider = Provider<L3Analyzer>((ref) {
  final analyzer = L3Analyzer(
    assetLoader: ref.read(assetLoaderProvider),
    logger: ref.read(loggerProvider),
  );
  ref.onDispose(analyzer.dispose);
  return analyzer;
});

/// Singleton AnalysisCoordinator — uses the singleton analyzers above.
/// Analyzers tự dispose qua provider riêng; coordinator không sở hữu chúng.
final analysisCoordinatorProvider = Provider<AnalysisCoordinator>((ref) {
  return AnalysisCoordinator(
    l1Analyzer: ref.read(l1AnalyzerProvider),
    l2Analyzer: ref.read(l2AnalyzerProvider),
    l3Analyzer: ref.read(l3AnalyzerProvider),
  );
});
