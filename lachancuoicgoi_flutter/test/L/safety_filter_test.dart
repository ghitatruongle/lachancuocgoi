import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:lachancuocgoi_flutter/analysis/l2/safety/safety_filter.dart';

/// Safety keywords JSON (subset used for testing loadConfig).
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

  // ─── Parity: config values match Kotlin ────────────────────────────────

  group('SafetyFilter — default config parity', () {
    test('openingSectionLength defaults to 200 (matches Kotlin)', () {
      // After resetForTesting, defaults should be in place.
      // Test indirectly: a text exactly 200 chars should be all opening.
      final text = 'a' * 200; // no keywords -> 1.0
      expect(SafetyFilter.calculateSafetyDiscount(text), 1.0);
    });

    test('casualReductionPerMatch defaults to 0.15', () {
      // One casual phrase in opening -> 1.0 - 0.15 = 0.85
      final result = SafetyFilter.calculateSafetyDiscount('ăn cơm chưa bạn nhé');
      expect(result, closeTo(0.85, 0.001));
    });

    test('transactionReductionPerMatch defaults to 0.30', () {
      // One transaction in full text -> 1.0 - 0.30 = 0.70
      final result = SafetyFilter.calculateSafetyDiscount('tiền cơm tháng này');
      expect(result, closeTo(0.70, 0.001));
    });

    test('minMultiplier defaults to 0.4', () {
      // Many casual phrases + many transactions to push below 0.4
      const text = 'ăn cơm chưa đi chơi không đang làm gì đấy thế à vậy hả '
          'mẹ đây bố đây con đang chút nữa gọi lại mua rau đi chợ. '
          'chuyển khoản tiền trọ tiền cơm chia tiền nốt chuyển tiền học phí trả tiền điện';
      final result = SafetyFilter.calculateSafetyDiscount(text);
      // 11 casual * 0.15 = 1.65 reduction, 5 transactions * 0.30 = 1.50 reduction
      // Total reduction = 3.15, so multiplier = 1.0 - 3.15 = -2.15 -> clamped to 0.4
      expect(result, closeTo(0.4, 0.001));
    });
  });

  // ─── Casual phrases in opening section ─────────────────────────────────

  group('SafetyFilter — casual phrases in opening section', () {
    test('single casual phrase in opening -> discount applied (0.85)', () {
      final result = SafetyFilter.calculateSafetyDiscount('alo, ăn cơm chưa bạn?');
      expect(result, closeTo(0.85, 0.001));
    });

    test('two casual phrases in opening -> discount applied (0.70)', () {
      final result = SafetyFilter.calculateSafetyDiscount(
        'alo, ăn cơm chưa, đang làm gì đấy vậy?',
      );
      // 2 casual * 0.15 = 0.30 reduction -> 0.70
      expect(result, closeTo(0.70, 0.001));
    });

    test('case insensitive match for casual phrases', () {
      final result = SafetyFilter.calculateSafetyDiscount('ALO, ĂN CƠM CHƯA?');
      // Should still match because text is lowercased
      expect(result, closeTo(0.85, 0.001));
    });
  });

  // ─── Casual phrases AFTER opening section ──────────────────────────────

  group('SafetyFilter — casual phrases after opening section', () {
    test('casual phrase only in main section -> NO discount', () {
      // Build a transcript where the casual phrase appears after position 200
      final prefix = 'x' * 210; // 210 chars of filler
      final text = '$prefix ăn cơm chưa bạn nhé';
      final result = SafetyFilter.calculateSafetyDiscount(text);
      // Casual phrase is at position 210+, which is in the main section.
      // Opening section has no casual phrases. Should return 1.0.
      expect(result, 1.0);
    });

    test('casual phrase in opening + danger in main -> return 1.0', () {
      // Opening has casual phrase, but main has danger keyword
      const prefix = 'ăn cơm chưa ';
      final filler = 'x' * (200 - prefix.length);
      final text = '$prefix${filler}mã otp của bạn là gì?';
      final result = SafetyFilter.calculateSafetyDiscount(text);
      // Danger in main overrides everything
      expect(result, 1.0);
    });
  });

  // ─── Danger keywords in main section ───────────────────────────────────

  group('SafetyFilter — danger keywords in main section', () {
    test('danger keyword in main section -> return 1.0', () {
      final prefix = 'x' * 210;
      final text = '${prefix}số tài khoản của bạn là gì?';
      final result = SafetyFilter.calculateSafetyDiscount(text);
      expect(result, 1.0);
    });

    test('danger keyword in opening section only -> NO override', () {
      // Danger keyword "mã otp" is in the opening section (< 200 chars)
      // but the check is only on the main section
      const text = 'mã otp là gì vậy bạn?';
      final result = SafetyFilter.calculateSafetyDiscount(text);
      // Danger check only looks at main section (after 200 chars).
      // This text is < 200 chars, so main section is empty.
      // No danger in main -> no override.
      // But there are no casual phrases or transactions either -> 1.0
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
        'số tài khoản', 'mã otp', 'chuyển khoản', 'mật khẩu',
        'cccd', 'cmnd', 'công an', 'kiểm sát', 'tải ứng dụng',
        'cài app', 'link', 'bắt cóc', 'tống tiền',
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

  // ─── Standard transactions ─────────────────────────────────────────────

  group('SafetyFilter — standard transactions', () {
    test('single transaction in full text -> discount applied (0.70)', () {
      final result = SafetyFilter.calculateSafetyDiscount(
        'chào bạn, tiền cơm tháng này bao nhiêu?',
      );
      // 1 transaction * 0.30 = 0.30 reduction -> 0.70
      expect(result, closeTo(0.70, 0.001));
    });

    test('transaction match is checked on full text (not just opening)', () {
      // Put transaction keyword after position 200
      final prefix = 'x' * 210;
      final text = '${prefix}tiền cơm tháng này bao nhiêu?';
      final result = SafetyFilter.calculateSafetyDiscount(text);
      // Transaction is in main section, but transactions are checked on full text
      // 1 transaction * 0.30 = 0.30 reduction -> 0.70
      expect(result, closeTo(0.70, 0.001));
    });

    test('multiple transactions -> cumulative discount', () {
      const text = 'chuyển khoản tiền trọ và tiền cơm tháng này';
      final result = SafetyFilter.calculateSafetyDiscount(text);
      // 2 transactions * 0.30 = 0.60 reduction -> 0.40
      expect(result, closeTo(0.40, 0.001));
    });
  });

  // ─── Combined: casual + transaction ────────────────────────────────────

  group('SafetyFilter — combined casual + transaction', () {
    test('casual in opening + transaction -> combined discount', () {
      const text = 'alo, ăn cơm chưa? tiền cơm tháng này bao nhiêu?';
      final result = SafetyFilter.calculateSafetyDiscount(text);
      // 1 casual * 0.15 = 0.15, 1 transaction * 0.30 = 0.30
      // Total reduction = 0.45 -> 0.55
      expect(result, closeTo(0.55, 0.001));
    });

    test('many casual + many transactions -> clamped to minMultiplier', () {
      const text = 'ăn cơm chưa đi chơi không đang làm gì đấy thế à vậy hả '
          'mẹ đây bố đây con đang chút nữa gọi lại mua rau đi chợ. '
          'chuyển khoản tiền trọ tiền cơm chia tiền nốt chuyển tiền học phí trả tiền điện';
      final result = SafetyFilter.calculateSafetyDiscount(text);
      // 11 casual * 0.15 = 1.65, 5 transactions * 0.30 = 1.50
      // Total = 3.15 reduction -> clamped to 0.4
      expect(result, closeTo(0.4, 0.001));
    });
  });

  // ─── Minimum multiplier clamp ──────────────────────────────────────────

  group('SafetyFilter — minimum multiplier clamp', () {
    test('discount does not go below 0.4', () {
      // Construct a text with many matches to push below 0.4
      const text = 'ăn cơm chưa đi chơi không đang làm gì đấy thế à vậy hả '
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

  // ─── Short text (less than openingSectionLength) ───────────────────────

  group('SafetyFilter — short text', () {
    test('short text with casual phrase in opening -> discount applied', () {
      final result = SafetyFilter.calculateSafetyDiscount('ăn cơm chưa');
      expect(result, closeTo(0.85, 0.001));
    });

    test('short text with danger keyword -> NO override (opening only)', () {
      // Text < 200 chars, so main section is empty
      final result = SafetyFilter.calculateSafetyDiscount('mã otp là gì');
      // Danger check: main section is empty -> no danger in main
      // No casual phrases or transactions -> 1.0
      expect(result, 1.0);
    });

    test('short text with transaction -> discount applied', () {
      final result = SafetyFilter.calculateSafetyDiscount('tiền cơm tháng này');
      expect(result, closeTo(0.70, 0.001));
    });
  });

  // ─── loadConfig ────────────────────────────────────────────────────────

  group('SafetyFilter — loadConfig', () {
    test('loadConfig overrides defaults with JSON values', () async {
      await SafetyFilter.loadConfig(assetProvider: (_) => _testSafetyJson);
      // After loading, "alo" and "ơi" should both be casual phrases
      final result = SafetyFilter.calculateSafetyDiscount('alo bạn ơi');
      // 2 casual matches ("alo", "ơi") * 0.15 = 0.30 reduction -> 0.70
      expect(result, closeTo(0.70, 0.001));
    });

    test('loadConfig with invalid JSON -> keeps defaults', () async {
      await SafetyFilter.loadConfig(assetProvider: (_) => 'not valid json');
      // Defaults should still be in place
      final result = SafetyFilter.calculateSafetyDiscount('ăn cơm chưa');
      expect(result, closeTo(0.85, 0.001));
    });

    test('loadConfig with empty map -> keeps defaults', () async {
      await SafetyFilter.loadConfig(assetProvider: (_) => '{}');
      // Empty JSON -> no fields to update -> defaults remain
      final result = SafetyFilter.calculateSafetyDiscount('ăn cơm chưa');
      expect(result, closeTo(0.85, 0.001));
    });

    test('loadConfig with custom minMultiplier', () async {
      final customJson = jsonEncode({
        'openingSectionLength': 200,
        'casualPhrases': ['ăn cơm chưa', 'đi chơi không', 'đang làm gì đấy'],
        'standardTransactions': ['tiền cơm', 'trả tiền điện', 'chuyển tiền học phí'],
        'dangerOverrides': ['mã otp'],
        'casualReductionPerMatch': 0.15,
        'transactionReductionPerMatch': 0.30,
        'minMultiplier': 0.5, // custom
      });
      await SafetyFilter.loadConfig(assetProvider: (_) => customJson);

      // Push below 0.5: 3 casual (0.45) + 3 transactions (0.90) = 1.35 reduction
      const text = 'ăn cơm chưa đi chơi không đang làm gì đấy. '
          'tiền cơm trả tiền điện chuyển tiền học phí';
      final result = SafetyFilter.calculateSafetyDiscount(text);
      // 1.0 - 1.35 = -0.35 -> clamped to 0.5
      expect(result, closeTo(0.5, 0.001));
    });
  });

  // ─── Parity: Kotlin logic flow verification ────────────────────────────

  group('SafetyFilter — Kotlin logic flow parity', () {
    test(
      'danger in main section DISABLES all discounts even with casual in opening',
      () {
        // Opening: casual phrase. Main: danger keyword.
        // Kotlin: hasDangerInMain -> return 1.0 (before any discount)
        const prefix = 'ăn cơm chưa ';
        final filler = 'x' * (200 - prefix.length);
        final text = '$prefix${filler}số tài khoản ngân hàng';
        final result = SafetyFilter.calculateSafetyDiscount(text);
        expect(result, 1.0);
      },
    );

    test('discount order: casual (opening) then transaction (full text)', () {
      // Verify the discount is cumulative: casual first, then transaction
      const text = 'ăn cơm chưa bạn, tiền cơm tháng này';
      final result = SafetyFilter.calculateSafetyDiscount(text);
      // 1 casual * 0.15 = 0.15
      // 1 transaction * 0.30 = 0.30
      // Total = 0.45 reduction -> 0.55
      expect(result, closeTo(0.55, 0.001));
    });

    test('transaction discount applies even when transaction is in opening', () {
      // "tiền cơm" appears in opening section
      const text = 'tiền cơm tháng này bao nhiêu vậy bạn?';
      final result = SafetyFilter.calculateSafetyDiscount(text);
      // Transaction is checked on full text -> 1 match -> 0.30 reduction
      expect(result, closeTo(0.70, 0.001));
    });

    test('exact boundary: text of exactly 200 chars', () {
      // Text is exactly 200 chars -> main section is empty
      final text = 'a' * 200;
      final result = SafetyFilter.calculateSafetyDiscount(text);
      expect(result, 1.0);
    });

    test('text of 201 chars -> main section has 1 char', () {
      // 201 chars -> main section is 'a' (1 char)
      final text = 'a' * 201;
      final result = SafetyFilter.calculateSafetyDiscount(text);
      expect(result, 1.0);
    });
  });

  // ─── resetForTesting ───────────────────────────────────────────────────

  group('SafetyFilter — resetForTesting', () {
    test('resetForTesting restores defaults after loadConfig', () async {
      // Load custom config
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

      // Reset
      SafetyFilter.resetForTesting();

      // Verify defaults are back
      final result = SafetyFilter.calculateSafetyDiscount('ăn cơm chưa');
      expect(result, closeTo(0.85, 0.001)); // 1 casual * 0.15
    });
  });
}
