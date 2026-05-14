import '../../core/risk_level.dart';
import '../analysis_level.dart';
import '../analysis_result.dart';

class L1ResultParser {
  L1ResultParser._();

  static final Set<String> _criticalKeywords = {
    'mã otp',
    'mã xác thực',
    'mã bảo mật',
    'otp',
    'ma otp',
    'mã số xác minh',
    'mã đăng nhập',
    'mã chuyển tiền',
    'số tài khoản',
    'số thẻ',
    'cvv',
    'cvc',
    'pin ngân hàng',
    'mật khẩu otp',
    'xác minh otp',
    'gửi mã',
    'nhận mã',
  };

  static AnalysisResult parse(Set<KeywordMatch> matches,
      [int totalTokens = 0]) {
    final riskMatches = matches
        .where((match) => match.level.index > RiskLevel.green.index)
        .toSet();

    if (riskMatches.isEmpty) {
      return const AnalysisResult(
        overallRiskLevel: RiskLevel.green,
        matches: [],
        reason: 'Không tìm thấy từ khóa rủi ro.',
        analysisLevel: AnalysisLevel.l1,
        alertEnabled: false,
        confidence: 0.9,
      );
    }

    final categoryGroups = <String, List<KeywordMatch>>{};
    for (final match in riskMatches) {
      categoryGroups.putIfAbsent(match.category, () => []).add(match);
    }

    final significantCategories = Map<String, List<KeywordMatch>>.fromEntries(
      categoryGroups.entries.where((entry) => entry.value.length >= 2),
    );

    final bestScore = categoryGroups.values.map((keywords) {
      final maxLevel = keywords
          .map((match) => match.level.index)
          .reduce((a, b) => a > b ? a : b);
      final weight = switch (keywords.length) {
        >= 4 => 1.00,
        3 => 0.85,
        2 => 0.65,
        _ => 0.30,
      };
      return maxLevel * weight;
    }).fold<double>(0, (best, score) => score > best ? score : best);

    final hasCriticalKeyword = _containsCriticalKeyword(riskMatches);
    final adjustedRiskLevel = switch (bestScore) {
      _ when hasCriticalKeyword => RiskLevel.red,
      < 1.00 => RiskLevel.yellow,
      < 2.00 => RiskLevel.orange,
      _ => RiskLevel.red,
    };

    final reason = StringBuffer(
      switch (adjustedRiskLevel) {
        RiskLevel.red => 'PHÁT HIỆN TỪ KHÓA NGUY HIỂM',
        RiskLevel.orange => 'PHÁT HIỆN TỪ KHÓA CÓ NGUY CƠ',
        RiskLevel.yellow => 'Phát hiện từ khóa cần lưu ý',
        RiskLevel.green => 'Hệ thống L1 phát hiện từ khóa rủi ro.',
      },
    );

    if (hasCriticalKeyword) {
      reason.write(' [CẢNH BÁO OTP/BẢO MẬT]');
    }
    if (significantCategories.isNotEmpty) {
      reason.write(' [${significantCategories.keys.join(', ')}]');
    }

    return AnalysisResult(
      overallRiskLevel: adjustedRiskLevel,
      matches: riskMatches.toList(),
      reason: reason.toString(),
      analysisLevel: AnalysisLevel.l1,
      alertEnabled: adjustedRiskLevel != RiskLevel.green,
      confidence: _calculateConfidence(
        riskMatches.length,
        significantCategories.length,
        totalTokens,
      ),
    );
  }

  static bool _containsCriticalKeyword(Set<KeywordMatch> matches) {
    return matches.any((match) {
      final keyword = match.keyword.toLowerCase();
      return _criticalKeywords.any((critical) => keyword.contains(critical));
    });
  }

  static double _calculateConfidence(
    int matchCount,
    int significantCategoryCount,
    int totalTokens,
  ) {
    var confidence = 0.3;
    confidence += (matchCount * 0.1).clamp(0, 0.3).toDouble();
    confidence += (significantCategoryCount * 0.15).clamp(0, 0.3).toDouble();
    if (totalTokens > 0) {
      final proportion = matchCount / totalTokens;
      confidence += proportion.clamp(0, 0.1).toDouble();
    }
    return confidence.clamp(0.0, 1.0);
  }
}
