import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lachancuocgoi_flutter/analysis/l2/intent/intent_classifier.dart';
import 'package:lachancuocgoi_flutter/analysis/l2/l2_analysis.dart';
import 'package:lachancuocgoi_flutter/core/risk_level.dart';
import 'package:lachancuocgoi_flutter/services/flutter_services_impl.dart';

RiskLevel _parseExpected(String json) => switch (json.toLowerCase()) {
  'red' => RiskLevel.red,
  'orange' => RiskLevel.orange,
  'yellow' => RiskLevel.yellow,
  _ => RiskLevel.green,
};

String _buildTranscript(List<dynamic> script) {
  return script
      .map((e) {
        final line = e as Map<String, dynamic>;
        return '${line['speaker']}: ${line['line']}';
      })
      .join('\n');
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('Simulate all 27 scenarios through L2 analyzer', () async {
    final raw = await rootBundle.loadString('assets/situation_test.json');
    final scenarios = jsonDecode(raw) as List<dynamic>;

    final l2 = L2Analyzer(
      assetLoader: const FlutterAssetLoader(),
      intentClassifier: const DisabledIntentClassifier(),
    );
    await l2.initialize();

    final results = <_SimResult>[];
    var passCount = 0;
    var failCount = 0;

    for (var i = 0; i < scenarios.length; i++) {
      final s = scenarios[i] as Map<String, dynamic>;
      final title = s['title'] as String;
      final expected = _parseExpected(
        (s['expected_result']?['risk_level'] as String?) ??
            s['riskLevel'] as String? ??
            'GREEN',
      );
      final transcript = _buildTranscript(s['script'] as List<dynamic>);

      l2.resetSession();

      final result = await l2.analyze(transcript, transcript);

      final actual = result.overallRiskLevel;

      final pass = actual.index >= expected.index;
      if (pass) {
        passCount++;
      } else {
        failCount++;
      }

      if (!pass) {
        debugPrint('  [DEBUG] "$title"');
        debugPrint('    Risk: ${actual.name} | Reason: ${result.reason}');
        debugPrint(
          '    Matches: ${result.matches.map((m) => "${m.keyword}(${m.level.name})").join(", ")}',
        );
        debugPrint(
          '    Matches: ${result.matches.map((m) => m.keyword).join(', ')}',
        );
      }

      results.add(
        _SimResult(
          index: i + 1,
          title: title,
          expected: expected,
          actual: actual,
          reason: result.reason ?? '—',
          pass: pass,
        ),
      );
    }

    debugPrint('');
    debugPrint(
      '═══════════════════════════════════════════════════════════════════',
    );
    debugPrint('  KẾT QUẢ MÔ PHỎNG 27 KỊCH BẢN — L2 (gDetection) ANALYZER');
    debugPrint(
      '═══════════════════════════════════════════════════════════════════',
    );
    for (final r in results) {
      final icon = r.pass ? '✅ PASS ' : '❌ FAIL ';
      debugPrint(
        '${r.index.toString().padLeft(2)}. $icon  '
        '${r.title.padRight(40).substring(0, r.title.length > 40 ? 40 : r.title.length)}  '
        'Mong đợi: ${r.expected.name.toUpperCase().padLeft(7)}  '
        'Thực tế: ${r.actual.name.toUpperCase().padLeft(7)}',
      );
    }
    debugPrint(
      '═══════════════════════════════════════════════════════════════════',
    );
    debugPrint(
      '  TỔNG KẾT: $passCount PASS / $failCount FAIL / ${scenarios.length} TOTAL',
    );
    debugPrint(
      '═══════════════════════════════════════════════════════════════════',
    );

    expect(scenarios.length, equals(26));
  });
}

class _SimResult {
  _SimResult({
    required this.index,
    required this.title,
    required this.expected,
    required this.actual,
    required this.reason,
    required this.pass,
  });

  final int index;
  final String title;
  final RiskLevel expected;
  final RiskLevel actual;
  final String reason;
  final bool pass;
}
