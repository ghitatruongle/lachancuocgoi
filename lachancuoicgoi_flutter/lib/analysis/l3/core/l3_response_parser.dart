import 'dart:convert';

import '../../../core/risk_level.dart';
import 'gemini_response.dart';

class L3ResponseParser {
  AnalysisResponse parse(String responseText) {
    if (responseText.trim().isEmpty) {
      throw const FormatException('Response is blank');
    }
    final jsonString = extractJson(responseText);
    final decoded = jsonDecode(jsonString);
    if (decoded is! Map) {
      throw const FormatException('Expected JSON object');
    }
    return AnalysisResponse.fromJson(decoded.cast<String, Object?>());
  }

  String extractJson(String responseText) {
    final markdownRegex = RegExp(r'```json\s*(\{.*?\})\s*```', dotAll: true);
    final match = markdownRegex.firstMatch(responseText);
    if (match != null) {
      return match.group(1) ?? responseText;
    }

    final startIndex = responseText.indexOf('{');
    final endIndex = responseText.lastIndexOf('}');
    if (startIndex != -1 && endIndex != -1 && endIndex > startIndex) {
      return responseText.substring(startIndex, endIndex + 1);
    }
    return responseText;
  }

  RiskLevel parseRiskLevel(String? level, String? reason) {
    switch (level?.trim().toLowerCase()) {
      case 'red':
        return RiskLevel.red;
      case 'orange':
        return RiskLevel.orange;
      case 'yellow':
        return RiskLevel.yellow;
      case 'green':
        return RiskLevel.green;
      default:
        return inferLevelFromReason(reason);
    }
  }

  RiskLevel inferLevelFromReason(String? reason) {
    final lower = reason?.toLowerCase() ?? '';
    final redWords = <String>[
      'lừa đảo',
      'chuyển tiền',
      'mã otp',
      'đe dọa',
      'khởi tố',
      'bắt cóc',
      'tống tiền',
    ];
    if (redWords.any(lower.contains)) {
      return RiskLevel.red;
    }
    final orangeWords = <String>[
      'công an',
      'kiểm sát',
      'tài khoản',
      'mật khẩu',
      'cấp bách',
      'ngay lập tức',
      'ứng dụng',
    ];
    if (orangeWords.any(lower.contains)) {
      return RiskLevel.orange;
    }
    final yellowWords = <String>[
      'đáng ngờ',
      'cẩn thận',
      'lưu ý',
      'chú ý',
      'không chắc',
      'có thể',
    ];
    if (yellowWords.any(lower.contains)) {
      return RiskLevel.yellow;
    }
    return RiskLevel.green;
  }

  String assembleReason(AnalysisResponse response) {
    final reasonParts = <String>[
      if ((response.label ?? '').trim().isNotEmpty) '[${response.label}]',
      if ((response.reason ?? '').trim().isNotEmpty) response.reason!.trim(),
      if ((response.recommendation ?? '').trim().isNotEmpty)
        'Khuyến cáo: ${response.recommendation!.trim()}',
    ];
    final joined = reasonParts.join(' ').trim();
    return joined.isNotEmpty ? reasonParts.join(' ') : 'Phân tích hoàn tất';
  }

  bool isSentenceBoundary(String text) {
    final trimmed = text.trimRight();
    if (trimmed.isEmpty) {
      return false;
    }
    final lower = trimmed.toLowerCase();
    final lastChar = trimmed[trimmed.length - 1];
    if ('.?!\n;:'.contains(lastChar) || trimmed.endsWith('...')) {
      return true;
    }
    final endings = <String>[
      ' à',
      ' ạ',
      ' nhé',
      ' nha',
      ' vậy',
      ' rồi',
      ' đi',
      ' nhỉ',
      ' hen',
      ' nghe',
    ];
    return endings.any(lower.endsWith);
  }
}
