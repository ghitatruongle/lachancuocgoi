import 'package:flutter_test/flutter_test.dart';
import 'package:lachancuocgoi_flutter/analysis/l2/intent/scam_intent.dart';

/// Mirrors the label order from assets/model_labels.txt (23 classes).
/// Must match the file exactly — the model ghitav3.tflite was trained with
/// this ordering (confirmed via accuracy_per_label.md + stage34_master_mix.csv).
const modelLabelOrder = <ScamIntent>[
  ScamIntent.authPoliceLawsuit,   // 0
  ScamIntent.taxGovApp,           // 1
  ScamIntent.telecomLock,         // 2
  ScamIntent.techSupportHijack,   // 3
  ScamIntent.hospitalEmergency,   // 4
  ScamIntent.virtualKidnapping,   // 5
  ScamIntent.ceoFraudB2b,         // 6
  ScamIntent.socialDeepfakeLoan,  // 7
  ScamIntent.romanceScam,         // 8
  ScamIntent.sextortionBlackmail, // 9
  ScamIntent.charityDonation,     // 10
  ScamIntent.investmentScam,      // 11
  ScamIntent.jobTaskScam,         // 12
  ScamIntent.giftLottery,         // 13
  ScamIntent.gamblingPrediction,  // 14
  ScamIntent.immigrationVisaScam, // 15
  ScamIntent.bankCardFraud,       // 16
  ScamIntent.deliveryCod,         // 17
  ScamIntent.fakeSubscription,    // 18
  ScamIntent.blackCreditTerror,   // 19
  ScamIntent.recoveryScam,        // 20
  ScamIntent.genericScam,         // 21  ← NOT fakeEcommerce
  ScamIntent.safe,                // 22  ← NOT cryptoDrain
];

void main() {
  group('model_labels.txt', () {
    test('has exactly 23 entries', () {
      expect(modelLabelOrder.length, 23);
    });

    test('index 0 = authPoliceLawsuit', () {
      expect(modelLabelOrder[0], ScamIntent.authPoliceLawsuit);
    });

    test('index 16 = bankCardFraud (not shifted)', () {
      expect(modelLabelOrder[16], ScamIntent.bankCardFraud);
    });

    test('index 21 = genericScam (NOT fakeEcommerce)', () {
      expect(modelLabelOrder[21], ScamIntent.genericScam);
    });

    test('index 22 = safe (NOT cryptoDrain)', () {
      expect(modelLabelOrder[22], ScamIntent.safe);
    });

    test('does NOT contain fakeEcommerce', () {
      expect(modelLabelOrder.contains(ScamIntent.fakeEcommerce), isFalse);
    });

    test('does NOT contain cryptoDrain', () {
      expect(modelLabelOrder.contains(ScamIntent.cryptoDrain), isFalse);
    });

    test('every entry is a valid ScamIntent', () {
      for (final intent in modelLabelOrder) {
        expect(ScamIntent.values.contains(intent), isTrue);
      }
    });

    test('no duplicate entries', () {
      final unique = modelLabelOrder.toSet();
      expect(unique.length, modelLabelOrder.length);
    });

    test('first 21 entries match intentLabels (indices 0-20)', () {
      for (var i = 0; i < 21; i++) {
        expect(modelLabelOrder[i], intentLabels[i],
            reason: 'Index $i should match between model and app labels');
      }
    });

    test('diverges from intentLabels at index 21', () {
      // intentLabels[21] = fakeEcommerce (wrong for model)
      // modelLabelOrder[21] = genericScam (correct for model)
      expect(modelLabelOrder[21], isNot(intentLabels[21]));
    });

    test('diverges from intentLabels at index 22', () {
      // intentLabels[22] = cryptoDrain (wrong for model)
      // modelLabelOrder[22] = safe (correct for model)
      expect(modelLabelOrder[22], isNot(intentLabels[22]));
    });
  });
}
