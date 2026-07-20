// Bug Hunt Phase B.4 — UI RiskLevel color consistency
//
// Reference: docs/superpowers/specs/.../Mục 5 — UI/UX

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lachancuocgoi_flutter/core/risk_level.dart';
import 'package:lachancuocgoi_flutter/ui/theme/risk_level_colors.dart';

void main() {
  group('BUG-HUNT-UI — RiskLevel color consistency', () {
    test('BUG-UI-1: every RiskLevel resolves to non-transparent Color', () {
      for (final level in RiskLevel.values) {
        final c = level.color;
        // Color.value is deprecated in newer Flutter; use toARGB32().
        final alpha = (c.a * 255.0).round().clamp(0, 255);
        expect(
          alpha,
          greaterThan(0),
          reason: '${level.name} produced alpha=0 (transparent)',
        );
        expect(c, isA<Color>());
      }
    });

    test('BUG-UI-2: red/orange/yellow/green have distinct ARGB values', () {
      final palette = <RiskLevel, Color>{
        for (final l in RiskLevel.values) l: l.color,
      };
      final seen = <int>{};
      for (final entry in palette.entries) {
        final argb = entry.value.toARGB32();
        expect(
          seen.contains(argb),
          isFalse,
          reason:
              '${entry.key.name} shares color with another level: 0x${argb.toRadixString(16)}',
        );
        seen.add(argb);
      }
    });

    test(
      'BUG-UI-3: RiskLevel.fromString maps unknown values to ORANGE (conservative)',
      () {
        expect(
          RiskLevel.fromString('totally-unknown-value'),
          RiskLevel.orange,
          reason:
              'Conservative default for unrecognized risk string should be orange',
        );
        expect(RiskLevel.fromString(null), RiskLevel.green);
        expect(RiskLevel.fromString(''), RiskLevel.green);
      },
    );
  });
}
