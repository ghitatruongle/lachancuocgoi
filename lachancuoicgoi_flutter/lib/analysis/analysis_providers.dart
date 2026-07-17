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
import '../core/system_logger.dart';
import '../data/remote_config_store.dart';
import '../services/flutter_services_impl.dart';
import 'analysis_coordinator.dart';
import 'l1/l1_analysis.dart';
import 'l2/g_detection/g_detection_engine.dart';
import 'l2/l2_analysis.dart';
import 'l3/l3_analysis.dart';

/// Phase 2 (P2-3): Composite asset loader — disk-first (OTA downloads),
/// falls back to the Flutter asset bundle when no OTA file is present.
/// Wrapped in CachingAssetLoader so JSON/config files are parsed once.
final assetLoaderProvider = Provider<AssetLoader>((ref) {
  const flutterLoader = FlutterAssetLoader();
  final diskLoader = DiskAssetLoader();
  final remoteStore = ref.watch(remoteConfigStoreProvider);
  if (remoteStore != null) {
    ref.onDispose(remoteStore.dispose);
  }
  final composite = CompositeAssetLoader(primary: diskLoader, fallback: flutterLoader);
  return CachingAssetLoader(composite);
});

/// Unified logger: SystemLogger implements AppLogger, so all analysis-layer
/// logs are also visible in the UI System Log viewer.
final loggerProvider = Provider<AppLogger>((ref) => SystemLogger.instance);

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
