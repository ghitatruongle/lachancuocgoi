library;

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/asset_loader.dart';
import '../core/logger.dart';
import '../core/system_logger.dart';
import '../app/settings_controller.dart';
import '../services/flutter_services_impl.dart';
import 'analysis_coordinator.dart';
import 'l1/l1_analysis.dart';
import 'l2/g_detection/g_detection_engine.dart';
import 'l2/l2_analysis.dart';
import 'l3/l3_analysis.dart';

final assetLoaderProvider = Provider<AssetLoader>((ref) {
  return CachingAssetLoader(const FlutterAssetLoader());
});

final loggerProvider = Provider<AppLogger>((ref) => SystemLogger.instance);

final l1AnalyzerProvider = Provider<L1Analyzer>((ref) {
  final analyzer = L1Analyzer(
    assetLoader: ref.read(assetLoaderProvider),
    logger: ref.read(loggerProvider),
  );
  ref.onDispose(analyzer.dispose);
  return analyzer;
});

final gDetectionEngineProvider = Provider<GDetectionEngine>((ref) {
  final engine = GDetectionEngine(
    assetLoader: ref.read(assetLoaderProvider),
    logger: ref.read(loggerProvider),
  );
  ref.onDispose(engine.dispose);
  return engine;
});

final l2AnalyzerProvider = Provider<L2Analyzer>((ref) {
  final analyzer = L2Analyzer(
    assetLoader: ref.read(assetLoaderProvider),
    logger: ref.read(loggerProvider),
    gDetectionEngine: ref.read(gDetectionEngineProvider),
  );

  ref.onDispose(() {
    analyzer.dispose();
  });
  return analyzer;
});

final l3AnalyzerProvider = Provider<L3Analyzer>((ref) {
  final analyzer = L3Analyzer(
    assetLoader: ref.read(assetLoaderProvider),
    logger: ref.read(loggerProvider),
    cloudConsentStore: ref.read(cloudAnalysisConsentStoreProvider),
  );
  ref.onDispose(analyzer.dispose);
  return analyzer;
});

final analysisCoordinatorProvider = Provider<AnalysisCoordinator>((ref) {
  return AnalysisCoordinator(
    l1Analyzer: ref.read(l1AnalyzerProvider),
    l2Analyzer: ref.read(l2AnalyzerProvider),
    l3Analyzer: ref.read(l3AnalyzerProvider),
  );
});
