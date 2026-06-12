import 'package:flutter_test/flutter_test.dart';
import 'package:lachancuocgoi_flutter/analysis/l2/intent/intent_classifier.dart';

void main() {
  group('DisabledIntentClassifier', () {
    test('isReady returns false before initialization', () {
      const classifier = DisabledIntentClassifier();
      expect(classifier.isReady, isFalse);
    });

    test('isReady returns false after initialization', () async {
      const classifier = DisabledIntentClassifier();
      await classifier.initialize();
      expect(classifier.isReady, isFalse);
    });

    test('predictIntent returns empty list', () async {
      const classifier = DisabledIntentClassifier();
      final predictions = await classifier.predictIntent('any transcript');
      expect(predictions, isEmpty);
    });

    test('predictIntent returns empty list even with OTP text', () async {
      const classifier = DisabledIntentClassifier();
      final predictions =
          await classifier.predictIntent('gửi mã otp cho tôi');
      expect(predictions, isEmpty);
    });

    test('predictIntent returns const empty list (same instance)', () async {
      const classifier = DisabledIntentClassifier();
      final first = await classifier.predictIntent('test');
      final second = await classifier.predictIntent('test');
      expect(identical(first, second), isTrue);
    });

    test('initialize is a no-op (completes without error)', () async {
      const classifier = DisabledIntentClassifier();
      // Should complete without throwing
      await classifier.initialize();
    });

    test('close is a no-op (completes without error)', () {
      const classifier = DisabledIntentClassifier();
      // Should complete without throwing
      classifier.close();
    });

    test('implements IntentClassifier interface', () {
      const classifier = DisabledIntentClassifier();
      expect(classifier, isA<IntentClassifier>());
    });

    test('can be used as const', () {
      const a = DisabledIntentClassifier();
      const b = DisabledIntentClassifier();
      expect(identical(a, b), isTrue);
    });
  });
}
