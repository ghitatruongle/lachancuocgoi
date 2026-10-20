import '../../../core/asset_loader.dart';
import '../../../core/logger.dart';
import 'intent_classifier.dart';

IntentClassifier createPlatformIntentClassifier({
  required AssetLoader assetLoader,
  AppLogger? logger,
}) {
  return const DisabledIntentClassifier();
}
