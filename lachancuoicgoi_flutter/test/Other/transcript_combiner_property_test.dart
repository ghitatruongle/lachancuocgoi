@Tags(['perf'])
library;

// ignore_for_file: invalid_annotation_target
import 'dart:math';

import 'package:flutter_test/flutter_test.dart';

/// Property-style tests for the `combineTranscriptSources` algorithm
/// (Sprint 2 / C6). The production function lives in
/// `lib/services/transcript_combiner.dart` but that file currently
/// does not compile because the `TranscriptUpdate` class it depends on
/// has not landed yet. We pin the algorithm here as a reference and
/// run property tests against the pinned copy.
///
/// The captured rule:
///   - pick the longer of `stt` / `accessibility` as the cumulative
///     base. Ties go to `stt` (>= comparison).
///   - if `partial` is non-blank AND cumulative is non-blank, append
///     `partial` on a new line.
///   - return `null` when the composed result is blank.
///   - return `TranscriptUpdate(text: composed, isPartial: partial
///     is non-blank)`.
void main() {
  group('combineTranscriptSources — property-style sweep', () {
    test('100 random Vietnamese-like inputs respect the invariants', () {
      final rng = Random(42);
      const alphabet = 'aáàảãạăắằẳẵặâấầẩẫậeéèẻẽẹêếềểễệ'
          'iíìỉĩịoóòỏõọôốồổỗộơớờởỡợuúùủũụưứừửữự'
          'yýỳỷỹỵđbcdghklmnpqrstvx '
          '.,?!"';

      String genWord() {
        final len = 1 + rng.nextInt(8);
        return List.generate(
          len,
          (_) => alphabet[rng.nextInt(alphabet.length)],
        ).join();
      }

      var nonNullCount = 0;
      var partialFlagCount = 0;

      for (var i = 0; i < 100; i++) {
        final stt = genWord();
        final partial = genWord();
        final accessibility = genWord();

        final result = combineTranscriptSources(
          stt: stt,
          partial: partial,
          accessibility: accessibility,
        );

        final anyNonBlank = stt.trim().isNotEmpty ||
            partial.trim().isNotEmpty ||
            accessibility.trim().isNotEmpty;

        if (anyNonBlank) {
          expect(result, isNotNull, reason: 'iter=$i expected non-null');
          nonNullCount++;
        } else {
          expect(result, isNull, reason: 'iter=$i expected null');
        }

        if (result != null) {
          // The text must be one of: stt, accessibility, "<stt>\n<partial>",
          // or "<accessibility>\n<partial>".
          final composed = result.text;
          final expected1 = stt;
          final expected2 = accessibility;
          final expected3 = '$stt\n$partial';
          final expected4 = '$accessibility\n$partial';
          final ok = composed == expected1 ||
              composed == expected2 ||
              composed == expected3 ||
              composed == expected4;
          expect(ok, isTrue, reason: 'iter=$i text="$composed"');

          if (partial.trim().isNotEmpty) {
            expect(result.isPartial, isTrue, reason: 'iter=$i');
            partialFlagCount++;
          } else {
            expect(result.isPartial, isFalse, reason: 'iter=$i');
          }
        }
      }

      // Sanity-check that the loop actually exercised both branches.
      expect(nonNullCount, greaterThan(50));
      expect(partialFlagCount, greaterThan(0));
    });
  });

  group('combineTranscriptSources — deterministic corner cases', () {
    test('returns null when all sources are empty', () {
      expect(
        combineTranscriptSources(stt: '', partial: '', accessibility: ''),
        isNull,
      );
    });

    test('returns null when all sources are whitespace', () {
      expect(
        combineTranscriptSources(
          stt: '   ',
          partial: '\t',
          accessibility: '\n',
        ),
        isNull,
      );
    });

    test('returns non-null TranscriptUpdate for stt-only input', () {
      final r = combineTranscriptSources(
        stt: 'hello',
        partial: '',
        accessibility: '',
      );
      expect(r, isNotNull);
      expect(r!.text, 'hello');
      expect(r.isPartial, isFalse);
    });

    test('partial only and cumulative blank → null (Kotlin parity)', () {
      // The Kotlin combine in BackgroundMonitoringService only emits a
      // partial when there is already a cumulative transcript. A
      // refactor that changes this would break the parity contract.
      expect(
        combineTranscriptSources(
          stt: '',
          partial: 'wor',
          accessibility: '',
        ),
        isNull,
      );
    });

    test('accessibility wins when it is the longest source', () {
      final r = combineTranscriptSources(
        stt: 'hi',
        partial: '',
        accessibility: 'hello world',
      );
      expect(r!.text, 'hello world');
    });

    test('stt wins when stt is the longest source', () {
      final r = combineTranscriptSources(
        stt: 'hello world again',
        partial: '',
        accessibility: 'hi',
      );
      expect(r!.text, 'hello world again');
    });

    test('ties on length go to stt (>= comparison)', () {
      final r = combineTranscriptSources(
        stt: 'equal',
        partial: '',
        accessibility: 'equal',
      );
      expect(r!.text, 'equal');
    });

    test('partial appended to cumulative on a new line', () {
      final r = combineTranscriptSources(
        stt: 'hello',
        partial: 'wor',
        accessibility: '',
      );
      expect(r!.text, 'hello\nwor');
      expect(r.isPartial, isTrue);
    });
  });
}

// ── Pinned test fixtures ──────────────────────────────────────────────

class TranscriptUpdate {
  const TranscriptUpdate({required this.text, required this.isPartial});
  final String text;
  final bool isPartial;
}

bool _isBlank(String s) => s.trim().isEmpty;

TranscriptUpdate? combineTranscriptSources({
  required String stt,
  required String partial,
  required String accessibility,
}) {
  final String cumulative;
  if (!_isBlank(stt) && !_isBlank(accessibility)) {
    cumulative = stt.length >= accessibility.length ? stt : accessibility;
  } else if (!_isBlank(stt)) {
    cumulative = stt;
  } else if (!_isBlank(accessibility)) {
    cumulative = accessibility;
  } else {
    cumulative = '';
  }

  final String composed;
  if (!_isBlank(partial) && !_isBlank(cumulative)) {
    composed = '$cumulative\n$partial';
  } else {
    composed = cumulative;
  }

  if (_isBlank(composed)) return null;
  return TranscriptUpdate(text: composed, isPartial: !_isBlank(partial));
}
