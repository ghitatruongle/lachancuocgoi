import '../../core/asset_loader.dart';
import '../../core/logger.dart';
import 'g_detection/g_detection_engine.dart';
import 'intent/intent_classifier.dart';
import 'safety/safety_filter.dart';

/// Shared concurrent-init guard for L2 components (v1.6.5 extract).
///
/// Multiple [initialize] callers share one in-flight Future; failed init
/// clears the cache so the next call can retry.
class L2Initialization {
  L2Initialization({
    required GDetectionEngine gDetectionEngine,
    required IntentClassifier intentClassifier,
    required AssetLoader assetLoader,
    AppLogger? logger,
  }) : _gDetectionEngine = gDetectionEngine,
       _intentClassifier = intentClassifier,
       _assetLoader = assetLoader,
       _logger = logger;

  final GDetectionEngine _gDetectionEngine;
  final IntentClassifier _intentClassifier;
  final AssetLoader _assetLoader;
  final AppLogger? _logger;

  Future<void>? _initFuture;

  Future<void> initialize() async {
    final pending = _initFuture;
    if (pending != null) return pending;

    try {
      final future = _doInitialize();
      _initFuture = future;
      return await future;
    } catch (_) {
      _initFuture = null;
      rethrow;
    }
  }

  Future<void> _doInitialize() async {
    await Future.wait(<Future<void>>[
      _gDetectionEngine.initialize(),
      _intentClassifier.initialize(),
      SafetyFilter.loadConfig(assetLoader: _assetLoader, logger: _logger),
    ]);
  }

  /// Clears cached init so the next [initialize] reloads components.
  void invalidate() {
    _initFuture = null;
  }
}
