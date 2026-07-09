import 'package:flutter_test/flutter_test.dart';
import 'package:lachancuocgoi_flutter/core/risk_level.dart';

void main() {
  group('RiskLevel', () {
    test('properties map correctly for each level', () {
      expect(RiskLevel.green.vietnameseName, 'An toàn');
      expect(RiskLevel.green.colorValue, 0xFF4CAF50);
      expect(RiskLevel.green.level, 0);
      expect(RiskLevel.green.storageName, 'GREEN');
      expect(RiskLevel.green.shouldAlert, isFalse);

      expect(RiskLevel.yellow.vietnameseName, 'Chú ý');
      expect(RiskLevel.yellow.colorValue, 0xFFFFEB3B);
      expect(RiskLevel.yellow.level, 1);
      expect(RiskLevel.yellow.storageName, 'YELLOW');
      expect(RiskLevel.yellow.shouldAlert, isFalse);

      expect(RiskLevel.orange.vietnameseName, 'Nguy cơ');
      expect(RiskLevel.orange.colorValue, 0xFFFFA500);
      expect(RiskLevel.orange.level, 2);
      expect(RiskLevel.orange.storageName, 'ORANGE');
      expect(RiskLevel.orange.shouldAlert, isTrue);

      expect(RiskLevel.red.vietnameseName, 'Nguy hiểm');
      expect(RiskLevel.red.colorValue, 0xFFF44336);
      expect(RiskLevel.red.level, 3);
      expect(RiskLevel.red.storageName, 'RED');
      expect(RiskLevel.red.shouldAlert, isTrue);
    });

    test('deescalate lowers risk level step-by-step', () {
      expect(RiskLevel.red.deescalate(), RiskLevel.orange);
      expect(RiskLevel.orange.deescalate(), RiskLevel.yellow);
      expect(RiskLevel.yellow.deescalate(), RiskLevel.green);
      expect(RiskLevel.green.deescalate(), RiskLevel.green);
    });

    test('fromInt parses integer risk values', () {
      expect(RiskLevel.fromInt(3), RiskLevel.red);
      expect(RiskLevel.fromInt(2), RiskLevel.orange);
      expect(RiskLevel.fromInt(1), RiskLevel.yellow);
      expect(RiskLevel.fromInt(0), RiskLevel.green);
      expect(RiskLevel.fromInt(-1), RiskLevel.green);
      expect(RiskLevel.fromInt(99), RiskLevel.green);
    });

    test('fromString parses normal and variant strings', () {
      // Null and empty defaults to green
      expect(RiskLevel.fromString(null), RiskLevel.green);
      expect(RiskLevel.fromString(''), RiskLevel.green);
      expect(RiskLevel.fromString('   '), RiskLevel.green);

      // Standard English names
      expect(RiskLevel.fromString('red'), RiskLevel.red);
      expect(RiskLevel.fromString('RED'), RiskLevel.red);
      expect(RiskLevel.fromString('orange'), RiskLevel.orange);
      expect(RiskLevel.fromString('ORANGE'), RiskLevel.orange);
      expect(RiskLevel.fromString('yellow'), RiskLevel.yellow);
      expect(RiskLevel.fromString('YELLOW'), RiskLevel.yellow);
      expect(RiskLevel.fromString('green'), RiskLevel.green);
      expect(RiskLevel.fromString('GREEN'), RiskLevel.green);

      // Vietnamese names with accents
      expect(RiskLevel.fromString('Nguy hiểm'), RiskLevel.red);
      expect(RiskLevel.fromString('NGUY HIỂM'), RiskLevel.red);
      expect(RiskLevel.fromString('Nguy cơ'), RiskLevel.orange);
      expect(RiskLevel.fromString('Có nguy cơ'), RiskLevel.orange);
      expect(RiskLevel.fromString('Chú ý'), RiskLevel.yellow);
      expect(RiskLevel.fromString('An toàn'), RiskLevel.green);

      // Vietnamese names without accents
      expect(RiskLevel.fromString('NGUY HIEM'), RiskLevel.red);
      expect(RiskLevel.fromString('nguy co'), RiskLevel.orange);
      expect(RiskLevel.fromString('co nguy co'), RiskLevel.orange);
      expect(RiskLevel.fromString('chu y'), RiskLevel.yellow);
      expect(RiskLevel.fromString('an toan'), RiskLevel.green);
    });

    test('fromString fallback with unknown input returns orange', () {
      expect(RiskLevel.fromString('unknown_val'), RiskLevel.orange);
      expect(RiskLevel.fromString('SCAM'), RiskLevel.orange);
    });
  });
}
