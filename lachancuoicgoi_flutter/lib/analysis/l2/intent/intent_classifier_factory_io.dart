import 'dart:io';

import '../../../core/asset_loader.dart';
import '../../../core/logger.dart';
import 'intent_classifier.dart';
import 'tflite_intent_classifier.dart';

IntentClassifier createPlatformIntentClassifier({
  required AssetLoader assetLoader,
  AppLogger? logger,
}) {
  if (Platform.isAndroid) {
    return TFLiteIntentClassifier(assetLoader: assetLoader, logger: logger);
  }
  return const DisabledIntentClassifier();
}
