import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:lachancuocgoi_flutter/analysis/l2/safety/safety_filter.dart';

const String _testSafetyJson = '''
{
  "openingSectionLength": 200,
  "casualPhrases": [
    "ăn cơm chưa", "đi chơi không", "đang làm gì đấy", "thế à", "vậy hả",
    "mẹ đây", "bố đây", "con đang", "chút nữa gọi lại", "mua rau", "đi chợ",
    "alo", "ơi", "dạ", "nè", "khỏe không"
  ],
  "standardTransactions": [
    "chuyển khoản tiền trọ", "tiền cơm", "chia tiền nốt", "chuyển tiền học phí", "trả tiền điện"
  ],
  "dangerOverrides": [
    "số tài khoản", "mã otp", "chuyển khoản", "mật khẩu",
    "cccd", "cmnd", "công an", "kiểm sát", "tải ứng dụng",
    "cài app", "link", "bắt cóc", "tống tiền"
  ],
  "casualReductionPerMatch": 0.15,
  "transactionReductionPerMatch": 0.30,
  "minMultiplier": 0.4
}
''';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SafetyFilter.resetForTesting();
  });

  group('SafetyFilter — default config parity', () {
    test('openingSectionLength defaults to 200 (matches Kotlin)', () {
      final text = 'a' * 200;
      expect(SafetyFilter.calculateSafetyDiscount(text), 1.0);
    });

    test('casualReductionPerMatch defaults to 0.15', () {
      final result = SafetyFilter.calculateSafetyDiscount(
        'ăn cơm chưa bạn nhé',
      );
      expect(result, closeTo(0.85, 0.001));
    });

    test('transactionReductionPerMatch defaults to 0.30', () {
      final result = SafetyFilter.calculateSafetyDiscount('tiền cơm tháng này');
      expect(result, closeTo(0.70, 0.001));
    });

    test('minMultiplier defaults to 0.4', () {
      const text =
          'ăn cơm chưa đi chơi không đang làm gì đấy thế à vậy hả '
          'mẹ đây bố đây con đang chút nữa gọi lại mua rau đi chợ. '
          'chuyển khoản tiền trọ tiền cơm chia tiền nốt chuyển tiền học phí trả tiền điện';
      final result = SafetyFilter.calculateSafetyDiscount(text);

      expect(result, closeTo(0.4, 0.001));
    });
  });

  group('SafetyFilter — casual phrases in opening section', () {
    test('single casual phrase in opening -> discount applied (0.85)', () {
      final result = SafetyFilter.calculateSafetyDiscount(
        'alo, ăn cơm chưa bạn?',
      );
      expect(result, closeTo(0.85, 0.001));
    });

    test('two casual phrases in opening -> discount applied (0.70)', () {
      final result = SafetyFilter.calculateSafetyDiscount(
        'alo, ăn cơm chưa, đang làm gì đấy vậy?',
      );

      expect(result, closeTo(0.70, 0.001));
    });

    test('case insensitive match for casual phrases', () {
      final result = SafetyFilter.calculateSafetyDiscount('ALO, ĂN CƠM CHƯA?');

      expect(result, closeTo(0.85, 0.001));
    });
  });

  group('SafetyFilter — casual phrases after opening section', () {
    test('casual phrase only in main section -> NO discount', () {
      final prefix = 'x' * 210;
      final text = '$prefix ăn cơm chưa bạn nhé';
      final result = SafetyFilter.calculateSafetyDiscount(text);

      expect(result, 1.0);
    });

    test('casual phrase in opening + danger in main -> return 1.0', () {
      const prefix = 'ăn cơm chưa ';
      final filler = 'x' * (200 - prefix.length);
      final text = '$prefix${filler}mã otp của bạn là gì?';
      final result = SafetyFilter.calculateSafetyDiscount(text);

      expect(result, 1.0);
    });
  });

  group('SafetyFilter — danger keywords in main section', () {
    test('danger keyword in main section -> return 1.0', () {
      final prefix = 'x' * 210;
      final text = '${prefix}số tài khoản của bạn là gì?';
      final result = SafetyFilter.calculateSafetyDiscount(text);
      expect(result, 1.0);
    });

    test('danger keyword in opening section only -> NO override', () {
      const text = 'mã otp là gì vậy bạn?';
      final result = SafetyFilter.calculateSafetyDiscount(text);

      expect(result, 1.0);
    });

    test('multiple danger keywords in main section -> return 1.0', () {
      final prefix = 'x' * 210;
      final text = '${prefix}cho tôi số tài khoản và mã otp';
      final result = SafetyFilter.calculateSafetyDiscount(text);
      expect(result, 1.0);
    });

    test('all danger override keywords are detected', () {
      const dangerKeywords = [
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
      for (final keyword in dangerKeywords) {
        SafetyFilter.resetForTesting();
        final prefix = 'x' * 210;
        final text = '$prefix$keyword';
        final result = SafetyFilter.calculateSafetyDiscount(text);
        expect(
          result,
          1.0,
          reason: 'Danger keyword "$keyword" in main section should return 1.0',
        );
      }
    });
  });

  group('SafetyFilter — standard transactions', () {
    test('single transaction in full text -> discount applied (0.70)', () {
      final result = SafetyFilter.calculateSafetyDiscount(
        'chào bạn, tiền cơm tháng này bao nhiêu?',
      );

      expect(result, closeTo(0.70, 0.001));
    });

    test('transaction match is checked on full text (not just opening)', () {
      final prefix = 'x' * 210;
      final text = '${prefix}tiền cơm tháng này bao nhiêu?';
      final result = SafetyFilter.calculateSafetyDiscount(text);

      expect(result, closeTo(0.70, 0.001));
    });

    test('multiple transactions -> cumulative discount', () {
      const text = 'chuyển khoản tiền trọ và tiền cơm tháng này';
      final result = SafetyFilter.calculateSafetyDiscount(text);

      expect(result, closeTo(0.40, 0.001));
    });
  });

  group('SafetyFilter — combined casual + transaction', () {
    test('casual in opening + transaction -> combined discount', () {
      const text = 'alo, ăn cơm chưa? tiền cơm tháng này bao nhiêu?';
      final result = SafetyFilter.calculateSafetyDiscount(text);

      expect(result, closeTo(0.55, 0.001));
    });

    test('many casual + many transactions -> clamped to minMultiplier', () {
      const text =
          'ăn cơm chưa đi chơi không đang làm gì đấy thế à vậy hả '
          'mẹ đây bố đây con đang chút nữa gọi lại mua rau đi chợ. '
          'chuyển khoản tiền trọ tiền cơm chia tiền nốt chuyển tiền học phí trả tiền điện';
      final result = SafetyFilter.calculateSafetyDiscount(text);

      expect(result, closeTo(0.4, 0.001));
    });
  });

  group('SafetyFilter — minimum multiplier clamp', () {
    test('discount does not go below 0.4', () {
      const text =
          'ăn cơm chưa đi chơi không đang làm gì đấy thế à vậy hả '
          'mẹ đây bố đây con đang chút nữa gọi lại mua rau đi chợ. '
          'chuyển khoản tiền trọ tiền cơm chia tiền nốt chuyển tiền học phí trả tiền điện';
      final result = SafetyFilter.calculateSafetyDiscount(text);
      expect(result, greaterThanOrEqualTo(0.4));
    });

    test('empty text returns 1.0', () {
      final result = SafetyFilter.calculateSafetyDiscount('');
      expect(result, 1.0);
    });

    test('text with no keywords returns 1.0', () {
      final result = SafetyFilter.calculateSafetyDiscount(
        'xin chào hôm nay thời tiết đẹp nhỉ',
      );
      expect(result, 1.0);
    });
  });

  group('SafetyFilter — short text', () {
    test('short text with casual phrase in opening -> discount applied', () {
      final result = SafetyFilter.calculateSafetyDiscount('ăn cơm chưa');
      expect(result, closeTo(0.85, 0.001));
    });

    test('short text with danger keyword -> NO override (opening only)', () {
      final result = SafetyFilter.calculateSafetyDiscount('mã otp là gì');

      expect(result, 1.0);
    });

    test('short text with transaction -> discount applied', () {
      final result = SafetyFilter.calculateSafetyDiscount('tiền cơm tháng này');
      expect(result, closeTo(0.70, 0.001));
    });
  });

  group('SafetyFilter — loadConfig', () {
    test('loadConfig overrides defaults with JSON values', () async {
      await SafetyFilter.loadConfig(assetProvider: (_) => _testSafetyJson);

      final result = SafetyFilter.calculateSafetyDiscount('alo bạn ơi');

      expect(result, closeTo(0.70, 0.001));
    });

    test('loadConfig with invalid JSON -> keeps defaults', () async {
      await SafetyFilter.loadConfig(assetProvider: (_) => 'not valid json');

      final result = SafetyFilter.calculateSafetyDiscount('ăn cơm chưa');
      expect(result, closeTo(0.85, 0.001));
    });

    test('loadConfig with empty map -> keeps defaults', () async {
      await SafetyFilter.loadConfig(assetProvider: (_) => '{}');

      final result = SafetyFilter.calculateSafetyDiscount('ăn cơm chưa');
      expect(result, closeTo(0.85, 0.001));
    });

    test('loadConfig with custom minMultiplier', () async {
      final customJson = jsonEncode({
        'openingSectionLength': 200,
        'casualPhrases': ['ăn cơm chưa', 'đi chơi không', 'đang làm gì đấy'],
        'standardTransactions': [
          'tiền cơm',
          'trả tiền điện',
          'chuyển tiền học phí',
        ],
        'dangerOverrides': ['mã otp'],
        'casualReductionPerMatch': 0.15,
        'transactionReductionPerMatch': 0.30,
        'minMultiplier': 0.5,
      });
      await SafetyFilter.loadConfig(assetProvider: (_) => customJson);

      const text =
          'ăn cơm chưa đi chơi không đang làm gì đấy. '
          'tiền cơm trả tiền điện chuyển tiền học phí';
      final result = SafetyFilter.calculateSafetyDiscount(text);

      expect(result, closeTo(0.5, 0.001));
    });
  });

  group('SafetyFilter — Kotlin logic flow parity', () {
    test(
      'danger in main section DISABLES all discounts even with casual in opening',
      () {
        const prefix = 'ăn cơm chưa ';
        final filler = 'x' * (200 - prefix.length);
        final text = '$prefix${filler}số tài khoản ngân hàng';
        final result = SafetyFilter.calculateSafetyDiscount(text);
        expect(result, 1.0);
      },
    );

    test('discount order: casual (opening) then transaction (full text)', () {
      const text = 'ăn cơm chưa bạn, tiền cơm tháng này';
      final result = SafetyFilter.calculateSafetyDiscount(text);

      expect(result, closeTo(0.55, 0.001));
    });

    test(
      'transaction discount applies even when transaction is in opening',
      () {
        const text = 'tiền cơm tháng này bao nhiêu vậy bạn?';
        final result = SafetyFilter.calculateSafetyDiscount(text);

        expect(result, closeTo(0.70, 0.001));
      },
    );

    test('exact boundary: text of exactly 200 chars', () {
      final text = 'a' * 200;
      final result = SafetyFilter.calculateSafetyDiscount(text);
      expect(result, 1.0);
    });

    test('text of 201 chars -> main section has 1 char', () {
      final text = 'a' * 201;
      final result = SafetyFilter.calculateSafetyDiscount(text);
      expect(result, 1.0);
    });
  });

  group('SafetyFilter — negation-aware safety', () {
    test('phrase starting with negation word is not counted', () async {
      final json = jsonEncode({
        'casualPhrases': ['không phải ăn cơm', 'đi chơi'],
        'standardTransactions': ['tiền cơm'],
        'dangerOverrides': ['mã otp'],
      });
      await SafetyFilter.loadConfig(assetProvider: (_) => json);

      final result = SafetyFilter.calculateSafetyDiscount(
        'đi chơi nhé, không phải ăn cơm đâu',
      );

      expect(result, closeTo(0.85, 0.001));
    });

    test('non-negated phrases are counted normally', () async {
      final json = jsonEncode({
        'casualPhrases': ['đi chơi', 'ăn cơm'],
        'standardTransactions': ['tiền cơm'],
        'dangerOverrides': ['mã otp'],
      });
      await SafetyFilter.loadConfig(assetProvider: (_) => json);

      final result = SafetyFilter.calculateSafetyDiscount(
        'đi chơi và ăn cơm nhé',
      );

      expect(result, closeTo(0.70, 0.001));
    });
  });

  group('SafetyFilter — small amount awareness', () {
    setUpAll(() => SafetyFilter.resetForTesting());

    test('small amount with unit suffix gets extra discount', () {
      final result = SafetyFilter.calculateSafetyDiscount(
        'chào bạn, chuyển tiền cho bạn 2 triệu nhé',
      );

      expect(result, closeTo(0.90, 0.001));
    });

    test('large amount reduces safety discount', () {
      final prefix = 'x' * 210;
      final result = SafetyFilter.calculateSafetyDiscount(
        '${prefix}chuyển khoản 100 triệu nhé',
      );

      expect(result, 1.0);
    });

    test('no amount → no amount bonus', () {
      final result = SafetyFilter.calculateSafetyDiscount('tiền cơm tháng này');

      expect(result, closeTo(0.70, 0.001));
    });

    test('small VND amount gets extra discount', () {
      final result = SafetyFilter.calculateSafetyDiscount(
        'tiền cơm tháng này hết 500000 vnđ',
      );

      expect(result, closeTo(0.60, 0.001));
    });
  });

  group('SafetyFilter — relationship context', () {
    test('family term in opening gets extra discount', () {
      final result = SafetyFilter.calculateSafetyDiscount(
        'mẹ ơi, tiền cơm tháng này bao nhiêu?',
      );

      expect(result, closeTo(0.65, 0.001));
    });

    test('family term "bố" gets relationship bonus', () {
      final result = SafetyFilter.calculateSafetyDiscount(
        'bố gọi đây, chút nữa gọi lại nhé',
      );

      expect(result, closeTo(0.80, 0.001));
    });

    test('no family term → no relationship bonus', () {
      final result = SafetyFilter.calculateSafetyDiscount('tiền cơm tháng này');

      expect(result, closeTo(0.70, 0.001));
    });
  });

  group('SafetyFilter — combined features', () {
    test('casual + transaction + relationship + small amount', () async {
      SafetyFilter.resetForTesting();
      final result = SafetyFilter.calculateSafetyDiscount(
        'mẹ ơi, ăn cơm chưa? tiền cơm tháng này 2 triệu nhé',
      );

      expect(result, closeTo(0.40, 0.001));
    });

    test('amount bonus caps at minMultiplier', () {
      final result = SafetyFilter.calculateSafetyDiscount(
        'chuyển tiền học phí 2 triệu, trả tiền điện 1 triệu, tiền xăng 500000 vnđ',
      );

      expect(result, closeTo(0.4, 0.001));
    });
  });

  group('SafetyFilter — resetForTesting', () {
    test('resetForTesting restores defaults after loadConfig', () async {
      final customJson = jsonEncode({
        'openingSectionLength': 100,
        'casualPhrases': ['custom phrase'],
        'standardTransactions': ['custom transaction'],
        'dangerOverrides': ['custom danger'],
        'casualReductionPerMatch': 0.50,
        'transactionReductionPerMatch': 0.50,
        'minMultiplier': 0.1,
      });
      await SafetyFilter.loadConfig(assetProvider: (_) => customJson);

      SafetyFilter.resetForTesting();

      final result = SafetyFilter.calculateSafetyDiscount('ăn cơm chưa');
      expect(result, closeTo(0.85, 0.001));
    });
  });
}
