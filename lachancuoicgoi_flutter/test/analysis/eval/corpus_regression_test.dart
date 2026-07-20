import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lachancuocgoi_flutter/analysis/analysis_coordinator.dart';
import 'package:lachancuocgoi_flutter/analysis/analysis_mode.dart';
import 'package:lachancuocgoi_flutter/analysis/l1/l1_analysis.dart';
import 'package:lachancuocgoi_flutter/analysis/l2/g_detection/g_detection_engine.dart';
import 'package:lachancuocgoi_flutter/analysis/l2/intent/intent_classifier.dart';
import 'package:lachancuocgoi_flutter/analysis/l2/l2_analysis.dart';
import 'package:lachancuocgoi_flutter/analysis/l3/core/api_key_provider.dart';
import 'package:lachancuocgoi_flutter/analysis/l3/l3_analysis.dart';
import 'package:lachancuocgoi_flutter/services/flutter_services_impl.dart';

import 'eval_case.dart';
import 'eval_runner.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late DebugPrintCallback originalDebugPrint;

  setUpAll(() {
    originalDebugPrint = debugPrint;
    debugPrint = (message, {wrapWidth}) {};
  });

  tearDownAll(() {
    debugPrint = originalDebugPrint;
  });

  test('corpus_v2 real L1/L2 regression gate', () async {
    final corpusJson = await File(
      'test/fixtures/eval/corpus_v2_templates.json',
    ).readAsString();
    final cases = parseEvalTemplateCorpus(corpusJson);

    expect(cases, hasLength(greaterThanOrEqualTo(300)));
    expect(cases.where((item) => item.group == 'benign'), hasLength(120));
    expect(cases.where((item) => item.group == 'scam'), hasLength(120));
    expect(cases.where((item) => item.group == 'noisy_asr'), hasLength(60));

    const assetLoader = FlutterAssetLoader();
    final l1 = L1Analyzer(assetLoader: assetLoader);
    final gDetection = GDetectionEngine(assetLoader: assetLoader);
    final l2 = L2Analyzer(
      assetLoader: assetLoader,
      gDetectionEngine: gDetection,
      intentClassifier: const DisabledIntentClassifier(),
    );
    await Future.wait(<Future<void>>[l1.initialize(), l2.initialize()]);

    final coordinator = AnalysisCoordinator(
      l1Analyzer: l1,
      l2Analyzer: l2,
      l3Analyzer: L3Analyzer(
        apiKeyProvider: StaticApiKeyProvider(const <String>[]),
      ),
      networkAvailable: () => false,
    );

    final report = await const EvalRunner().run(
      cases: cases,
      mode: AnalysisMode.parallel,
      coordinator: coordinator,
    );

    // ignore: avoid_print
    print(report.toMarkdownTable());

    expect(report.precision, greaterThanOrEqualTo(0.90));
    expect(report.recall, greaterThanOrEqualTo(0.90));
    expect(report.falseRedRate, lessThanOrEqualTo(0.01));
    expect(report.criticalFalseGreen, 0);
  }, tags: ['eval']);
}
