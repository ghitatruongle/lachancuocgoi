import 'dart:async';
import 'dart:convert';

import '../../../core/asset_loader.dart';
import '../../../core/logger.dart';

import '../../common/text_normalizer.dart';

typedef SafetyAssetProvider = FutureOr<String> Function(String fileName);

class SafetyFilter {
  SafetyFilter._();

  static const String configFile = 'safety_keywords.json';

  static int _openingSectionLength = 200;
  static List<String> _casualPhrases = const <String>[
    'ăn cơm chưa',
    'đi chơi không',
    'đang làm gì đấy',
    'thế à',
    'vậy hả',
    'mẹ đây',
    'bố đây',
    'con đang',
    'chút nữa gọi lại',
    'mua rau',
    'đi chợ',
  ];
  static List<String> _standardTransactions = const <String>[
    'chuyển khoản tiền trọ',
    'tiền cơm',
    'chia tiền nốt',
    'chuyển tiền học phí',
    'trả tiền điện',
  ];
  static List<String> _dangerOverrides = const <String>[
    'số tài khoản',
    'mã otp',
    'chuyển khoản',
    'mật khẩu',
    'cccd',
    'cmnd',
    'công an',
    'kiểm sát',
    'tải ứng dụng',
    'cài app',
    'link',
    'bắt cóc',
    'tống tiền',
  ];
  static double _casualReductionPerMatch = 0.15;
  static double _transactionReductionPerMatch = 0.30;
  static double _relationshipDiscount = 0.05;
  static double _smallAmountDiscount = 0.10;
  static double _minMultiplier = 0.4;

  static List<String> _normDanger = const [];
  static List<String> _normCasual = const [];
  static List<String> _normTransaction = const [];

  static const List<String> _negationWords = [
    'không',
    'khong',
    'ko',
    'chưa',
    'chua',
    'chẳng',
    'chang',
    'chả',
    'cha',
  ];

  static const List<String> _relationshipTerms = [
    'me',
    'bo',
    'vo',
    'chong',
    'chu',
    'cau',
    'bac',
    'duong',
  ];

  static const double _smallAmountThreshold = 5000000;
  static const double _largeAmountThreshold = 50000000;

  static Future<void> loadConfig({
    AssetLoader? assetLoader,
    SafetyAssetProvider? assetProvider,
    AppLogger? logger,
  }) async {
    try {
      final String text;
      if (assetProvider != null) {
        text = await assetProvider(configFile);
      } else if (assetLoader != null) {
        text = await assetLoader.loadString('assets/$configFile');
      } else {
        if (logger != null) {
          logger.warning(
            '[SafetyFilter] No AssetLoader provided — using hardcoded defaults',
          );
        }
        _rebuildNormalizedLists();
        return;
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
      if (logger != null) {
        logger.warning('[SafetyFilter] Failed to load $configFile: $e', e, st);
      }
    }

    _rebuildNormalizedLists();
  }

  static void _rebuildNormalizedLists() {
    _normDanger = _dangerOverrides
        .map(
          (p) => TextNormalizer.normalize(
            p,
            applySlang: true,
            noiseMode: NoiseMode.space,
          ),
        )
        .toList();
    _normCasual = _casualPhrases
        .map(
          (p) => TextNormalizer.normalize(
            p,
            applySlang: true,
            noiseMode: NoiseMode.space,
          ),
        )
        .toList();
    _normTransaction = _standardTransactions
        .map(
          (p) => TextNormalizer.normalize(
            p,
            applySlang: true,
            noiseMode: NoiseMode.space,
          ),
        )
        .toList();
  }

  static double calculateSafetyDiscount(String fullTranscript) {
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

  static double calculateSafetyDiscountNormalized(
    String normalizedText, {
    double? rawAmountBonus,
  }) {
    final text = normalizedText;
    final mainSection = text.length > _openingSectionLength
        ? text.substring(_openingSectionLength)
        : '';

    final openingSection = text.length > _openingSectionLength
        ? text.substring(0, _openingSectionLength)
        : text;
    final mainTokens = mainSection.isEmpty
        ? <String>{}
        : mainSection.split(RegExp(r'\s+')).where((t) => t.isNotEmpty).toSet();

    final hasDangerInMain = _normDanger.any(
      (phrase) => _phraseTokensAllPresent(phrase, mainTokens),
    );
    if (hasDangerInMain) return 1.0;

    var discountMultiplier = 1.0;

    final casualMatchCount = _normCasual
        .where(
          (p) =>
              openingSection.contains(p) &&
              !_isNegatedInText(openingSection, p),
        )
        .length;
    if (casualMatchCount > 0) {
      discountMultiplier -= _casualReductionPerMatch * casualMatchCount;
    }

    final safeTransactionMatchCount = _normTransaction
        .where((p) => text.contains(p) && !_isNegatedInText(text, p))
        .length;
    if (safeTransactionMatchCount > 0) {
      discountMultiplier -=
          _transactionReductionPerMatch * safeTransactionMatchCount;
    }

    if (_hasRelationshipContext(text)) {
      discountMultiplier -= _relationshipDiscount;
    }

    discountMultiplier -= rawAmountBonus ?? _getAmountBonus(text);

    return discountMultiplier.clamp(_minMultiplier, 1.0).toDouble();
  }

  static bool _phraseTokensAllPresent(String phrase, Set<String> tokenSet) {
    if (tokenSet.isEmpty) return false;
    final phraseTokens = phrase.split(' ');
    for (final token in phraseTokens) {
      if (!tokenSet.contains(token)) return false;
    }
    return true;
  }

  static bool _isNegatedInText(String text, String phrase) {
    final idx = text.indexOf(phrase);
    if (idx < 0) return false;

    for (final negWord in _negationWords) {
      if (phrase.startsWith('$negWord ')) return true;
    }

    return false;
  }

  static bool _hasRelationshipContext(String text) {
    final checkLength = text.length < 100 ? text.length : 100;
    final opening = text.substring(0, checkLength);
    final tokens = opening.split(RegExp(r'\s+'));
    return tokens.any(_relationshipTerms.contains);
  }

  static double _getAmountBonus(String text) {
    final amountPatterns = [
      RegExp(
        r'(\d{1,3}(?:[.,]\d{3}){1,3})\s*(?:vnd|đ|dong|vnđ)(?!\w)',
        caseSensitive: false,
      ),
      RegExp(
        r'(?:vnd|đ|dong|vnđ)\s*(\d{1,3}(?:[.,]\d{3}){1,3})',
        caseSensitive: false,
      ),

      RegExp(r'(\d{4,})\s*(?:vnd|đ|dong|vnđ)(?!\w)', caseSensitive: false),

      RegExp(r'(\d+(?:\.\d+)?)\s*(?:trieu|tr)\b', caseSensitive: false),
    ];

    for (final pattern in amountPatterns) {
      final match = pattern.firstMatch(text);
      if (match != null) {
        final rawAmount = match.group(1) ?? match.group(2);
        if (rawAmount != null) {
          final amount = double.tryParse(
            rawAmount.replaceAll(RegExp(r'[.,]'), ''),
          );
          if (amount != null) {
            if (amount < _smallAmountThreshold) return _smallAmountDiscount;
            if (amount > _largeAmountThreshold) return -_smallAmountDiscount;
          }
        }
      }
    }

    final trieuMatch = RegExp(
      r'(\d+(?:\.\d+)?)\s*(?:triệu|trieu|tr)(?!\w)',
      caseSensitive: false,
    ).firstMatch(text);
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

  static void resetForTesting() {
    _openingSectionLength = 200;
    _casualPhrases = <String>[
      'ăn cơm chưa',
      'đi chơi không',
      'đang làm gì đấy',
      'thế à',
      'vậy hả',
      'mẹ đây',
      'bố đây',
      'con đang',
      'chút nữa gọi lại',
      'mua rau',
      'đi chợ',
    ];
    _standardTransactions = <String>[
      'chuyển khoản tiền trọ',
      'tiền cơm',
      'chia tiền nốt',
      'chuyển tiền học phí',
      'trả tiền điện',
    ];
    _dangerOverrides = <String>[
      'số tài khoản',
      'mã otp',
      'chuyển khoản',
      'mật khẩu',
      'cccd',
      'cmnd',
      'công an',
      'kiểm sát',
      'tải ứng dụng',
      'cài app',
      'link',
      'bắt cóc',
      'tống tiền',
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
