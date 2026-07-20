import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart';
import 'package:lachancuocgoi_flutter/analysis/l2/intent/intent_output_mapper.dart';
import 'package:lachancuocgoi_flutter/analysis/l2/intent/scam_intent.dart';

void main() {
  group('IntentOutputMapper.decodeFlatOutput - empty and short tensors', () {
    test('empty tensor returns empty list', () {
      final result = IntentOutputMapper.decodeFlatOutput(<num>[]);
      expect(result, isEmpty);
    });

    test('tensor shorter than intentLabels fills remaining with zeros', () {
      final shortTensor = List<num>.filled(intentLabels.length - 1, 1.0);
      final result = IntentOutputMapper.decodeFlatOutput(shortTensor);
      // Graceful mismatch: uses min(rawOutput, intentLabels) classes.
      // Remaining slots filled with 0.
      expect(result.length, intentLabels.length);
      expect(result.last, 0.0);
    });

    test('tensor exactly intentLabels length returns correct length', () {
      final exactTensor = List<num>.filled(intentLabels.length, 1.0);
      final result = IntentOutputMapper.decodeFlatOutput(exactTensor);
      expect(result.length, intentLabels.length);
    });

    test(
      'tensor longer than intentLabels truncates to intentLabels length',
      () {
        final longTensor = List<num>.filled(intentLabels.length + 10, 1.0);
        final result = IntentOutputMapper.decodeFlatOutput(longTensor);
        expect(result.length, intentLabels.length);
      },
    );
  });

  group('IntentOutputMapper.decodeFlatOutput - all-zero logits', () {
    test('all-zero float32 tensor returns all zeros', () {
      final zeros = List<num>.filled(intentLabels.length, 0.0);
      final result = IntentOutputMapper.decodeFlatOutput(
        zeros,
        outputType: IntentOutputType.float32,
      );
      expect(result.every((v) => v == 0.0), isTrue);
    });

    test('all-zero uint8 with zeroPoint=0 returns all zeros', () {
      final zeros = List<num>.filled(intentLabels.length, 0);
      final result = IntentOutputMapper.decodeFlatOutput(
        zeros,
        outputType: IntentOutputType.uint8,
        scale: 0.1,
        zeroPoint: 0,
      );
      expect(result.every((v) => v == 0.0), isTrue);
    });

    test('uint8 values equal to zeroPoint return zero', () {
      final values = List<num>.filled(intentLabels.length, 128);
      final result = IntentOutputMapper.decodeFlatOutput(
        values,
        outputType: IntentOutputType.uint8,
        scale: 0.1,
        zeroPoint: 128,
      );
      expect(result.every((v) => v == 0.0), isTrue);
    });
  });

  group('IntentOutputMapper.decodeFlatOutput - single class output', () {
    test('single high value among zeros gives that class dominance', () {
      final raw = List<num>.filled(intentLabels.length, 0.0);
      raw[0] = 10.0;
      final logits = IntentOutputMapper.decodeFlatOutput(
        raw,
        outputType: IntentOutputType.float32,
      );
      final predictions = IntentOutputMapper.predictionsFromLogits(logits);

      expect(predictions.first.intent, intentLabels[0]);
      expect(predictions.first.confidence, greaterThan(0.9));
    });
  });

  group('IntentOutputMapper.decodeFlatOutput - different tensor types', () {
    test('float32 passes raw values directly', () {
      final raw = List<num>.filled(intentLabels.length, 0.0);
      raw[0] = 1.5;
      raw[1] = -2.3;
      final result = IntentOutputMapper.decodeFlatOutput(
        raw,
        outputType: IntentOutputType.float32,
      );
      expect(result[0], closeTo(1.5, 0.0001));
      expect(result[1], closeTo(-2.3, 0.0001));
    });

    test('uint8 applies (raw & 0xFF - zeroPoint) * scale', () {
      final raw = List<num>.filled(intentLabels.length, 0);
      raw[0] = 200;
      final result = IntentOutputMapper.decodeFlatOutput(
        raw,
        outputType: IntentOutputType.uint8,
        scale: 0.5,
        zeroPoint: 128,
      );
      // (200 & 0xFF - 128) * 0.5 = (200 - 128) * 0.5 = 36.0
      expect(result[0], closeTo(36.0, 0.0001));
    });

    test('uint8 masks to 0xFF for values > 255', () {
      final raw = List<num>.filled(intentLabels.length, 0);
      raw[0] = 300; // 300 & 0xFF = 44
      final result = IntentOutputMapper.decodeFlatOutput(
        raw,
        outputType: IntentOutputType.uint8,
        scale: 1.0,
        zeroPoint: 0,
      );
      expect(result[0], closeTo(44.0, 0.0001));
    });

    test('int8 applies (raw - zeroPoint) * scale', () {
      final raw = List<num>.filled(intentLabels.length, 0);
      raw[0] = 50;
      raw[1] = -30;
      final result = IntentOutputMapper.decodeFlatOutput(
        raw,
        outputType: IntentOutputType.int8,
        scale: 0.25,
        zeroPoint: 10,
      );
      // (50 - 10) * 0.25 = 10.0
      expect(result[0], closeTo(10.0, 0.0001));
      // (-30 - 10) * 0.25 = -10.0
      expect(result[1], closeTo(-10.0, 0.0001));
    });

    test('float32 ignores scale and zeroPoint parameters', () {
      final raw = List<num>.filled(intentLabels.length, 3.0);
      final result = IntentOutputMapper.decodeFlatOutput(
        raw,
        outputType: IntentOutputType.float32,
        scale: 100.0,
        zeroPoint: 999,
      );
      expect(result.every((v) => v == 3.0), isTrue);
    });
  });

  group('IntentOutputMapper.predictionsFromLogits - edge cases', () {
    test('empty logits returns empty list', () {
      final result = IntentOutputMapper.predictionsFromLogits(<double>[]);
      expect(result, isEmpty);
    });

    test('logits shorter than intentLabels uses available logits', () {
      final result = IntentOutputMapper.predictionsFromLogits(<double>[
        1.0,
        2.0,
      ]);
      // Graceful mismatch: returns predictions for available logits.
      expect(result.length, 2);
    });

    test('all-zero logits produces uniform distribution', () {
      final zeros = List<double>.filled(intentLabels.length, 0.0);
      final predictions = IntentOutputMapper.predictionsFromLogits(zeros);

      expect(predictions.length, intentLabels.length);
      final expectedProb = 1.0 / intentLabels.length;
      for (final p in predictions) {
        expect(p.confidence, closeTo(expectedProb, 0.001));
      }
    });

    test('predictions are sorted descending by confidence', () {
      final logits = List<double>.filled(intentLabels.length, 0.0);
      logits[5] = 10.0;
      logits[10] = 5.0;
      final predictions = IntentOutputMapper.predictionsFromLogits(logits);

      for (var i = 0; i < predictions.length - 1; i++) {
        expect(
          predictions[i].confidence,
          greaterThanOrEqualTo(predictions[i + 1].confidence),
        );
      }
    });

    test('all predictions have valid confidence range [0, 1]', () {
      final logits = List<double>.generate(
        intentLabels.length,
        (i) => (i - 5).toDouble(),
      );
      final predictions = IntentOutputMapper.predictionsFromLogits(logits);

      for (final p in predictions) {
        expect(p.confidence, greaterThanOrEqualTo(0.0));
        expect(p.confidence, lessThanOrEqualTo(1.0));
      }
    });

    test('sum of all confidences equals 1.0', () {
      final logits = List<double>.generate(
        intentLabels.length,
        (i) => math.sin(i.toDouble()),
      );
      final predictions = IntentOutputMapper.predictionsFromLogits(logits);

      final total = predictions.fold<double>(0, (sum, p) => sum + p.confidence);
      expect(total, closeTo(1.0, 0.0001));
    });

    test('each ScamIntent label appears exactly once', () {
      final logits = List<double>.filled(intentLabels.length, 1.0);
      final predictions = IntentOutputMapper.predictionsFromLogits(logits);

      final intents = predictions.map((p) => p.intent).toSet();
      expect(intents.length, intentLabels.length);
      for (final label in intentLabels) {
        expect(intents.contains(label), isTrue);
      }
    });
  });

  group('IntentOutputMapper.softmax - edge cases', () {
    test('empty input returns empty', () {
      expect(IntentOutputMapper.softmax(<double>[]), isEmpty);
    });

    test('single element returns 1.0', () {
      final result = IntentOutputMapper.softmax(<double>[5.0]);
      expect(result.length, 1);
      expect(result[0], closeTo(1.0, 0.0001));
    });

    test('equal values produce uniform distribution', () {
      final result = IntentOutputMapper.softmax(<double>[3.0, 3.0, 3.0]);
      expect(result.length, 3);
      for (final p in result) {
        expect(p, closeTo(1.0 / 3, 0.0001));
      }
    });

    test('dominant value gets near 1.0 probability', () {
      final result = IntentOutputMapper.softmax(<double>[0.0, 0.0, 100.0]);
      expect(result[2], closeTo(1.0, 0.001));
      expect(result[0], closeTo(0.0, 0.001));
      expect(result[1], closeTo(0.0, 0.001));
    });

    test('handles very large values without overflow', () {
      final result = IntentOutputMapper.softmax(<double>[
        1000.0,
        1000.0,
        1000.0,
      ]);
      expect(result, <double>[1 / 3, 1 / 3, 1 / 3]);
    });

    test('handles very negative values', () {
      final result = IntentOutputMapper.softmax(<double>[
        -1000.0,
        -1000.0,
        -1000.0,
      ]);
      expect(result.length, 3);
      final sum = result.reduce((a, b) => a + b);
      expect(sum, closeTo(1.0, 0.0001));
    });

    test('handles mix of large positive and negative', () {
      final result = IntentOutputMapper.softmax(<double>[100.0, -100.0]);
      expect(result[0], closeTo(1.0, 0.001));
      expect(result[1], closeTo(0.0, 0.001));
    });

    test('all-positive infinity values return all zeros (NaN fallback)', () {
      // When all values are inf, maxLogit = inf, diff = inf - inf = NaN
      // exp(NaN) = NaN, sum = NaN, code returns all zeros
      final result = IntentOutputMapper.softmax(<double>[
        double.infinity,
        double.infinity,
      ]);
      expect(result.length, 2);
      expect(result[0], 0.0);
      expect(result[1], 0.0);
    });

    test('negative infinity values return all zeros (NaN fallback)', () {
      // When all values are -inf, maxLogit = -inf, diff = NaN, sum = NaN
      // Code returns all zeros when sum is NaN
      final result = IntentOutputMapper.softmax(<double>[
        double.negativeInfinity,
        double.negativeInfinity,
      ]);
      expect(result.length, 2);
      expect(result[0], 0.0);
      expect(result[1], 0.0);
    });
  });

  group('IntentOutputMapper - name-based labelOrder (model 23-class)', () {
    /// The real model order from accuracy_per_label.md + stage34 CSV.
    /// 23 classes — fakeEcommerce/cryptoDrain are NOT in the model.
    final modelLabelOrder = <ScamIntent>[
      ScamIntent.authPoliceLawsuit, // 0
      ScamIntent.taxGovApp, // 1
      ScamIntent.telecomLock, // 2
      ScamIntent.techSupportHijack, // 3
      ScamIntent.hospitalEmergency, // 4
      ScamIntent.virtualKidnapping, // 5
      ScamIntent.ceoFraudB2b, // 6
      ScamIntent.socialDeepfakeLoan, // 7
      ScamIntent.romanceScam, // 8
      ScamIntent.sextortionBlackmail, // 9
      ScamIntent.charityDonation, // 10
      ScamIntent.investmentScam, // 11
      ScamIntent.jobTaskScam, // 12
      ScamIntent.giftLottery, // 13
      ScamIntent.gamblingPrediction, // 14
      ScamIntent.immigrationVisaScam, // 15
      ScamIntent.bankCardFraud, // 16
      ScamIntent.deliveryCod, // 17
      ScamIntent.fakeSubscription, // 18
      ScamIntent.blackCreditTerror, // 19
      ScamIntent.recoveryScam, // 20
      ScamIntent.genericScam, // 21 ← NOT fakeEcommerce
      ScamIntent.safe, // 22 ← NOT cryptoDrain
    ];

    test('predictionsFromLogits with labelOrder: index 16 → bankCardFraud', () {
      final logits = List<double>.filled(modelLabelOrder.length, 0.0);
      logits[16] = 10.0; // Model says BANK_CARD_FRAUD

      final predictions = IntentOutputMapper.predictionsFromLogits(
        logits,
        labelOrder: modelLabelOrder,
      );

      expect(predictions.first.intent, ScamIntent.bankCardFraud);
      expect(predictions.first.confidence, greaterThan(0.9));
    });

    test(
      'predictionsFromLogits with labelOrder: index 21 → genericScam (not fakeEcommerce)',
      () {
        final logits = List<double>.filled(modelLabelOrder.length, 0.0);
        logits[21] = 10.0; // Model says GENERIC_SCAM

        final predictions = IntentOutputMapper.predictionsFromLogits(
          logits,
          labelOrder: modelLabelOrder,
        );

        expect(predictions.first.intent, ScamIntent.genericScam);
        expect(predictions.first.intent, isNot(ScamIntent.fakeEcommerce));
      },
    );

    test(
      'predictionsFromLogits with labelOrder: index 22 → safe (not cryptoDrain)',
      () {
        final logits = List<double>.filled(modelLabelOrder.length, 0.0);
        logits[22] = 10.0; // Model says SAFE

        final predictions = IntentOutputMapper.predictionsFromLogits(
          logits,
          labelOrder: modelLabelOrder,
        );

        expect(predictions.first.intent, ScamIntent.safe);
        expect(predictions.first.intent, isNot(ScamIntent.cryptoDrain));
      },
    );

    test('labelOrder=null falls back to global intentLabels (25 entries)', () {
      final logits = List<double>.filled(intentLabels.length, 0.0);
      logits[0] = 10.0;

      final predictions = IntentOutputMapper.predictionsFromLogits(logits);

      expect(predictions.length, intentLabels.length); // 25, not 23
      expect(predictions.first.intent, intentLabels[0]);
    });

    test('calibratedPredictions with labelOrder: index 16 → bankCardFraud', () {
      final raw = List<num>.filled(modelLabelOrder.length, 0);
      raw[16] = 200; // uint8 for BANK_CARD_FRAUD

      final predictions = IntentOutputMapper.calibratedPredictions(
        raw,
        outputType: IntentOutputType.uint8,
        scale: 0.1,
        zeroPoint: 128,
        labelOrder: modelLabelOrder,
      );

      expect(predictions.first.intent, ScamIntent.bankCardFraud);
    });

    test('decodeFlatOutput with labelOrder uses modelLabelOrder length', () {
      final shortTensor = List<num>.filled(modelLabelOrder.length, 1.0);
      final result = IntentOutputMapper.decodeFlatOutput(
        shortTensor,
        labelOrder: modelLabelOrder,
      );
      // When labelOrder is provided, output length = labelOrder.length (23)
      expect(result.length, modelLabelOrder.length);
    });
  });

  group('IntentOutputMapper full pipeline', () {
    test(
      'decodeFlatOutput + predictionsFromLogits produces sorted predictions',
      () {
        final raw = List<num>.filled(intentLabels.length, 0);
        raw[ScamIntent.romanceScam.index] = 200;
        raw[ScamIntent.safe.index] = 50;

        final logits = IntentOutputMapper.decodeFlatOutput(
          raw,
          outputType: IntentOutputType.uint8,
          scale: 0.1,
          zeroPoint: 128,
        );
        final predictions = IntentOutputMapper.predictionsFromLogits(logits);

        expect(predictions.first.intent, ScamIntent.romanceScam);
        expect(predictions.length, intentLabels.length);

        // Verify descending order
        for (var i = 0; i < predictions.length - 1; i++) {
          expect(
            predictions[i].confidence,
            greaterThanOrEqualTo(predictions[i + 1].confidence),
          );
        }
      },
    );
  });
}
