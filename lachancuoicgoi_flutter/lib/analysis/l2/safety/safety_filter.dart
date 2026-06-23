import 'dart:async';
import 'dart:convert';

import '../../../core/asset_loader.dart';
import '../../../core/logger.dart';
import 'package:flutter/foundation.dart' show debugPrint;

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
  static double _relationshipDiscount = 0.05;
  static double _smallAmountDiscount = 0.10;
  static double _minMultiplier = 0.4;

  // Pre-computed normalized phrase lists — built once at loadConfig time
  // to avoid redundant normalize() calls on every calculateSafetyDiscount().
  static List<String> _normDanger = const [];
  static List<String> _normCasual = const [];
  static List<String> _normTransaction = const [];

  // Negation words — if a casual/transaction phrase appears shortly after
  // a negation word, it's likely not a real safety signal.
  // e.g. "không phải chuyển tiền học phí" → should NOT reduce discount.
  static const List<String> _negationWords = [
    'không', 'khong', 'ko', 'chưa', 'chua',
    'chẳng', 'chang', 'chả', 'cha',
  ];

  // Relationship terms — unambiguous family indicators only, NORMALIZED (no diacritics)
  // since _hasRelationshipContext operates on already-normalized text.
  // Excludes ambiguous terms: 'ba' (bà/ba/three), 'di' (dì/đi), 'co' (cô/có),
  // 'ong' (ông), 'ma' (má/mà), 'mo' (mợ/mở).
  static const List<String> _relationshipTerms = [
    'me', 'bo', 'vo', 'chong',
    'chu', 'cau', 'bac', 'duong',
  ];

  // Amount thresholds for safety discount adjustment.
  static const double _smallAmountThreshold = 5000000; // 5 triệu VND
  static const double _largeAmountThreshold = 50000000; // 50 triệu VND

  static Future<void> loadConfig({
    AssetLoader? assetLoader,
    SafetyAssetProvider? assetProvider,
    AppLogger? logger,
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
        if (assetLoader == null) {
          throw StateError('AssetLoader is null. Phải cung cấp AssetLoader để load config.');
        }
        text = await assetLoader.loadString('assets/$configFile');
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
    } on Object catch (e, st) {
      // Previously this was `catch (_) { /* ignore */ }` — a malformed asset
      // or missing file would silently leave stale defaults with no clue why.
      // Log so config load failures are diagnosable.
      if (logger != null) {
        logger.warning('[SafetyFilter] Failed to load $configFile: $e', e, st);
      } else {
        debugPrint('[WARN] [SafetyFilter] Failed to load $configFile: $e | Error: $e\n$st');
      }
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
    // Extract amount bonus from RAW text BEFORE normalization — the phonetic
    // map converts digits to letters (5→s, 0→o, etc.) which destroys amount
    // patterns like "500000 vnđ".
    final rawAmountBonus = _getAmountBonus(fullTranscript.toLowerCase());

    final text = TextNormalizer.normalize(
      fullTranscript,
      applySlang: true,
      noiseMode: NoiseMode.space,
    );
    return calculateSafetyDiscountNormalized(
      text,
      rawAmountBonus: rawAmountBonus,
    );
  }

  /// Variant nhận text ĐÃ normalize. Dùng cho L2 hot path để tránh normalize
  /// 2 lần. [rawAmountBonus] is the pre-computed amount bonus from raw text
  /// (before normalization destroyed digit patterns). If null, _getAmountBonus
  /// is called on normalized text as fallback (works for "triệu" but not digits).
  static double calculateSafetyDiscountNormalized(
    String normalizedText, {
    double? rawAmountBonus,
  }) {
    final text = normalizedText;
    final mainSection = text.length > _openingSectionLength
        ? text.substring(_openingSectionLength)
        : '';

    // Conversation phase detection: split transcript into opening/main.
    final openingSection = text.length > _openingSectionLength
        ? text.substring(0, _openingSectionLength)
        : text;
    final mainTokens = mainSection.isEmpty
        ? <String>{}
        : mainSection.split(RegExp(r'\s+')).where((t) => t.isNotEmpty).toSet();

    // Danger keywords: token-based matching in main section only.
    // For short texts (< openingSectionLength), main section is empty → no danger override.
    // This is intentional: short greetings with "chuyển khoản" in casual context
    // should not be blocked (e.g. "chuyển khoản tiền trọ cho mẹ").
    final hasDangerInMain = _normDanger.any(
      (phrase) => _phraseTokensAllPresent(phrase, mainTokens),
    );
    if (hasDangerInMain) return 1.0;

    var discountMultiplier = 1.0;

    // Casual phrases: substring matching with negation awareness.
    // Only phrases in the opening section (greeting phase) count.
    final casualMatchCount = _normCasual
        .where((p) => openingSection.contains(p) && !_isNegatedInText(openingSection, p))
        .length;
    if (casualMatchCount > 0) {
      discountMultiplier -= _casualReductionPerMatch * casualMatchCount;
    }

    // Transaction phrases: substring matching with negation awareness.
    final safeTransactionMatchCount = _normTransaction
        .where((p) => text.contains(p) && !_isNegatedInText(text, p))
        .length;
    if (safeTransactionMatchCount > 0) {
      discountMultiplier -=
          _transactionReductionPerMatch * safeTransactionMatchCount;
    }

    // Relationship context: conversations with family get extra discount.
    if (_hasRelationshipContext(text)) {
      discountMultiplier -= _relationshipDiscount;
    }

    // Amount awareness: use pre-computed raw bonus if available, else check normalized text.
    discountMultiplier -= rawAmountBonus ?? _getAmountBonus(text);

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

  /// Checks if [phrase] in [text] is directly preceded by a negation pattern.
  /// Uses direct text matching (not token window) to avoid false positives
  /// where a negation word from a PREVIOUS clause is caught.
  /// Eats the first occurrence only.
  static bool _isNegatedInText(String text, String phrase) {
    final idx = text.indexOf(phrase);
    if (idx < 0) return false;

    // Only negate if the phrase itself starts with a negation word.
    // This is conservative but bulletproof — it avoids false positives
    // where negation words from previous clauses are caught.
    // The negation word must be at the START of the matched phrase.
    for (final negWord in _negationWords) {
      if (phrase.startsWith('$negWord ')) return true;
    }

    return false;
  }

  /// Returns true if the text contains a family/relationship term in the
  /// first 100 characters. Conversations with family are more likely safe.
  static bool _hasRelationshipContext(String text) {
    final checkLength = text.length < 100 ? text.length : 100;
    final opening = text.substring(0, checkLength);
    final tokens = opening.split(RegExp(r'\s+'));
    return tokens.any(_relationshipTerms.contains);
  }

  /// Extracts VND amounts from the text and returns a discount bonus.
  /// Small amounts (< 5M) → positive bonus (more safety discount).
  /// Large amounts (> 50M) → negative bonus (less safety discount).
  static double _getAmountBonus(String text) {
    final amountPatterns = [
      // Formatted numbers with VND suffix: "1.234.567 vnd" or "1,234,567đ"
      RegExp(r'(\d{1,3}(?:[.,]\d{3}){1,3})\s*(?:vnd|đ|dong|vnđ)(?!\w)', caseSensitive: false),
      RegExp(r'(?:vnd|đ|dong|vnđ)\s*(\d{1,3}(?:[.,]\d{3}){1,3})', caseSensitive: false),
      // Plain numbers with VND suffix: "500000 vnd", "200000đ"
      RegExp(r'(\d{4,})\s*(?:vnd|đ|dong|vnđ)(?!\w)', caseSensitive: false),
      // Million shorthand: "2 trieu", "3tr"
      RegExp(r'(\d+(?:\.\d+)?)\s*(?:trieu|tr)\b', caseSensitive: false),
    ];

    for (final pattern in amountPatterns) {
      final match = pattern.firstMatch(text);
      if (match != null) {
        final rawAmount = match.group(1) ?? match.group(2);
        if (rawAmount != null) {
          final amount = double.tryParse(rawAmount.replaceAll(RegExp(r'[.,]'), ''));
          if (amount != null) {
            if (amount < _smallAmountThreshold) return _smallAmountDiscount;
            if (amount > _largeAmountThreshold) return -_smallAmountDiscount;
          }
        }
      }
    }
    // Also check for "triệu" or "tr" pattern (e.g., "2 triệu", "3tr")
    final trieuMatch = RegExp(r'(\d+(?:\.\d+)?)\s*(?:triệu|trieu|tr)(?!\w)', caseSensitive: false).firstMatch(text);
    if (trieuMatch != null) {
      final numStr = trieuMatch.group(1);
      if (numStr != null) {
        final num = double.tryParse(numStr);
        if (num != null) {
          final amount = num * 1000000;
          if (amount < _smallAmountThreshold) return _smallAmountDiscount;
          if (amount > _largeAmountThreshold) return -_smallAmountDiscount;
        }
      }
    }
    return 0.0;
  }

  // For use in unit tests only.
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
    _relationshipDiscount = 0.05;
    _smallAmountDiscount = 0.10;
    _minMultiplier = 0.4;
    _rebuildNormalizedLists();
  }

  static List<String> _readStringList(Object? raw, List<String> fallback) {
    if (raw is! List) return fallback;
    return raw.map((item) => item.toString().toLowerCase()).toList();
  }
}
