import 'package:flutter_test/flutter_test.dart';
import 'package:lachancuocgoi_flutter/analysis/l2/intent/scam_intent.dart';
import 'package:lachancuocgoi_flutter/core/risk_level.dart';

void main() {
  group('ScamIntent enum — all 25 intents are defined', () {
    test('ScamIntent.values has 25 entries', () {
      expect(ScamIntent.values.length, 25);
    });

    test('all 25 intents are present in ScamIntent.values', () {
      const expectedIntents = <ScamIntent>[
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
        ScamIntent.fakeEcommerce,
        ScamIntent.cryptoDrain,
        ScamIntent.genericScam,
        ScamIntent.safe,
      ];
      expect(ScamIntent.values, expectedIntents);
    });

    test('intentLabels list has 25 entries matching ScamIntent.values', () {
      expect(intentLabels.length, 25);
      expect(intentLabels, ScamIntent.values);
    });
  });

  group('displayName', () {
    test('returns non-empty string for every intent', () {
      for (final intent in ScamIntent.values) {
        expect(
          intent.displayName,
          isNotEmpty,
          reason: 'displayName of ${intent.name} must not be empty',
        );
      }
    });

    test('safe intent has correct displayName', () {
      expect(ScamIntent.safe.displayName, 'Giao tiếp bình thường');
    });

    test('authPoliceLawsuit has correct displayName', () {
      expect(
        ScamIntent.authPoliceLawsuit.displayName,
        'Giả danh Công an/Tòa án',
      );
    });

    test('each intent has a unique displayName', () {
      final names = ScamIntent.values.map((i) => i.displayName).toList();
      final uniqueNames = names.toSet();
      expect(
        uniqueNames.length,
        names.length,
        reason: 'All displayNames must be unique',
      );
    });
  });

  group('description', () {
    test('returns non-empty string for every intent', () {
      for (final intent in ScamIntent.values) {
        expect(
          intent.description,
          isNotEmpty,
          reason: 'description of ${intent.name} must not be empty',
        );
      }
    });

    test('each intent has a unique description', () {
      final descs = ScamIntent.values.map((i) => i.description).toList();
      final uniqueDescs = descs.toSet();
      expect(
        uniqueDescs.length,
        descs.length,
        reason: 'All descriptions must be unique',
      );
    });
  });

  group('baseRiskLevel', () {
    test('safe intent returns RiskLevel.green', () {
      expect(ScamIntent.safe.baseRiskLevel, RiskLevel.green);
    });

    test('yellow-tier intents return RiskLevel.yellow', () {
      const yellowIntents = <ScamIntent>[
        ScamIntent.charityDonation,
        ScamIntent.giftLottery,
        ScamIntent.fakeSubscription,
        ScamIntent.genericScam,
      ];
      for (final intent in yellowIntents) {
        expect(
          intent.baseRiskLevel,
          RiskLevel.yellow,
          reason: '${intent.name} should be yellow',
        );
      }
    });

    test('orange-tier intents return RiskLevel.orange', () {
      const orangeIntents = <ScamIntent>[
        ScamIntent.investmentScam,
        ScamIntent.jobTaskScam,
        ScamIntent.romanceScam,
        ScamIntent.immigrationVisaScam,
        ScamIntent.deliveryCod,
        ScamIntent.recoveryScam,
        ScamIntent.gamblingPrediction,
        ScamIntent.ceoFraudB2b,
        ScamIntent.socialDeepfakeLoan,
        ScamIntent.fakeEcommerce,
        ScamIntent.cryptoDrain,
      ];
      for (final intent in orangeIntents) {
        expect(
          intent.baseRiskLevel,
          RiskLevel.orange,
          reason: '${intent.name} should be orange',
        );
      }
    });

    test('red-tier intents return RiskLevel.red', () {
      const redIntents = <ScamIntent>[
        ScamIntent.authPoliceLawsuit,
        ScamIntent.taxGovApp,
        ScamIntent.telecomLock,
        ScamIntent.techSupportHijack,
        ScamIntent.hospitalEmergency,
        ScamIntent.virtualKidnapping,
        ScamIntent.sextortionBlackmail,
        ScamIntent.bankCardFraud,
        ScamIntent.blackCreditTerror,
      ];
      for (final intent in redIntents) {
        expect(
          intent.baseRiskLevel,
          RiskLevel.red,
          reason: '${intent.name} should be red',
        );
      }
    });

    test('every intent has a valid baseRiskLevel', () {
      for (final intent in ScamIntent.values) {
        expect(intent.baseRiskLevel, isA<RiskLevel>());
      }
    });
  });

  group('riskLevelForConfidence', () {
    group('safe intent', () {
      test('always returns green regardless of confidence', () {
        expect(ScamIntent.safe.riskLevelForConfidence(1.0), RiskLevel.green);
        expect(ScamIntent.safe.riskLevelForConfidence(0.9), RiskLevel.green);
        expect(ScamIntent.safe.riskLevelForConfidence(0.7), RiskLevel.green);
        expect(ScamIntent.safe.riskLevelForConfidence(0.5), RiskLevel.green);
        expect(ScamIntent.safe.riskLevelForConfidence(0.3), RiskLevel.green);
        expect(ScamIntent.safe.riskLevelForConfidence(0.0), RiskLevel.green);
      });
    });

    group('high confidence (>= 0.85)', () {
      test('returns base risk level', () {
        // Red intent with high confidence → red
        expect(
          ScamIntent.authPoliceLawsuit.riskLevelForConfidence(0.85),
          RiskLevel.red,
        );
        expect(
          ScamIntent.authPoliceLawsuit.riskLevelForConfidence(0.95),
          RiskLevel.red,
        );

        // Orange intent with high confidence → orange
        expect(
          ScamIntent.investmentScam.riskLevelForConfidence(0.90),
          RiskLevel.orange,
        );

        // Yellow intent with high confidence → yellow
        expect(
          ScamIntent.charityDonation.riskLevelForConfidence(0.85),
          RiskLevel.yellow,
        );
      });
    });

    group('medium-high confidence (>= 0.70 and < 0.85)', () {
      test('returns base risk level (no de-escalation)', () {
        // Red intent at 0.75 confidence → still red
        expect(
          ScamIntent.authPoliceLawsuit.riskLevelForConfidence(0.75),
          RiskLevel.red,
        );

        // Orange intent at 0.70 confidence → still orange
        expect(
          ScamIntent.investmentScam.riskLevelForConfidence(0.70),
          RiskLevel.orange,
        );

        // Yellow intent at 0.70 confidence → still yellow
        expect(
          ScamIntent.charityDonation.riskLevelForConfidence(0.70),
          RiskLevel.yellow,
        );
      });
    });

    group('medium confidence (>= 0.50 and < 0.70)', () {
      test('de-escalates once from base risk level', () {
        // Red → orange
        expect(
          ScamIntent.authPoliceLawsuit.riskLevelForConfidence(0.50),
          RiskLevel.orange,
        );
        expect(
          ScamIntent.authPoliceLawsuit.riskLevelForConfidence(0.60),
          RiskLevel.orange,
        );

        // Orange → yellow
        expect(
          ScamIntent.investmentScam.riskLevelForConfidence(0.50),
          RiskLevel.yellow,
        );

        // Yellow → green
        expect(
          ScamIntent.charityDonation.riskLevelForConfidence(0.55),
          RiskLevel.green,
        );
      });
    });

    group('low confidence (< 0.50)', () {
      test('de-escalates twice from base risk level, minimum yellow', () {
        // Red → orange → yellow (twice de-escalated, clamped at yellow)
        expect(
          ScamIntent.authPoliceLawsuit.riskLevelForConfidence(0.30),
          RiskLevel.yellow,
        );

        // Orange → yellow → green, but green.index < yellow.index
        // so it clamps to yellow
        expect(
          ScamIntent.investmentScam.riskLevelForConfidence(0.30),
          RiskLevel.yellow,
        );

        // Yellow → green → green, but green.index < yellow.index
        // so it clamps to yellow
        expect(
          ScamIntent.charityDonation.riskLevelForConfidence(0.30),
          RiskLevel.yellow,
        );
      });

      test('returns at least yellow for any non-safe intent', () {
        // Test every non-safe intent at 0.0 confidence.
        for (final intent in ScamIntent.values) {
          if (intent == ScamIntent.safe) continue;
          final level = intent.riskLevelForConfidence(0.0);
          expect(
            level.index,
            greaterThanOrEqualTo(RiskLevel.yellow.index),
            reason:
                '${intent.name} at 0.0 confidence should be at least yellow',
          );
        }
      });
    });

    group('boundary values', () {
      test('confidence exactly 0.85 returns base level', () {
        expect(
          ScamIntent.authPoliceLawsuit.riskLevelForConfidence(0.85),
          RiskLevel.red,
        );
      });

      test('confidence 0.849 returns base level (>= 0.70 branch)', () {
        expect(
          ScamIntent.authPoliceLawsuit.riskLevelForConfidence(0.849),
          RiskLevel.red,
        );
      });

      test('confidence exactly 0.70 returns base level', () {
        expect(
          ScamIntent.investmentScam.riskLevelForConfidence(0.70),
          RiskLevel.orange,
        );
      });

      test('confidence exactly 0.50 triggers single de-escalation', () {
        expect(
          ScamIntent.authPoliceLawsuit.riskLevelForConfidence(0.50),
          RiskLevel.orange,
        );
      });

      test('confidence 0.499 triggers double de-escalation', () {
        expect(
          ScamIntent.authPoliceLawsuit.riskLevelForConfidence(0.499),
          RiskLevel.yellow,
        );
      });
    });
  });

  group('IntentPrediction', () {
    test('stores intent and confidence', () {
      const prediction = IntentPrediction(
        intent: ScamIntent.authPoliceLawsuit,
        confidence: 0.95,
      );
      expect(prediction.intent, ScamIntent.authPoliceLawsuit);
      expect(prediction.confidence, 0.95);
    });

    test('works with safe intent', () {
      const prediction = IntentPrediction(
        intent: ScamIntent.safe,
        confidence: 1.0,
      );
      expect(prediction.intent, ScamIntent.safe);
      expect(prediction.confidence, 1.0);
    });
  });
}
