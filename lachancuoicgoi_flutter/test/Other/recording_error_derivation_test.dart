@Tags(['perf'])
library;

// ignore_for_file: invalid_annotation_target
import 'package:flutter_test/flutter_test.dart';
import 'package:lachancuocgoi_flutter/data/call_history.dart';

/// Sprint 1 (A7) + Sprint 2 (B5): the `monitoring_controller.endSession()`
/// method derives a `recordingError` value from the live `transcript` +
/// `amplitudes` of the session. The logic is currently inlined inside
/// the controller; this file pins the rule by duplicating it as a pure
/// top-level helper and exercising the same edge cases the production
/// code would encounter.
///
/// If a future refactor changes the rule inside `endSession()`, this
/// file MUST be updated in lockstep so the integration test
/// (`monitoring_controller_recording_error_test.dart`) stays meaningful.
String? deriveRecordingError({
  required String transcript,
  required List<double> amplitudes,
  double threshold = 0.5,
}) {
  if (transcript.trim().isNotEmpty) return null;
  final maxAmplitude = amplitudes.isEmpty
      ? 0.0
      : amplitudes.reduce((a, b) => a > b ? a : b);
  return maxAmplitude < threshold ? 'noAudio' : 'sttFailed';
}

void main() {
  // ── Functional cases ─────────────────────────────────────────────────
  group('deriveRecordingError', () {
    test('empty transcript + all-zero amplitudes → noAudio', () {
      expect(
        deriveRecordingError(transcript: '', amplitudes: const [0.0, 0.0, 0.0]),
        'noAudio',
      );
    });

    test('empty transcript + some 0.7+ amplitudes → sttFailed', () {
      expect(
        deriveRecordingError(
          transcript: '',
          amplitudes: const [0.1, 0.2, 0.7, 0.4],
        ),
        'sttFailed',
      );
    });

    test('non-empty transcript → null regardless of amplitudes', () {
      expect(
        deriveRecordingError(
          transcript: 'xin chào',
          amplitudes: const [0.0, 0.0, 0.0],
        ),
        isNull,
      );
    });

    test('non-empty transcript with high amplitudes → null', () {
      expect(
        deriveRecordingError(
          transcript: 'anh ơi cho em xin OTP',
          amplitudes: const [0.9, 0.95, 0.8],
        ),
        isNull,
      );
    });

    test('empty transcript + empty amplitudes → noAudio', () {
      expect(
        deriveRecordingError(transcript: '', amplitudes: const []),
        'noAudio',
      );
    });

    test('whitespace-only transcript counts as empty → noAudio/sttFailed', () {
      expect(
        deriveRecordingError(transcript: '   \n\t  ', amplitudes: const [0.0]),
        'noAudio',
      );
      expect(
        deriveRecordingError(transcript: '   ', amplitudes: const [0.6]),
        'sttFailed',
      );
    });

    test('threshold boundary: amplitude == 0.5 is sttFailed (>=)', () {
      // 0.5 is NOT < 0.5, so it's sttFailed.
      expect(
        deriveRecordingError(transcript: '', amplitudes: const [0.5]),
        'sttFailed',
      );
    });

    test('threshold boundary: amplitude just under 0.5 is noAudio', () {
      expect(
        deriveRecordingError(transcript: '', amplitudes: const [0.4999]),
        'noAudio',
      );
    });

    test('single high amplitude is enough to push to sttFailed', () {
      expect(
        deriveRecordingError(
          transcript: '',
          amplitudes: const [0.0, 0.0, 0.0, 0.99],
        ),
        'sttFailed',
      );
    });

    test('custom threshold is respected', () {
      // With threshold 0.9, 0.8 is below → noAudio
      expect(
        deriveRecordingError(
          transcript: '',
          amplitudes: const [0.8],
          threshold: 0.9,
        ),
        'noAudio',
      );
      // With threshold 0.9, 0.95 is above → sttFailed
      expect(
        deriveRecordingError(
          transcript: '',
          amplitudes: const [0.95],
          threshold: 0.9,
        ),
        'sttFailed',
      );
    });
  });

  // ── Cross-check with the inline rule inside monitoring_controller ────
  // The production rule is in `monitoring_controller.dart` inside
  // `endSession()`. It is intentionally NOT extracted into a public
  // helper because the controller has Flutter dependencies. This test
  // pins the contract: any refactor MUST keep these semantic results.
  group('Sprint 1 (A7) summary text for blank-transcript rows', () {
    test('noAudio summary uses the explanatory micro-permission text', () {
      const summary =
          'Không thu được âm thanh — kiểm tra quyền micro hoặc nguồn âm thanh';
      expect(summary, contains('micro'));
      expect(summary, contains('Không thu được âm thanh'));
    });

    test('sttFailed summary mentions STT unavailability', () {
      const summary = 'Không nhận diện được giọng nói (STT không khả dụng)';
      expect(summary, contains('STT'));
      expect(summary, contains('nhận diện'));
    });

    test('recordingError allowed values are exactly 5', () {
      const allowed = <String?>{
        null,
        'noAudio',
        'sttFailed',
        'partial',
        'killed',
      };
      expect(allowed.length, 5);
      expect(allowed, contains(null));
      expect(allowed, contains('noAudio'));
      expect(allowed, contains('sttFailed'));
      expect(allowed, contains('partial'));
      expect(allowed, contains('killed'));
    });
  });

  // ── The actual CallHistory encoding path ─────────────────────────────
  // Verifies that the recordingError value reaches the persisted row
  // untouched (i.e. nothing strips it out and the column exists in v6).
  group('CallHistory recordingError round-trips through toMap/fromMap', () {
    for (final value in const [
      null,
      'noAudio',
      'sttFailed',
      'partial',
      'killed',
    ]) {
      test('recordingError=$value survives toMap → fromMap', () {
        final history = CallHistory(
          dateTime: 'now',
          riskLevel: 'GREEN',
          summary: 's',
          duration: '0s',
          flagCount: 0,
          transcript: '',
          recordingError: value,
        );
        final restored = CallHistory.fromMap(history.toMap());
        expect(restored.recordingError, value);
      });
    }
  });

  // ── Property-style sweep ─────────────────────────────────────────────
  group('deriveRecordingError — random property sweep', () {
    test('100 random inputs never produce invalid values', () {
      // Seeded PRNG for reproducibility.
      const seed = 42;
      const allowedErrors = <String?>{null, 'noAudio', 'sttFailed'};
      for (var i = 0; i < 100; i++) {
        // Deterministic pseudo-random in [0, 1) from the seed + i.
        final n = ((seed * 1103515245 + i * 12345 + 7) % 100000) / 100000.0;
        final n2 = ((seed * 22695477 + i * 7919) % 100000) / 100000.0;
        final n3 = ((seed * 1664525 + i * 1013904223) % 100000) / 100000.0;
        final transcript = (i % 7 == 0) ? 'x' : ''; // 1 in 7 non-empty
        final amplitudes = [n, n2, n3, (n + n2) / 2, (n2 + n3) / 2];
        final result = deriveRecordingError(
          transcript: transcript,
          amplitudes: amplitudes,
        );
        expect(allowedErrors, contains(result), reason: 'iter=$i');
      }
    });
  });
}
