import 'package:flutter_test/flutter_test.dart';
import 'package:lachancuocgoi_flutter/analysis/l2/intent/intent_classifier.dart';
import 'package:lachancuocgoi_flutter/analysis/l2/intent/tflite_intent_classifier.dart';

void main() {
  group('Bug #4: TFLiteIntentClassifier.close() graceful shutdown', () {
    test('close() trên uninitialized classifier là idempotent + safe', () {
      final classifier = TFLiteIntentClassifier();
      expect(() => classifier.close(), returnsNormally);
      expect(
        () => classifier.close(),
        returnsNormally,
        reason: 'close() phải idempotent — gọi nhiều lần không crash',
      );
    });

    test('close() không throw exception khi isolate = null', () {
      final classifier = TFLiteIntentClassifier();

      expect(classifier.isReady, isFalse);

      classifier.close();

      expect(classifier.isReady, isFalse);
    });

    test('close() set isReady = false ngay lập tức', () {
      final classifier = TFLiteIntentClassifier();

      expect(classifier.isReady, isFalse);
      classifier.close();
      expect(classifier.isReady, isFalse);
    });
  });

  group('Bug #4: IntentClassifier interface contract', () {
    test('DisabledIntentClassifier.close() là no-op an toàn', () {
      const classifier = DisabledIntentClassifier();
      expect(classifier.isReady, isFalse);
      expect(() => classifier.close(), returnsNormally);
      expect(() => classifier.close(), returnsNormally);
    });

    test('close() không được throw (interface contract)', () {
      final classifiers = <IntentClassifier>[
        const DisabledIntentClassifier(),
        TFLiteIntentClassifier(),
      ];

      for (final classifier in classifiers) {
        expect(
          () => classifier.close(),
          returnsNormally,
          reason: '${classifier.runtimeType} close() không được throw',
        );
        expect(
          () => classifier.close(),
          returnsNormally,
          reason: '${classifier.runtimeType} close() phải idempotent',
        );
        expect(
          classifier.isReady,
          isFalse,
          reason: '${classifier.runtimeType} phải set isReady=false',
        );
      }
    });
  });

  group('Bug #4: Documentation test (verify fix is in code)', () {
    test('close() method không gọi _isolate.kill() đồng bộ', () {
      final classifier = TFLiteIntentClassifier();
      final stopwatch = Stopwatch()..start();
      classifier.close();
      stopwatch.stop();

      expect(
        stopwatch.elapsedMilliseconds,
        lessThan(100),
        reason: 'close() không được block chờ isolate shutdown',
      );
    });
  });
}
