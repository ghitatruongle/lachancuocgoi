// Bug Hunt Phase C.2 — Scenario corpus test from risk_scenarios_master.json

import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:lachancuocgoi_flutter/analysis/l1/l1_analysis.dart';

void main() {
  test(
    'BUG-CORPUS-1: every scenario from risk_scenarios_master.json analyzed by L1',
    () async {
      final file = File('assets/risk_scenarios_master.json');
      if (!file.existsSync()) {
        markTestSkipped('risk_scenarios_master.json not found');
        return;
      }
      final json = jsonDecode(file.readAsStringSync()) as Map<String, Object?>;
      final scenarios = json['scenarios'] as List<dynamic>?;
      expect(
        scenarios,
        isNotNull,
        reason: 'JSON must contain "scenarios" list',
      );

      final l1 = L1Analyzer(
        vocabularyProvider: () => jsonEncode({
          'riskLevels': [
            {
              'level': 3,
              'threats': {
                'PII': ['mã otp', 'OTP'],
              },
              'keywords': [
                'mã otp',
                'công an',
                'tài khoản',
                'chuyển tiền',
                'OTP',
              ],
            },
          ],
        }),
        bigramCorrectionsProvider: () => '{"corrections":[]}',
      );
      await l1.initialize();

      var scenariosAnalyzed = 0;
      for (final scenario in scenarios!) {
        if (scenario is! Map) continue;
        // Try feeding the description + name as transcript.
        final name = scenario['name'] as String? ?? '';
        final description = scenario['description'] as String? ?? '';
        final transcript = '$name. $description';
        if (transcript.trim().isEmpty) continue;
        try {
          await l1.analyzeStream(transcript);
          scenariosAnalyzed++;
        } on Object catch (e) {
          fail('L1 threw on scenario "${scenario['id']}": $e');
        }
      }
      expect(
        scenariosAnalyzed,
        greaterThan(50),
        reason: 'Should have analyzed a meaningful number of scenarios',
      );
    },
    timeout: const Timeout(Duration(seconds: 120)),
  );
}
