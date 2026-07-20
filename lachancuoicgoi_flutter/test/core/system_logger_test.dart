import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lachancuocgoi_flutter/core/system_logger.dart';

void main() {
  late DebugPrintCallback originalDebugPrint;

  setUpAll(() {
    originalDebugPrint = debugPrint;
    debugPrint = (message, {wrapWidth}) {};
  });

  tearDownAll(() {
    debugPrint = originalDebugPrint;
  });

  group('SystemLogger sensitive-data scrubber', () {
    test('redacts Gemini keys, bearer tokens and labelled user content', () {
      const raw =
          'apiKey=AIza1234567890abcdefghijklmnop; '
          'Authorization: Bearer secret.token.value\n'
          'transcript: vui lòng đọc mã OTP 123456';

      final safe = SystemLogger.scrubForLogging(raw);

      expect(safe, isNot(contains('AIza1234567890abcdefghijklmnop')));
      expect(safe, isNot(contains('secret.token.value')));
      expect(safe, isNot(contains('vui lòng đọc mã OTP')));
      expect(safe, contains('[REDACTED]'));
    });

    test('masks Vietnamese phone numbers and email addresses', () {
      const raw = 'caller=0912 345 678, email victim@example.com';

      final safe = SystemLogger.scrubForLogging(raw);

      expect(safe, isNot(contains('0912 345 678')));
      expect(safe, contains('***678'));
      expect(safe, isNot(contains('victim@example.com')));
    });

    test('never exports more than 500 entries', () {
      final logger = SystemLogger.instance;
      logger.clear();
      for (var index = 0; index < 505; index++) {
        logger.log(LogCategory.system, 'entry-$index');
      }

      final lines = logger.exportScrubbed().split('\n');
      expect(lines, hasLength(500));
      expect(lines.first, contains('entry-5'));
      expect(lines.last, contains('entry-504'));
    });
  });
}
