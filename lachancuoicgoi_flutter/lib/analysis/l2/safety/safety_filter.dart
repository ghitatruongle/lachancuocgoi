import 'dart:async';
import 'dart:convert';

import 'package:flutter/services.dart';

typedef SafetyAssetProvider = FutureOr<String> Function(String fileName);

class SafetyFilter {
  SafetyFilter._();

  static const String configFile = 'safety_keywords.json';

  static int _openingSectionLength = 200;
  static List<String> _casualPhrases = <String>[
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
  static List<String> _standardTransactions = <String>[
    'chuyển khoản tiền trọ',
    'tiền cơm',
    'chia tiền nốt',
    'chuyển tiền học phí',
    'trả tiền điện',
  ];
  static List<String> _dangerOverrides = <String>[
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
  static double _minMultiplier = 0.4;

  static Future<void> loadConfig({
    AssetBundle? assetBundle,
    SafetyAssetProvider? assetProvider,
  }) async {
    try {
      final text = assetProvider != null
          ? await Future<String>.value(assetProvider(configFile))
          : await (assetBundle ?? rootBundle).loadString('assets/$configFile');
      final decoded = jsonDecode(text);
      if (decoded is! Map) return;
      final json = decoded.cast<String, Object?>();
      _openingSectionLength =
          (json['openingSectionLength'] as num?)?.toInt() ??
          _openingSectionLength;
      _casualPhrases = _readStringList(json['casualPhrases'], _casualPhrases);
      _standardTransactions = _readStringList(
        json['standardTransactions'],
        _standardTransactions,
      );
      _dangerOverrides = _readStringList(
        json['dangerOverrides'],
        _dangerOverrides,
      );
      _casualReductionPerMatch =
          (json['casualReductionPerMatch'] as num?)?.toDouble() ??
          _casualReductionPerMatch;
      _transactionReductionPerMatch =
          (json['transactionReductionPerMatch'] as num?)?.toDouble() ??
          _transactionReductionPerMatch;
      _minMultiplier =
          (json['minMultiplier'] as num?)?.toDouble() ?? _minMultiplier;
    } catch (_) {
      return;
    }
  }

  static double calculateSafetyDiscount(String fullTranscript) {
    final text = fullTranscript.toLowerCase();
    final mainSection = text.length > _openingSectionLength
        ? text.substring(_openingSectionLength)
        : '';

    final hasDangerInMain = _dangerOverrides.any(mainSection.contains);
    if (hasDangerInMain) return 1.0;

    final openingSection = text.length > _openingSectionLength
        ? text.substring(0, _openingSectionLength)
        : text;
    var discountMultiplier = 1.0;

    final casualMatchCount = _casualPhrases
        .where(openingSection.contains)
        .length;
    if (casualMatchCount > 0) {
      discountMultiplier -= _casualReductionPerMatch * casualMatchCount;
    }

    final safeTransactionMatchCount = _standardTransactions
        .where(text.contains)
        .length;
    if (safeTransactionMatchCount > 0) {
      discountMultiplier -=
          _transactionReductionPerMatch * safeTransactionMatchCount;
    }

    return discountMultiplier.clamp(_minMultiplier, 1.0).toDouble();
  }

  static List<String> _readStringList(Object? raw, List<String> fallback) {
    if (raw is! List) return fallback;
    return raw.map((item) => item.toString().toLowerCase()).toList();
  }
}
