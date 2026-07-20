import 'dart:io';

import '../../../core/asset_loader.dart';
import '../../../core/logger.dart';
import 'intent_classifier.dart';
import 'tflite_intent_classifier.dart';

/// Android uses the real bundled TFLite classifier. Other native platforms
/// remain honest demo targets and use the GDetection/WFSA fallback pipeline.
IntentClassifier createPlatformIntentClassifier({
  required AssetLoader assetLoader,
  AppLogger? logger,
}) {
  if (Platform.isAndroid) {
    return TFLiteIntentClassifier(assetLoader: assetLoader, logger: logger);
  }
  return const DisabledIntentClassifier();
}
