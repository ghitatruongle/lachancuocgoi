import '../../core/risk_level.dart';
import '../analysis_level.dart';
import '../analysis_result.dart';

class L1ResultParser {
  L1ResultParser._();

  /// Default critical keywords (fallback when not provided externally).
  /// These can be overridden by passing [criticalKeywords] to [parse()].
  static final Set<String> _defaultCriticalKeywords = {
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

  /// Public accessor for default critical keywords (used as fallback by L1Analyzer).
  static Set<String> get defaultCriticalKeywords =>
      Set<String>.unmodifiable(_defaultCriticalKeywords);

  /// Co-occurrence bonus: when matches span 2+ different categories,
  /// add a small score boost reflecting compound-threat risk.
  static const double _coOccurrenceBonusPerExtraCategory = 0.15;
  static const int _maxCoOccurrenceBonusCategories = 4;

  /// Positional weighting: keywords appearing in the first N% of the
  /// transcript (greeting/opening phase) get a score multiplier.
  /// Scammers often state their authority/urgency early in the call.
  static const double _earlyPositionFraction = 0.20;
  static const double _earlyPositionMultiplier = 1.15;

  static AnalysisResult parse(
    Set<KeywordMatch> matches, [
    int totalTokens = 0,
    Set<String>? criticalKeywords,
  ]) {
    final riskMatches = matches
        .where((match) => match.level.index > RiskLevel.green.index)
        .toSet();

    if (riskMatches.isEmpty) {
      return AnalysisResult(
        overallRiskLevel: RiskLevel.green,
        matches: const [],
        reason: 'Không tìm thấy từ khóa rủi ro.',
        analysisLevel: AnalysisLevel.l1,
        alertEnabled: false,
        confidence: totalTokens < 10 ? 0.6 : 0.9,
      );
    }

    final categoryGroups = <String, List<KeywordMatch>>{};
    for (final match in riskMatches) {
      categoryGroups.putIfAbsent(match.category, () => []).add(match);
    }

    final significantCategories = Map<String, List<KeywordMatch>>.fromEntries(
      categoryGroups.entries.where((entry) => entry.value.length >= 2),
    );

    // Positional weighting threshold: matches in the first 25% of the
    // transcript are considered "early" (greeting/opening phase).
    final earlyThreshold = totalTokens > 0
        ? (totalTokens * _earlyPositionFraction).ceil()
        : 0;

    final bestScore = categoryGroups.values
        .map((keywords) {
          final maxLevel = keywords
              .map((match) => match.level.index)
              .reduce((a, b) => a > b ? a : b);
          final weight = switch (keywords.length) {
            >= 4 => 1.00,
            3 => 0.85,
            2 => 0.65,
            _ => 0.30,
          };

          // Positional weighting: if any keyword in this category group
          // appears early in the transcript, apply a score multiplier.
          final hasEarlyKeyword =
              earlyThreshold > 0 &&
              keywords.any(
                (m) => m.startIndex >= 0 && m.startIndex < earlyThreshold,
              );
          final positionalBonus = hasEarlyKeyword
              ? _earlyPositionMultiplier
              : 1.0;

          return maxLevel * weight * positionalBonus;
        })
        .fold<double>(0, (best, score) => score > best ? score : best);

    // Category co-occurrence bonus: 2+ distinct categories with risk matches
    // indicates a compound scam pattern (e.g. AUTHORITY + MONEY + URGENCY).
    final distinctCategoryCount = categoryGroups.length;
    final extraCategories = (distinctCategoryCount - 1).clamp(
      0,
      _maxCoOccurrenceBonusCategories,
    );
    final coOccurrenceBonus =
        extraCategories * _coOccurrenceBonusPerExtraCategory;
    final adjustedBestScore = bestScore + coOccurrenceBonus;

    final effectiveCriticalKeywords =
        criticalKeywords ?? _defaultCriticalKeywords;
    final hasCriticalKeyword = _containsCriticalKeyword(
      riskMatches,
      effectiveCriticalKeywords,
    );
    final adjustedRiskLevel = switch (adjustedBestScore) {
      _ when hasCriticalKeyword => RiskLevel.red,
      < 1.00 => RiskLevel.yellow,
      < 2.50 => RiskLevel.orange,
      _ => RiskLevel.red,
    };

    final reason = StringBuffer(switch (adjustedRiskLevel) {
      RiskLevel.red => 'PHÁT HIỆN TỪ KHÓA NGUY HIỂM',
      RiskLevel.orange => 'PHÁT HIỆN TỪ KHÓA NGUY CƠ',
      RiskLevel.yellow => 'Phát hiện từ khóa cần lưu ý',
      RiskLevel.green => 'Hệ thống L1 phát hiện từ khóa rủi ro.',
    });

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

  static bool _containsCriticalKeyword(
    Set<KeywordMatch> matches,
    Set<String> criticalKeywords,
  ) {
    return matches.any((match) {
      final keyword = match.keyword.toLowerCase();
      return criticalKeywords.any(
        (critical) => RegExp(
          r'(?:\b|\s|^)' + RegExp.escape(critical) + r'(?:\b|\s|$)',
        ).hasMatch(keyword),
      );
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
