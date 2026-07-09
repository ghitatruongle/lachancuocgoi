import 'dart:convert';

import '../../../core/risk_level.dart';
import 'gemini_response.dart';

// ─── L3 Response Parser ────────────────────────────────────────────────
//
// Parses raw LLM response text into structured [AnalysisResponse] objects.
// Handles JSON extraction from markdown blocks, risk level parsing with
// keyword-based fallback inference, and reason string assembly.
//
// Extracted from [L3Analyzer] to reduce class size and enable independent
// testing of parsing logic.

class L3ResponseParser {
  /// Parses a raw LLM response string into an [AnalysisResponse].
  ///
  /// Throws [FormatException] if the response is blank or not valid JSON.
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

  /// Extracts JSON from a response that may contain markdown code blocks
  /// or other surrounding text.
  String extractJson(String responseText) {
    // Try to find a markdown json block first
    final markdownRegex = RegExp(r'```json\s*(\{.*?\})\s*```', dotAll: true);
    final match = markdownRegex.firstMatch(responseText);
    if (match != null) {
      return match.group(1) ?? responseText;
    }

    // Fallback to finding the first { and last }
    final startIndex = responseText.indexOf('{');
    final endIndex = responseText.lastIndexOf('}');
    if (startIndex != -1 && endIndex != -1 && endIndex > startIndex) {
      return responseText.substring(startIndex, endIndex + 1);
    }
    return responseText;
  }

  /// Maps a risk level string to a [RiskLevel] enum value.
  ///
  /// Falls back to [_inferLevelFromReason] if the level string is not
  /// recognized.
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

  /// Infers a [RiskLevel] from Vietnamese keywords in the reason text.
  ///
  /// Used as a fallback when the LLM does not provide a valid level string.
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

  /// Assembles a human-readable reason string from the response fields.
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

  /// Checks if the text ends at a sentence boundary (including Vietnamese
  /// sentence-ending particles).
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
