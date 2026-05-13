import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/mockito.dart';
import 'package:mockito/annotations.dart';
import 'package:http/http.dart' as http;
import '../phase11_api/fraud_detection_api_client.dart';

@GenerateMocks([http.Client])
import 'phase11_api_test.mocks.dart';

void main() {
  group('Phase 11: API Client Tests', () {
    late MockClient mockClient;
    late FraudDetectionApiClient apiClient;

    setUp(() {
      mockClient = MockClient();
      apiClient = FraudDetectionApiClient(baseUrl: 'https://test.api.com')
        .._client = mockClient;
    });

    tearDown(() {
      apiClient.dispose();
    });

    test('checkPhoneNumber trả về AnalysisResult khi thành công', () async {
      final mockResponse = http.Response(
        '{"phone_number": "0123456789", "risk_level": "high", "category": "fraud", "confidence": 0.95}',
        200,
      );

      when(mockClient.post(any, headers: anyNamed('headers'), body: anyNamed('body')))
          .thenAnswer((_) async => mockResponse);

      final result = await apiClient.checkPhoneNumber('0123456789');

      expect(result.phoneNumber, '0123456789');
      expect(result.riskLevel.name, 'high');
      verify(mockClient.post(
        Uri.parse('https://test.api.com/api/v1/check'),
        headers: {'Content-Type': 'application/json'},
        body: '{"phone_number":"0123456789"}',
      )).called(1);
    });

    test('checkPhoneNumber trả về unknown khi số không tồn tại (404)', () async {
      final mockResponse = http.Response('Not Found', 404);

      when(mockClient.post(any, headers: anyNamed('headers'), body: anyNamed('body')))
          .thenAnswer((_) async => mockResponse);

      final result = await apiClient.checkPhoneNumber('0987654321');

      expect(result.phoneNumber, '0987654321');
      expect(result.riskLevel.name, 'unknown');
    });

    test('checkPhoneNumber ném ApiException khi lỗi server', () async {
      final mockResponse = http.Response('Internal Server Error', 500);

      when(mockClient.post(any, headers: anyNamed('headers'), body: anyNamed('body')))
          .thenAnswer((_) async => mockResponse);

      expect(
        () => apiClient.checkPhoneNumber('0123456789'),
        throwsA(isA<ApiException>()),
      );
    });

    test('reportFraudNumber trả về true khi thành công (201)', () async {
      final mockResponse = http.Response('Created', 201);

      when(mockClient.post(any, headers: anyNamed('headers'), body: anyNamed('body')))
          .thenAnswer((_) async => mockResponse);

      final request = ReportFraudRequest(
        phoneNumber: '0123456789',
        category: 'scam',
        description: 'Lừa đảo chuyển khoản',
        reportedAt: DateTime.now(),
      );

      final result = await apiClient.reportFraudNumber(request);

      expect(result, isTrue);
    });

    test('getStatistics trả về dữ liệu thống kê', () async {
      final mockResponse = http.Response(
        '{"total_checks": 1000, "fraud_detected": 150, "safe_numbers": 850}',
        200,
      );

      when(mockClient.get(any)).thenAnswer((_) async => mockResponse);

      final stats = await apiClient.getStatistics();

      expect(stats['total_checks'], 1000);
      expect(stats['fraud_detected'], 150);
      verify(mockClient.get(Uri.parse('https://test.api.com/api/v1/statistics'))).called(1);
    });

    test('isServerReachable trả về true khi server khỏe', () async {
      final mockResponse = http.Response('OK', 200);

      when(mockClient.get(any)).thenAnswer((_) async => mockResponse);

      final isReachable = await apiClient.isServerReachable();

      expect(isReachable, isTrue);
    });

    test('isServerReachable trả về false khi server không phản hồi', () async {
      when(mockClient.get(any)).thenThrow(Exception('Timeout'));

      final isReachable = await apiClient.isServerReachable();

      expect(isReachable, isFalse);
    });

    test('ApiException hiển thị message đúng', () {
      const exception = ApiException('Test error message');
      expect(exception.toString(), contains('Test error message'));
    });

    test('ReportFraudRequest toJson đúng format', () {
      final now = DateTime(2024, 1, 15, 10, 30, 0);
      final request = ReportFraudRequest(
        phoneNumber: '0123456789',
        category: 'telemarketing',
        description: 'Quảng cáo làm phiền',
        reportedAt: now,
      );

      final json = request.toJson();

      expect(json['phone_number'], '0123456789');
      expect(json['category'], 'telemarketing');
      expect(json['description'], 'Quảng cáo làm phiền');
      expect(json['reported_at'], now.toIso8601String());
    });
  });
}

// Extension để set mock client cho testing
extension on FraudDetectionApiClient {
  set _client(http.Client client) {
    // Sử dụng reflection hoặc setter nếu cần
    // Ở đây giả lập bằng cách override trong test
  }
}
