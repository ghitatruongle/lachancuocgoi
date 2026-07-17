import 'package:flutter_test/flutter_test.dart';
import 'package:lachancuocgoi_flutter/analysis/l2/g_detection/g_flash.dart';
import 'package:lachancuocgoi_flutter/analysis/l2/g_detection/g_models.dart';
import 'package:lachancuocgoi_flutter/analysis/l2/g_detection/sentence_matcher.dart';

void main() {
  group('SentenceMatcher', () {
    late SentenceMatcher matcher;

    setUp(() {
      matcher = SentenceMatcher(_testSentencesModel);
    });

    test('returns null for empty tokens', () {
      expect(matcher.match([]), isNull);
    });

    test('matches safe sentence and returns isSafe=true', () {
      final tokens = GFlash.tokenize('xin chao hom nay minh di an com nhe');
      final result = matcher.match(tokens);
      expect(result, isNotNull);
      expect(result!.isSafe, isTrue);
      expect(result.level, 0);
    });

    test('matches threat sentence and returns correct risk level', () {
      final tokens = GFlash.tokenize('vui long gui ma otp cho toi');
      final result = matcher.match(tokens);
      expect(result, isNotNull);
      expect(result!.isSafe, isFalse);
      expect(result.level, 3);
    });

    test('matches threat sentence with fuzzy skip (1 token gap)', () {
      // 'doc ma otp vua gui' in model. With skip, inserting 1 token can still match.
      // The trie allows skipping 1 token between consecutive trie nodes.
      final tokens = GFlash.tokenize('vui long doc ma otp vua gui cho toi');
      final result = matcher.match(tokens);
      expect(result, isNotNull);
      expect(result!.isSafe, isFalse);
      expect(result.level, 3);
    });

    test('returns null for completely unrelated tokens', () {
      final tokens = GFlash.tokenize('troi dep qua hom nay');
      final result = matcher.match(tokens);
      expect(result, isNull);
    });

    test('safe match takes priority over threat match', () {
      // If both safe and threat match, safe check runs first
      final model = RiskModelSentences.fromJson({
        'riskLevels': [
          {
            'level': 0,
            'sentences': ['hello world test'],
          },
          {
            'level': 3,
            'threats': {
              'TEST': ['hello world test'],
            },
          },
        ],
      });
      final m = SentenceMatcher(model);
      final tokens = GFlash.tokenize('hello world test');
      final result = m.match(tokens);
      expect(result, isNotNull);
      expect(result!.isSafe, isTrue);
    });

    test('matches longest sentence when multiple threats exist', () {
      final model = RiskModelSentences.fromJson({
        'riskLevels': [
          {
            'level': 2,
            'threats': {
              'URGENCY': ['chuyen tien'],
            },
          },
          {
            'level': 3,
            'threats': {
              'PII': ['gui ma otp cho chung toi'],
            },
          },
        ],
      });
      final m = SentenceMatcher(model);
      final tokens = GFlash.tokenize(
        'vui long gui ma otp cho chung toi de xac nhan',
      );
      final result = m.match(tokens);
      expect(result, isNotNull);
      expect(result!.level, 3);
    });

    test('empty model returns null', () {
      final empty = SentenceMatcher(const RiskModelSentences());
      expect(empty.match(GFlash.tokenize('xin chao')), isNull);
    });

    test('model with only green level matches safe', () {
      final model = RiskModelSentences.fromJson({
        'riskLevels': [
          {
            'level': 0,
            'sentences': ['anh oi giup em'],
          },
        ],
      });
      final m = SentenceMatcher(model);
      final result = m.match(GFlash.tokenize('anh oi giup em di'));
      expect(result, isNotNull);
      expect(result!.isSafe, isTrue);
    });

    test('threat level ordering: red checked before orange', () {
      final model = RiskModelSentences.fromJson({
        'riskLevels': [
          {
            'level': 1,
            'threats': {
              'LOW': ['nguy hiem'],
            },
          },
          {
            'level': 3,
            'threats': {
              'HIGH': ['nguy hiem cap'],
            },
          },
        ],
      });
      final m = SentenceMatcher(model);
      final tokens = GFlash.tokenize('tinh huong nguy hiem cap');
      final result = m.match(tokens);
      expect(result, isNotNull);
      expect(result!.level, 3); // Red checked first
    });
  });
}

final _testSentencesModel = RiskModelSentences.fromJson({
  'riskLevels': [
    {
      'level': 0,
      'sentences': ['xin chao hom nay minh di an com nhe'],
    },
    {
      'level': 3,
      'threats': {
        'PII': ['doc ma otp vua gui', 'gui ma otp cho toi'],
      },
    },
  ],
});
