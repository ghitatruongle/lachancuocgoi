// Bug Hunt Phase C.1 — Transcript fuzz test (500 L1 + 50 L3)
//
// Reference: docs/superpowers/specs/.../Phase C — Fuzz + scenario injection.

import 'dart:convert';
import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:lachancuocgoi_flutter/analysis/l1/l1_analysis.dart';
import 'package:lachancuocgoi_flutter/analysis/l3/core/api_key_provider.dart';
import 'package:lachancuocgoi_flutter/analysis/l3/l3_analysis.dart';

void main() {
  final rand = Random(20260629);

  String randomText(int maxLen) {
    const chars =
        'abcdefghijklmnopqrstuvwxyzáàảãạăắằẳẵặêếềểễệíìỉĩịóòỏõọôốồổỗộơớờởỡợúùủũụưứừửữựýỳỷỹỵđĐ '
        '0123456789 ,.!?;-\n\tOTP: mã công an tài khoản 👋🎉';
    final len = rand.nextInt(maxLen) + 1;
    return List.generate(len, (_) => chars[rand.nextInt(chars.length)]).join();
  }

  group('BUG-HUNT-FUZZ — Transcript fuzzing', () {
    test(
      'BUG-FUZZ-1: L1 must not throw on 200 random transcripts',
      () async {
        final l1 = L1Analyzer(
          vocabularyProvider: () => jsonEncode({
            'riskLevels': [
              {
                'level': 3,
                'threats': {
                  'PII': ['mã otp'],
                },
                'keywords': ['mã otp', 'công an'],
              },
            ],
          }),
          bigramCorrectionsProvider: () => '{"corrections":[]}',
        );
        await l1.initialize();
        for (var i = 0; i < 200; i++) {
          try {
            await l1.analyzeStream(randomText(500));
          } on Object catch (e) {
            fail('L1 threw at iteration $i on random input: $e');
          }
        }
      },
      timeout: const Timeout(Duration(seconds: 60)),
    );

    test(
      'BUG-FUZZ-2: L3 with no key must not crash on 50 random transcripts',
      () async {
        final l3 = L3Analyzer(
          apiKeyProvider: StaticApiKeyProvider(const <String>[]),
        );
        for (var i = 0; i < 50; i++) {
          try {
            await l3.analyzeIncremental(randomText(200));
          } on Object catch (e) {
            fail('L3 threw at iteration $i: $e');
          }
        }
      },
      timeout: const Timeout(Duration(seconds: 30)),
    );

    test(
      'BUG-FUZZ-3: L1 with very long random transcript (5000 chars)',
      () async {
        final l1 = L1Analyzer(
          vocabularyProvider: () => jsonEncode({
            'riskLevels': [
              {
                'level': 3,
                'threats': {
                  'PII': ['mã otp'],
                },
                'keywords': ['mã otp'],
              },
            ],
          }),
          bigramCorrectionsProvider: () => '{"corrections":[]}',
        );
        await l1.initialize();
        // 10 iterations of long text — no OOM.
        for (var i = 0; i < 10; i++) {
          try {
            await l1.analyzeStream(randomText(5000));
          } on Object catch (e) {
            fail('L1 threw on long random transcript iteration $i: $e');
          }
        }
      },
      timeout: const Timeout(Duration(seconds: 60)),
    );
  });
}
