import '../../../core/asset_loader.dart';
import '../../../core/logger.dart';
import 'intent_classifier.dart';

/// Web intentionally uses GDetection/WFSA and never imports TFLite/`dart:ffi`.
IntentClassifier createPlatformIntentClassifier({
  required AssetLoader assetLoader,
  AppLogger? logger,
}) {
  return const DisabledIntentClassifier();
}
