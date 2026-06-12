import 'package:flutter_test/flutter_test.dart';
import 'package:lachancuocgoi_flutter/data/alert_history_entry.dart';
import 'package:lachancuocgoi_flutter/data/call_history.dart';

/// Per-field round-trip test for every `CallHistory` column. Useful
/// when a new field is added or the encoding rule changes (e.g. when
/// `alert_history` was added in an earlier sprint).
///
/// Each test:
/// 1. Constructs a `CallHistory` with a unique sentinel value for one
///    field (and reasonable defaults for the rest).
/// 2. Calls `toMap(includeId: true)`.
/// 3. Calls `CallHistory.fromMap(map)`.
/// 4. Asserts that the field round-trips correctly.
void main() {
  CallHistory makeBaseline({
    int id = 1,
    String dateTime = '00:00:00 01/01/1970',
    String riskLevel = 'GREEN',
    String summary = 'baseline',
    String duration = '00:00',
    int flagCount = 0,
    String transcript = 'baseline transcript',
    String? audioPath = 'baseline/audio/path',
    String? analysisResult = '{"baseline":true}',
    String? analysisType = 'L1',
    String? alertHistory = '[]',
    String? recordingError,
  }) {
    return CallHistory(
      id: id,
      dateTime: dateTime,
      riskLevel: riskLevel,
      summary: summary,
      duration: duration,
      flagCount: flagCount,
      transcript: transcript,
      audioPath: audioPath,
      analysisResult: analysisResult,
      analysisType: analysisType,
      alertHistory: alertHistory,
      recordingError: recordingError,
    );
  }

  group('CallHistory per-field round-trip', () {
    test('id round-trips', () {
      final restored = CallHistory.fromMap(makeBaseline(id: 9999).toMap());
      expect(restored.id, 9999);
    });

    test('dateTime round-trips', () {
      final restored =
          CallHistory.fromMap(makeBaseline(dateTime: '13:45:01 02/02/2026').toMap());
      expect(restored.dateTime, '13:45:01 02/02/2026');
    });

    test('riskLevel round-trips for GREEN', () {
      final restored = CallHistory.fromMap(makeBaseline(riskLevel: 'GREEN').toMap());
      expect(restored.riskLevel, 'GREEN');
    });

    test('riskLevel round-trips for RED', () {
      final restored = CallHistory.fromMap(makeBaseline(riskLevel: 'RED').toMap());
      expect(restored.riskLevel, 'RED');
    });

    test('summary round-trips (Vietnamese)', () {
      final restored =
          CallHistory.fromMap(makeBaseline(summary: 'Cảnh báo lừa đảo').toMap());
      expect(restored.summary, 'Cảnh báo lừa đảo');
    });

    test('duration round-trips', () {
      final restored = CallHistory.fromMap(makeBaseline(duration: '12:34').toMap());
      expect(restored.duration, '12:34');
    });

    test('flagCount round-trips', () {
      final restored = CallHistory.fromMap(makeBaseline(flagCount: 7).toMap());
      expect(restored.flagCount, 7);
    });

    test('transcript round-trips (multiline)', () {
      const original = 'Line 1\nLine 2\nLine 3 — with em-dash';
      final restored = CallHistory.fromMap(makeBaseline(transcript: original).toMap());
      expect(restored.transcript, original);
    });

    test('audioPath null round-trips as null', () {
      final restored =
          CallHistory.fromMap(makeBaseline(audioPath: null).toMap());
      expect(restored.audioPath, isNull);
    });

    test('audioPath set round-trips', () {
      final restored =
          CallHistory.fromMap(makeBaseline(audioPath: '/tmp/a.wav').toMap());
      expect(restored.audioPath, '/tmp/a.wav');
    });

    test('analysisResult JSON round-trips', () {
      const json = '{"flags":["a","b"],"score":0.9}';
      final restored = CallHistory.fromMap(makeBaseline(analysisResult: json).toMap());
      expect(restored.analysisResult, json);
    });

    test('analysisType round-trips', () {
      final restored =
          CallHistory.fromMap(makeBaseline(analysisType: 'L2').toMap());
      expect(restored.analysisType, 'L2');
    });

    test('alertHistory (empty list) round-trips', () {
      final restored = CallHistory.fromMap(makeBaseline(alertHistory: '[]').toMap());
      expect(restored.alertHistory, '[]');
      expect(restored.getAlertHistoryList(), isEmpty);
    });

    test('alertHistory (non-empty list) round-trips', () {
      final entries = [
        const AlertHistoryEntry(
          timestamp: 0,
          analysisLevel: 'L1',
          riskLevel: 'RED',
          alertCount: 1,
          displayedReason: 'scam detected',
        ),
        const AlertHistoryEntry(
          timestamp: 5,
          analysisLevel: 'L1',
          riskLevel: 'GREEN',
          alertCount: 0,
          displayedReason: 'all clear',
        ),
      ];
      final json = CallHistory.alertHistoryToJson(entries);
      final restored = CallHistory.fromMap(makeBaseline(alertHistory: json).toMap());
      expect(restored.alertHistory, json);
      final restoredList = restored.getAlertHistoryList();
      expect(restoredList, hasLength(2));
      expect(restoredList[0].timestamp, 0);
      expect(restoredList[0].riskLevel, 'RED');
      expect(restoredList[1].timestamp, 5);
      expect(restoredList[1].displayedReason, 'all clear');
    });

    test('alertHistory null round-trips as null and yields empty list', () {
      final restored = CallHistory.fromMap(makeBaseline(alertHistory: null).toMap());
      expect(restored.alertHistory, isNull);
      expect(restored.getAlertHistoryList(), isEmpty);
    });

    test('alertHistory with invalid JSON yields empty list (not throw)', () {
      final restored = CallHistory.fromMap(makeBaseline(alertHistory: 'not json').toMap());
      expect(restored.getAlertHistoryList(), isEmpty);
    });
  });

  group('CallHistory — recordingError values (Sprint 1+2 B5)', () {
    for (final value in const [null, 'noAudio', 'sttFailed', 'partial', 'killed']) {
      test('recordingError=$value round-trips through toMap/fromMap', () {
        final history = makeBaseline(recordingError: value);
        final map = history.toMap();
        // Sanity: the column must be present (even if null) because the
        // schema v6 contract is "this column always exists".
        expect(map.containsKey('recordingError'), isTrue);
        expect(map['recordingError'], value);

        final restored = CallHistory.fromMap(map);
        expect(restored.recordingError, value);
      });
    }

    test('a non-sentinel value passes through (e.g. legacy data)', () {
      const sentinel = 'SENTINEL_VALUE_XYZ';
      final history = makeBaseline(recordingError: sentinel);
      final restored = CallHistory.fromMap(history.toMap());
      expect(restored.recordingError, sentinel);
    });

    test('recordingError: null is preserved as null, not empty string', () {
      final history = makeBaseline(recordingError: null);
      final restored = CallHistory.fromMap(history.toMap());
      expect(restored.recordingError, isNull);
    });
  });

  group('CallHistory — toMap invariants', () {
    test('includeId: true + id > 0 emits the id column', () {
      final map = makeBaseline(id: 17).toMap(includeId: true);
      expect(map['id'], 17);
    });

    test('includeId: false never emits the id column', () {
      final map = makeBaseline(id: 17).toMap(includeId: false);
      expect(map.containsKey('id'), isFalse);
    });

    test('id == 0 is omitted even with includeId: true (DAO contract)', () {
      final map = makeBaseline(id: 0).toMap(includeId: true);
      expect(map.containsKey('id'), isFalse);
    });

    test('alert_history column key (snake_case) is used, not alertHistory', () {
      final map = makeBaseline().toMap();
      // The column name in the SQL DDL is `alert_history` (snake_case),
      // not the Dart field name `alertHistory` (camelCase). This
      // protects against a future refactor that renames the SQL column.
      expect(map.containsKey('alert_history'), isTrue);
      expect(map.containsKey('alertHistory'), isFalse);
    });

    test('recordingError column is present even when null', () {
      final map = makeBaseline(recordingError: null).toMap();
      expect(map.containsKey('recordingError'), isTrue);
      expect(map['recordingError'], isNull);
    });
  });

  group('CallHistory — copyWith preserves unspecified fields', () {
    test('copyWith with no args returns equal instance', () {
      const a = CallHistory(
        id: 1,
        dateTime: 'd',
        riskLevel: 'RED',
        summary: 's',
        duration: '0s',
        flagCount: 3,
        transcript: 't',
        audioPath: 'p',
        analysisResult: 'r',
        analysisType: 'L1',
        alertHistory: '[]',
        recordingError: 'noAudio',
      );
      final b = a.copyWith();
      expect(b.id, a.id);
      expect(b.dateTime, a.dateTime);
      expect(b.riskLevel, a.riskLevel);
      expect(b.summary, a.summary);
      expect(b.duration, a.duration);
      expect(b.flagCount, a.flagCount);
      expect(b.transcript, a.transcript);
      expect(b.audioPath, a.audioPath);
      expect(b.analysisResult, a.analysisResult);
      expect(b.analysisType, a.analysisType);
      expect(b.alertHistory, a.alertHistory);
      expect(b.recordingError, a.recordingError);
    });

    test('copyWith updates only recordingError', () {
      const a = CallHistory(
        dateTime: 'd',
        riskLevel: 'GREEN',
        summary: 's',
        duration: '0s',
        flagCount: 0,
        transcript: 't',
        recordingError: null,
      );
      final b = a.copyWith(recordingError: 'killed');
      expect(b.recordingError, 'killed');
      // Every other field preserved.
      expect(b.dateTime, 'd');
      expect(b.riskLevel, 'GREEN');
      expect(b.summary, 's');
      expect(b.duration, '0s');
      expect(b.flagCount, 0);
      expect(b.transcript, 't');
    });
  });
}
