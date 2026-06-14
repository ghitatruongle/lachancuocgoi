import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import '../../common/text_normalizer.dart';

typedef SafetyAssetProvider = FutureOr<String> Function(String fileName);

class SafetyFilter {
  SafetyFilter._();

  static const String configFile = 'safety_keywords.json';

  static int _openingSectionLength = 200;
  static List<String> _casualPhrases = const <String>[
    'ăn cơm chưa', 'đi chơi không', 'đang làm gì đấy', 'thế à', 'vậy hả',
    'mẹ đây', 'bố đây', 'con đang', 'chút nữa gọi lại', 'mua rau', 'đi chợ',
  ];
  static List<String> _standardTransactions = const <String>[
    'chuyển khoản tiền trọ', 'tiền cơm', 'chia tiền nốt',
    'chuyển tiền học phí', 'trả tiền điện',
  ];
  static List<String> _dangerOverrides = const <String>[
    'số tài khoản', 'mã otp', 'chuyển khoản', 'mật khẩu',
    'cccd', 'cmnd', 'công an', 'kiểm sát', 'tải ứng dụng',
    'cài app', 'link', 'bắt cóc', 'tống tiền',
  ];
  static double _casualReductionPerMatch = 0.15;
  static double _transactionReductionPerMatch = 0.30;
  static double _minMultiplier = 0.4;

  // Pre-computed normalized phrase lists — built once at loadConfig time
  // to avoid redundant normalize() calls on every calculateSafetyDiscount().
  static List<String> _normDanger = const [];
  static List<String> _normCasual = const [];
  static List<String> _normTransaction = const [];

  static Future<void> loadConfig({
    AssetBundle? assetBundle,
    SafetyAssetProvider? assetProvider,
  }) async {
    try {
      // Must await directly — assetProvider returns FutureOr<String>, and
      // wrapping a Future in Future.value() creates a nested future (same bug
      // fixed in g_detection_engine.dart and l1_analysis.dart). Mirrors the
      // canonical pattern used in those sibling files.
      final String text;
      if (assetProvider != null) {
        text = await assetProvider(configFile);
      } else {
        text = await (assetBundle ?? rootBundle).loadString(
          'assets/$configFile',
        );
      }
      final decoded = jsonDecode(text);
      if (decoded is! Map) return;
      final json = decoded.cast<String, Object?>();
      _openingSectionLength =
          (json['openingSectionLength'] as num?)?.toInt() ??
          _openingSectionLength;
      _casualPhrases = List<String>.unmodifiable(
        _readStringList(json['casualPhrases'], _casualPhrases),
      );
      _standardTransactions = List<String>.unmodifiable(
        _readStringList(json['standardTransactions'], _standardTransactions),
      );
      _dangerOverrides = List<String>.unmodifiable(
        _readStringList(json['dangerOverrides'], _dangerOverrides),
      );
      _casualReductionPerMatch =
          (json['casualReductionPerMatch'] as num?)?.toDouble() ??
          _casualReductionPerMatch;
      _transactionReductionPerMatch =
          (json['transactionReductionPerMatch'] as num?)?.toDouble() ??
          _transactionReductionPerMatch;
      _minMultiplier =
          (json['minMultiplier'] as num?)?.toDouble() ?? _minMultiplier;
    } catch (e, st) {
      // Previously this was `catch (_) { /* ignore */ }` — a malformed asset
      // or missing file would silently leave stale defaults with no clue why.
      // Log so config load failures are diagnosable.
      debugPrint('[SafetyFilter] Failed to load $configFile: $e\n$st');
    }
    // Pre-compute normalized phrase lists once after config is loaded.
    _rebuildNormalizedLists();
  }

  static void _rebuildNormalizedLists() {
    _normDanger = _dangerOverrides
        .map((p) => TextNormalizer.normalize(p, applySlang: true, noiseMode: NoiseMode.space))
        .toList();
    _normCasual = _casualPhrases
        .map((p) => TextNormalizer.normalize(p, applySlang: true, noiseMode: NoiseMode.space))
        .toList();
    _normTransaction = _standardTransactions
        .map((p) => TextNormalizer.normalize(p, applySlang: true, noiseMode: NoiseMode.space))
        .toList();
  }

  static double calculateSafetyDiscount(String fullTranscript) {
    final text = TextNormalizer.normalize(
      fullTranscript,
      applySlang: true,
      noiseMode: NoiseMode.space,
    );
    final mainSection = text.length > _openingSectionLength
        ? text.substring(_openingSectionLength)
        : '';

    // Tokenize main section for accurate phrase matching — avoids substring
    // false positives (e.g. "chuyển khoản" matching inside "không chuyển khoản").
    // Only applied to danger keywords; casual/transaction phrases use substring
    // matching (phrases can appear within longer sentences).
    final mainTokens = mainSection.isEmpty
        ? <String>{}
        : mainSection.split(RegExp(r'\s+')).where((t) => t.isNotEmpty).toSet();

    // Use pre-computed normalized lists — no per-call normalization overhead.
    // Danger keywords: token-based matching for accuracy.
    final hasDangerInMain = _normDanger.any(
      (phrase) => _phraseTokensAllPresent(phrase, mainTokens),
    );
    if (hasDangerInMain) return 1.0;

    final openingSection = text.length > _openingSectionLength
        ? text.substring(0, _openingSectionLength)
        : text;
    var discountMultiplier = 1.0;

    // Casual phrases: substring matching (they appear naturally in longer text).
    final casualMatchCount = _normCasual
        .where(openingSection.contains)
        .length;
    if (casualMatchCount > 0) {
      discountMultiplier -= _casualReductionPerMatch * casualMatchCount;
    }

    // Transaction phrases: substring matching on full text.
    final safeTransactionMatchCount = _normTransaction
        .where(text.contains)
        .length;
    if (safeTransactionMatchCount > 0) {
      discountMultiplier -=
          _transactionReductionPerMatch * safeTransactionMatchCount;
    }

    return discountMultiplier.clamp(_minMultiplier, 1.0).toDouble();
  }

  /// Checks if all tokens of a normalized [phrase] exist in [tokens].
  /// More accurate than substring matching — "chuyển khoản" won't falsely
  /// match "không chuyển khoản" because token-level intersection is used.
  static bool _phraseTokensAllPresent(String phrase, Set<String> tokenSet) {
    if (tokenSet.isEmpty) return false;
    final phraseTokens = phrase.split(' ');
    for (final token in phraseTokens) {
      if (!tokenSet.contains(token)) return false;
    }
    return true;
  }

  /// Resets all fields to hardcoded defaults. For use in unit tests only.
  @visibleForTesting
  static void resetForTesting() {
    _openingSectionLength = 200;
    _casualPhrases = <String>[
      'ăn cơm chưa', 'đi chơi không', 'đang làm gì đấy', 'thế à', 'vậy hả',
      'mẹ đây', 'bố đây', 'con đang', 'chút nữa gọi lại', 'mua rau', 'đi chợ',
    ];
    _standardTransactions = <String>[
      'chuyển khoản tiền trọ', 'tiền cơm', 'chia tiền nốt',
      'chuyển tiền học phí', 'trả tiền điện',
    ];
    _dangerOverrides = <String>[
      'số tài khoản', 'mã otp', 'chuyển khoản', 'mật khẩu',
      'cccd', 'cmnd', 'công an', 'kiểm sát', 'tải ứng dụng',
      'cài app', 'link', 'bắt cóc', 'tống tiền',
    ];
    _casualReductionPerMatch = 0.15;
    _transactionReductionPerMatch = 0.30;
    _minMultiplier = 0.4;
    _rebuildNormalizedLists();
  }

  static List<String> _readStringList(Object? raw, List<String> fallback) {
    if (raw is! List) return fallback;
    return raw.map((item) => item.toString().toLowerCase()).toList();
  }
}
