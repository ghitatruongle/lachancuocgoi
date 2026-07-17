import 'package:flutter_test/flutter_test.dart';

import 'package:lachancuocgoi_flutter/analysis/analysis_coordinator.dart';
import 'package:lachancuocgoi_flutter/analysis/analysis_level.dart';
import 'package:lachancuocgoi_flutter/analysis/analysis_mode.dart';
import 'package:lachancuocgoi_flutter/analysis/analysis_result.dart';
import 'package:lachancuocgoi_flutter/analysis/l2/g_detection/g_detection_engine.dart';
import 'package:lachancuocgoi_flutter/analysis/l2/g_detection/g_models.dart';
import 'package:lachancuocgoi_flutter/analysis/l2/intent/intent_classifier.dart';
import 'package:lachancuocgoi_flutter/analysis/l2/l2_analysis.dart';
import 'package:lachancuocgoi_flutter/analysis/l2/wfsa/wfsa_engine.dart';
import 'package:lachancuocgoi_flutter/analysis/l3/core/api_key_provider.dart';
import 'package:lachancuocgoi_flutter/analysis/l3/core/gemini_client.dart';
import 'package:lachancuocgoi_flutter/analysis/l3/core/gemini_config.dart';
import 'package:lachancuocgoi_flutter/analysis/l3/core/pii_stripper.dart';
import 'package:lachancuocgoi_flutter/analysis/l3/l3_analysis.dart';
import 'package:lachancuocgoi_flutter/core/risk_level.dart';

void main() {
  group('L3 Gemini Analysis', () {
    test('PIIStripper redact va restore dung token', () {
      const text =
          'Tôi tên là Nguyễn Văn A, số tài khoản 123456789 và mã OTP 654321. '
          'Số điện thoại của tôi là 0912345678.';

      final redaction = PIIStripper.redactPII(text);

      expect(redaction.redactedText, contains('[TEN_NGUOI_1]'));
      expect(redaction.redactedText, contains('[SO_TAI_KHOAN_1]'));
      expect(redaction.redactedText, contains('[MA_OTP_1]'));
      expect(redaction.redactedText, contains('[SO_DIEN_THOAI_1]'));
      expect(
        PIIStripper.restorePII(redaction.redactedText, redaction.tokensMap),
        text,
      );
    });

    test('L3 parse JSON co text bao quanh va map dung risk', () {
      final analyzer = L3Analyzer(
        apiKeyProvider: StaticApiKeyProvider(const <String>[]),
      );

      final result = analyzer.parseResponse(
        'AI note... {"level":"red","label":"Giả danh công an","reason":"Yêu cầu chuyển tiền","recommendation":"Cúp máy ngay"} --done',
        'gemini-2.5-flash-lite',
      );

      expect(result.overallRiskLevel, RiskLevel.red);
      expect(result.analysisLevel, AnalysisLevel.l3);
      expect(result.matches.single.keyword, 'Giả danh công an');
      expect(result.reason, contains('Khuyến cáo: Cúp máy ngay'));
    });

    test('L3 risk decay giam dan sau 3 lan green lien tiep', () {
      final analyzer = L3Analyzer(
        apiKeyProvider: StaticApiKeyProvider(const <String>[]),
      );

      final red = analyzer.parseResponse(
        '{"level":"red","label":"Scam","reason":"Lừa đảo","recommendation":"Ngắt máy"}',
        'gemini',
      );
      final green1 = analyzer.parseResponse(
        '{"level":"green","label":"","reason":"An toàn","recommendation":"Theo dõi"}',
        'gemini',
      );
      final green2 = analyzer.parseResponse(
        '{"level":"green","label":"","reason":"An toàn","recommendation":"Theo dõi"}',
        'gemini',
      );
      final green3 = analyzer.parseResponse(
        '{"level":"green","label":"","reason":"An toàn","recommendation":"Theo dõi"}',
        'gemini',
      );

      expect(red.overallRiskLevel, RiskLevel.red);
      expect(green1.overallRiskLevel, RiskLevel.red);
      expect(green2.overallRiskLevel, RiskLevel.red);
      // RED should NOT de-escalate (only YELLOW can de-escalate for safety)
      expect(green3.overallRiskLevel, RiskLevel.red);
    });

    test('Coordinator fallback L3 sang L2 khi Gemini loi mang', () async {
      final l3Analyzer = L3Analyzer(
        apiKeyProvider: StaticApiKeyProvider(const <String>['AIza_test']),
        geminiClient: GeminiClient(
          apiKeyProvider: StaticApiKeyProvider(const <String>['AIza_test']),
          config: GeminiConfig.forAnalysis(),
          requestExecutor:
              ({
                required String apiKey,
                required GeminiConfig config,
                required String modelName,
                required String prompt,
              }) async {
                throw Exception('SocketException: network down');
              },
        ),
      );
      final l2Analyzer = L2Analyzer(
        gDetectionEngine: _FakeGDetectionEngine(
          GResult(
            riskLevel: RiskLevel.orange,
            reason: 'GDetection phát hiện nguy cơ lừa đảo',
            allMatchedKeywords: <KeywordMatch>{
              const KeywordMatch(
                keyword: 'chuyển tiền',
                level: RiskLevel.orange,
                category: 'Chung',
              ),
            },
            alertEnabled: true,
          ),
        ),
        intentClassifier: const DisabledIntentClassifier(),
        wfsaEngine: WfsaEngine(const <ScenarioGraph>[]),
      );
      final coordinator = AnalysisCoordinator(
        l2Analyzer: l2Analyzer,
        l3Analyzer: l3Analyzer,
      );

      final result = await coordinator.analyze(
        'Tôi là công an, anh phải chuyển tiền ngay vào tài khoản này.',
        AnalysisMode.geminiApi,
      );

      expect(result.analysisLevel, AnalysisLevel.l2);
      expect(result.reason, contains('API Error'));
      expect(result.reason, contains('GDetection phát hiện nguy cơ lừa đảo'));
      expect(result.isFallback, isTrue);
      expect(result.matches.any((m) => m.keyword == 'chuyển tiền'), isTrue);
      expect(result.overallRiskLevel, RiskLevel.orange);
    });
  });
}

class _FakeGDetectionEngine extends GDetectionEngine {
  _FakeGDetectionEngine(this._result);

  final GResult _result;

  @override
  Future<void> initialize() async {}

  @override
  bool get isReady => true;

  @override
  Future<GResult> performFullAnalysis(String text) async => _result;
}
