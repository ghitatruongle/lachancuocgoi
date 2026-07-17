// Bug Hunt Phase B.1 — L1 edge cases audit
//
// Spec: docs/superpowers/specs/2026-06-28-bug-hunt-campaign-design.md
//       section "Mục 1 — 3 máy phân tích L1, L2, L3"
//
// Verifies L1 robustness against Unicode, empty, whitespace-only, emoji-adjacent,
// and very long inputs. BUG-L1-N identifiers are placeholders to be filled
// when a test fails and evidence is added to bugs-draft.md.

import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:lachancuocgoi_flutter/analysis/l1/l1_analysis.dart';
import 'package:lachancuocgoi_flutter/core/risk_level.dart';

void main() {
  // Minimal vocabulary with critical keywords to exercise matcher logic.
  final vocabJson = jsonEncode({
    'riskLevels': [
      {
        'level': 3,
        'threats': {'PII': ['mã otp']},
        'keywords': ['mã otp', 'công an'],
      },
    ],
  });

  L1Analyzer newL1() => L1Analyzer(
        vocabularyProvider: () => vocabJson,
        bigramCorrectionsProvider: () => '{"corrections":[]}',
      );

  group('BUG-HUNT-L1 — Unicode + boundary inputs', () {
    test(
      'BUG-L1-1: L1 must not throw on CCCD/phone-shaped Unicode input',
      () async {
        final l1 = newL1();
        await l1.initialize();
        const inputs = <String>[
          '079123456789', // 12 chữ số CCCD-like
          'CMND: 079 123 456 789',
          'Số CCCD: 079123456789 hôm nay',
          'mã OTP là 123456',
          'MÃ OTP LÀ 123456', // uppercase keyword
          'mã otp ', // trailing space
          ' mã otp', // leading space
          '   ', // whitespace only
          '', // empty
          '👋 mã otp 🎉', // emoji adjacent
          'mã\notp', // newline inside
        ];
        for (final input in inputs) {
          final result = await l1.analyzeStream(input);
          expect(
            result.analysisLevel.name,
            anyOf('l1', 'L1'),
            reason: 'analyzeStream returned invalid level for input "$input"',
          );
        }
      },
    );

    test(
      'BUG-L1-2: analyzeStream twice on same text should be idempotent',
      () async {
        final l1 = newL1();
        await l1.initialize();
        const text = 'Cho tôi mã OTP ngay.';
        final r1 = await l1.analyzeStream(text);
        final r2 = await l1.analyzeStream(text);
        // Re-analyzing same text after processedTextLength already covers
        // it should not accumulate duplicate matches.
        expect(r1.matches.length, equals(r2.matches.length));
        expect(r2.matches.length, lessThanOrEqualTo(r1.matches.length));
      },
    );

    test('BUG-L1-3: extremely long input (>5000 chars) does not OOM',
        () async {
      final l1 = newL1();
      await l1.initialize();
      final longText = 'xin chào ' * 1000; // ~9000 chars, no keyword
      final result = await l1.analyzeStream(longText);
      expect(result.overallRiskLevel, RiskLevel.green);
    });

    test(
      'BUG-L1-4: L1 keyword match across punctuation boundary',
      () async {
        final l1 = newL1();
        await l1.initialize();
        const text = 'Hãy cho tôi biết:mã otp ngay!';
        final result = await l1.analyzeStream(text);
        expect(result.matches, isNotEmpty,
            reason: 'L1 should detect "mã otp" even when surrounded by :!');
      },
    );
  });
}