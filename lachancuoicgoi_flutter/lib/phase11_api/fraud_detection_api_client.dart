import 'dart:convert';
import 'package:http/http.dart' as http;
import '../data/models/call_log.dart';
import '../data/models/analysis_result.dart';

/// API Client để giao tiếp với server backend
/// Dùng để gửi số điện thoại cần kiểm tra và nhận kết quả phân tích
class FraudDetectionApiClient {
  final String baseUrl;
  final http.Client _client;

  FraudDetectionApiClient({this.baseUrl = 'https://api.lachancuoicgoi.com'})
      : _client = http.Client();

  /// Gửi số điện thoại lên server để kiểm tra
  /// Trả về kết quả phân tích từ server
  Future<AnalysisResult> checkPhoneNumber(String phoneNumber) async {
    try {
      final response = await _client.post(
        Uri.parse('$baseUrl/api/v1/check'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'phone_number': phoneNumber}),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return AnalysisResult.fromJson(data);
      } else if (response.statusCode == 404) {
        // Số điện thoại không có trong database
        return AnalysisResult.unknown(phoneNumber);
      } else {
        throw ApiException('Lỗi server: ${response.statusCode}');
      }
    } catch (e) {
      throw ApiException('Không thể kết nối server: $e');
    }
  }

  /// Gửi báo cáo số lừa đảo mới từ cộng đồng
  Future<bool> reportFraudNumber(ReportFraudRequest request) async {
    try {
      final response = await _client.post(
        Uri.parse('$baseUrl/api/v1/report'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(request.toJson()),
      );

      return response.statusCode == 201;
    } catch (e) {
      throw ApiException('Không thể gửi báo cáo: $e');
    }
  }

  /// Lấy thống kê từ server
  Future<Map<String, dynamic>> getStatistics() async {
    try {
      final response = await _client.get(
        Uri.parse('$baseUrl/api/v1/statistics'),
      );

      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      } else {
        throw ApiException('Lỗi khi lấy thống kê: ${response.statusCode}');
      }
    } catch (e) {
      throw ApiException('Không thể kết nối server: $e');
    }
  }

  /// Kiểm tra kết nối đến server
  Future<bool> isServerReachable() async {
    try {
      final response = await _client.get(
        Uri.parse('$baseUrl/api/v1/health'),
      ).timeout(const Duration(seconds: 5));

      return response.statusCode == 200;
    } catch (e) {
      return false;
    }
  }

  void dispose() {
    _client.close();
  }
}

/// Exception cho các lỗi API
class ApiException implements Exception {
  final String message;
  ApiException(this.message);

  @override
  String toString() => 'ApiException: $message';
}

/// Request để báo cáo số lừa đảo
class ReportFraudRequest {
  final String phoneNumber;
  final String category;
  final String description;
  final DateTime reportedAt;

  ReportFraudRequest({
    required this.phoneNumber,
    required this.category,
    required this.description,
    required this.reportedAt,
  });

  Map<String, dynamic> toJson() {
    return {
      'phone_number': phoneNumber,
      'category': category,
      'description': description,
      'reported_at': reportedAt.toIso8601String(),
    };
  }
}
