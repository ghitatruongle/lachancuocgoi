import 'package:flutter_test/flutter_test.dart';
import 'package:lachancuocgoi_flutter/analysis/l2/intent/intent_classifier.dart';
import 'package:lachancuocgoi_flutter/analysis/l2/intent/intent_classifier_factory.dart';
import 'package:lachancuocgoi_flutter/core/noop_asset_loader.dart';

void main() {
  test('desktop test runtime selects disabled intent classifier', () {
    final classifier = createPlatformIntentClassifier(
      assetLoader: const NoopAssetLoader(),
    );

    expect(classifier, isA<DisabledIntentClassifier>());
  });
}
