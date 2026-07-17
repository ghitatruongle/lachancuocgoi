import 'package:flutter_test/flutter_test.dart';
import 'package:lachancuocgoi_flutter/analysis/l3/core/gemini_response.dart';

void main() {
  group('AnalysisResponse.fromJson', () {
    test('parses all fields from complete JSON', () {
      final json = <String, Object?>{
        'level': 'RED',
        'label': 'Lừa đảo ngân hàng',
        'reason': 'Phát hiện yêu cầu OTP',
        'recommendation': 'Cúp máy ngay lập tức',
      };

      final response = AnalysisResponse.fromJson(json);

      expect(response.level, 'RED');
      expect(response.label, 'Lừa đảo ngân hàng');
      expect(response.reason, 'Phát hiện yêu cầu OTP');
      expect(response.recommendation, 'Cúp máy ngay lập tức');
    });

    test('parses JSON with missing level', () {
      final json = <String, Object?>{
        'label': 'Test label',
        'reason': 'Test reason',
        'recommendation': 'Test rec',
      };

      final response = AnalysisResponse.fromJson(json);

      expect(response.level, isNull);
      expect(response.label, 'Test label');
      expect(response.reason, 'Test reason');
      expect(response.recommendation, 'Test rec');
    });

    test('parses JSON with missing label', () {
      final json = <String, Object?>{
        'level': 'YELLOW',
        'reason': 'reason',
        'recommendation': 'rec',
      };

      final response = AnalysisResponse.fromJson(json);

      expect(response.level, 'YELLOW');
      expect(response.label, isNull);
    });

    test('parses JSON with missing reason', () {
      final json = <String, Object?>{
        'level': 'GREEN',
        'label': 'label',
        'recommendation': 'rec',
      };

      final response = AnalysisResponse.fromJson(json);

      expect(response.reason, isNull);
    });

    test('parses JSON with missing recommendation', () {
      final json = <String, Object?>{
        'level': 'ORANGE',
        'label': 'label',
        'reason': 'reason',
      };

      final response = AnalysisResponse.fromJson(json);

      expect(response.recommendation, isNull);
    });

    test('parses empty JSON with all null fields', () {
      final json = <String, Object?>{};

      final response = AnalysisResponse.fromJson(json);

      expect(response.level, isNull);
      expect(response.label, isNull);
      expect(response.reason, isNull);
      expect(response.recommendation, isNull);
    });

    test('parses JSON with null values for all fields', () {
      final json = <String, Object?>{
        'level': null,
        'label': null,
        'reason': null,
        'recommendation': null,
      };

      final response = AnalysisResponse.fromJson(json);

      expect(response.level, isNull);
      expect(response.label, isNull);
      expect(response.reason, isNull);
      expect(response.recommendation, isNull);
    });

    test('parses JSON with empty string values', () {
      final json = <String, Object?>{
        'level': '',
        'label': '',
        'reason': '',
        'recommendation': '',
      };

      final response = AnalysisResponse.fromJson(json);

      expect(response.level, '');
      expect(response.label, '');
      expect(response.reason, '');
      expect(response.recommendation, '');
    });

    test('ignores extra fields in JSON', () {
      final json = <String, Object?>{
        'level': 'RED',
        'label': 'test',
        'reason': 'test',
        'recommendation': 'test',
        'extraField': 'should be ignored',
        'anotherExtra': 42,
      };

      final response = AnalysisResponse.fromJson(json);

      expect(response.level, 'RED');
      expect(response.label, 'test');
    });

    test('handles Vietnamese characters in all fields', () {
      final json = <String, Object?>{
        'level': 'RED',
        'label': 'Nguy hiểm: Giả danh công an',
        'reason': 'Đối tượng yêu cầu cung cấp mã OTP ngân hàng',
        'recommendation': 'Hãy cúp máy và gọi công an gần nhất',
      };

      final response = AnalysisResponse.fromJson(json);

      expect(response.label, contains('Nguy hiểm'));
      expect(response.reason, contains('OTP'));
      expect(response.recommendation, contains('cúp máy'));
    });
  });

  group('AnalysisResponse constructor', () {
    test('constructs with all parameters', () {
      const response = AnalysisResponse(
        level: 'RED',
        label: 'Danger',
        reason: 'OTP detected',
        recommendation: 'Hang up',
      );

      expect(response.level, 'RED');
      expect(response.label, 'Danger');
      expect(response.reason, 'OTP detected');
      expect(response.recommendation, 'Hang up');
    });

    test('constructs with no parameters (all null)', () {
      const response = AnalysisResponse();

      expect(response.level, isNull);
      expect(response.label, isNull);
      expect(response.reason, isNull);
      expect(response.recommendation, isNull);
    });

    test('constructs with partial parameters', () {
      const response = AnalysisResponse(
        level: 'YELLOW',
        reason: 'Suspicious pattern',
      );

      expect(response.level, 'YELLOW');
      expect(response.label, isNull);
      expect(response.reason, 'Suspicious pattern');
      expect(response.recommendation, isNull);
    });
  });

  group('AnalysisResponse const', () {
    test('const constructor allows compile-time constants', () {
      const response = AnalysisResponse(level: 'GREEN');
      // Verify it can be used as a compile-time constant
      expect(
        identical(response, const AnalysisResponse(level: 'GREEN')),
        isTrue,
      );
    });
  });
}
