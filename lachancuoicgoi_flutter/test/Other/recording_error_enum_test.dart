import 'package:flutter_test/flutter_test.dart';
import 'package:lachancuocgoi_flutter/data/call_history.dart';

void main() {
  group('RecordingError.fromWire', () {
    test('noAudio maps correctly', () {
      expect(RecordingError.fromWire('noAudio'), RecordingError.noAudio);
    });

    test('sttFailed maps correctly', () {
      expect(RecordingError.fromWire('sttFailed'), RecordingError.sttFailed);
    });

    test('killed maps correctly', () {
      expect(RecordingError.fromWire('killed'), RecordingError.killed);
    });

    test('partial maps correctly', () {
      expect(RecordingError.fromWire('partial'), RecordingError.partial);
    });

    test('null returns null', () {
      expect(RecordingError.fromWire(null), isNull);
    });

    test('empty string returns null', () {
      expect(RecordingError.fromWire(''), isNull);
    });

    test('unknown value returns null', () {
      expect(RecordingError.fromWire('UNKNOWN'), isNull);
    });

    test('case-sensitive: NoAudio returns null', () {
      expect(RecordingError.fromWire('NoAudio'), isNull);
    });

    test('case-sensitive: NOAUDIO returns null', () {
      expect(RecordingError.fromWire('NOAUDIO'), isNull);
    });

    test('case-sensitive: Killed returns null', () {
      expect(RecordingError.fromWire('Killed'), isNull);
    });
  });

  group('RecordingError.wireName', () {
    test('noAudio wireName is "noAudio"', () {
      expect(RecordingError.noAudio.wireName, 'noAudio');
    });

    test('sttFailed wireName is "sttFailed"', () {
      expect(RecordingError.sttFailed.wireName, 'sttFailed');
    });

    test('killed wireName is "killed"', () {
      expect(RecordingError.killed.wireName, 'killed');
    });

    test('partial wireName is "partial"', () {
      expect(RecordingError.partial.wireName, 'partial');
    });
  });

  group('CallHistory.recordingErrorEnum', () {
    test('returns correct enum for valid wire name', () {
      final h = CallHistory.withRecordingError(
        dateTime: '2025-01-01',
        riskLevel: 'GREEN',
        summary: 'test',
        duration: '01:00',
        flagCount: 0,
        transcript: '',
        recordingError: RecordingError.noAudio,
      );
      expect(h.recordingErrorEnum, RecordingError.noAudio);
      expect(h.recordingError, 'noAudio');
    });

    test('returns null when recordingError is null', () {
      const h = CallHistory(
        dateTime: '2025-01-01',
        riskLevel: 'GREEN',
        summary: 'test',
        duration: '01:00',
        flagCount: 0,
        transcript: '',
      );
      expect(h.recordingErrorEnum, isNull);
    });

    test('returns null for unrecognized wire string', () {
      const h = CallHistory(
        dateTime: '2025-01-01',
        riskLevel: 'GREEN',
        summary: 'test',
        duration: '01:00',
        flagCount: 0,
        transcript: '',
        recordingError: 'bogus',
      );
      expect(h.recordingErrorEnum, isNull);
    });
  });

  group('CallHistory.withRecordingError factory', () {
    test('converts enum to wire string', () {
      final h = CallHistory.withRecordingError(
        dateTime: '2025-01-01',
        riskLevel: 'RED',
        summary: 'scam',
        duration: '02:00',
        flagCount: 3,
        transcript: 'OTP',
        recordingError: RecordingError.sttFailed,
      );
      expect(h.recordingError, 'sttFailed');
      expect(h.recordingErrorEnum, RecordingError.sttFailed);
    });

    test('null enum produces null wire string', () {
      final h = CallHistory.withRecordingError(
        dateTime: '2025-01-01',
        riskLevel: 'GREEN',
        summary: 'ok',
        duration: '01:00',
        flagCount: 0,
        transcript: 'hello',
        recordingError: null,
      );
      expect(h.recordingError, isNull);
      expect(h.recordingErrorEnum, isNull);
    });
  });

  group('RecordingError round-trip via toMap/fromMap', () {
    test('all enum values survive round-trip', () {
      for (final error in RecordingError.values) {
        final h = CallHistory.withRecordingError(
          dateTime: '2025-01-01',
          riskLevel: 'GREEN',
          summary: 'test',
          duration: '01:00',
          flagCount: 0,
          transcript: '',
          recordingError: error,
        );
        final map = h.toMap();
        final restored = CallHistory.fromMap(map);
        expect(restored.recordingErrorEnum, error);
      }
    });

    test('null error survives round-trip', () {
      final h = CallHistory.withRecordingError(
        dateTime: '2025-01-01',
        riskLevel: 'GREEN',
        summary: 'test',
        duration: '01:00',
        flagCount: 0,
        transcript: '',
        recordingError: null,
      );
      final map = h.toMap();
      final restored = CallHistory.fromMap(map);
      expect(restored.recordingErrorEnum, isNull);
      expect(restored.recordingError, isNull);
    });
  });
}
