import 'package:flutter_test/flutter_test.dart';
import 'package:lachancuocgoi_flutter/analysis/l2/intent/scam_intent.dart';

const modelLabelOrder = <ScamIntent>[
  ScamIntent.authPoliceLawsuit,
  ScamIntent.taxGovApp,
  ScamIntent.telecomLock,
  ScamIntent.techSupportHijack,
  ScamIntent.hospitalEmergency,
  ScamIntent.virtualKidnapping,
  ScamIntent.ceoFraudB2b,
  ScamIntent.socialDeepfakeLoan,
  ScamIntent.romanceScam,
  ScamIntent.sextortionBlackmail,
  ScamIntent.charityDonation,
  ScamIntent.investmentScam,
  ScamIntent.jobTaskScam,
  ScamIntent.giftLottery,
  ScamIntent.gamblingPrediction,
  ScamIntent.immigrationVisaScam,
  ScamIntent.bankCardFraud,
  ScamIntent.deliveryCod,
  ScamIntent.fakeSubscription,
  ScamIntent.blackCreditTerror,
  ScamIntent.recoveryScam,
  ScamIntent.genericScam,
  ScamIntent.safe,
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
        expect(
          modelLabelOrder[i],
          intentLabels[i],
          reason: 'Index $i should match between model and app labels',
        );
      }
    });

    test('diverges from intentLabels at index 21', () {
      expect(modelLabelOrder[21], isNot(intentLabels[21]));
    });

    test('diverges from intentLabels at index 22', () {
      expect(modelLabelOrder[22], isNot(intentLabels[22]));
    });
  });
}
