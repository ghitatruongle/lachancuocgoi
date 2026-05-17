import 'package:flutter_test/flutter_test.dart';
import 'package:lachancuocgoi_flutter/data/call_history.dart';
import 'package:lachancuocgoi_flutter/data/alert_history_entry.dart';

void main() {
  group('CallHistory — copyWith', () {
    test('copies all fields correctly', () {
      const original = CallHistory(
        id: 1,
        dateTime: '10:00:00 01/01/2026',
        riskLevel: 'GREEN',
        summary: 'An toàn',
        duration: '5s',
        flagCount: 0,
        transcript: 'Xin chào',
        audioPath: '/path/to/audio.wav',
        analysisResult: '{}',
        analysisType: 'L1',
        alertHistory: '[]',
      );

      final copy = original.copyWith(
        riskLevel: 'RED',
        summary: 'Nguy hiểm',
        flagCount: 3,
      );

      expect(copy.id, 1);
      expect(copy.dateTime, '10:00:00 01/01/2026');
      expect(copy.riskLevel, 'RED');
      expect(copy.summary, 'Nguy hiểm');
      expect(copy.duration, '5s');
      expect(copy.flagCount, 3);
      expect(copy.transcript, 'Xin chào');
      expect(copy.audioPath, '/path/to/audio.wav');
      expect(copy.analysisResult, '{}');
      expect(copy.analysisType, 'L1');
      expect(copy.alertHistory, '[]');
    });
  });

  group('CallHistory — toMap and fromMap', () {
    test('round-trips through toMap and fromMap', () {
      const original = CallHistory(
        id: 42,
        dateTime: '15:30:00 12/06/2026',
        riskLevel: 'ORANGE',
        summary: 'Có nguy cơ',
        duration: '120s',
        flagCount: 5,
        transcript: 'Tôi là công an...',
        audioPath: '/audio.wav',
        analysisResult: '{"level": "orange"}',
        analysisType: 'L2',
        alertHistory: '[{"riskLevel":"ORANGE"}]',
      );

      final map = original.toMap();
      final restored = CallHistory.fromMap(map);

      expect(restored.id, 42);
      expect(restored.dateTime, '15:30:00 12/06/2026');
      expect(restored.riskLevel, 'ORANGE');
      expect(restored.summary, 'Có nguy cơ');
      expect(restored.duration, '120s');
      expect(restored.flagCount, 5);
      expect(restored.transcript, 'Tôi là công an...');
      expect(restored.audioPath, '/audio.wav');
      expect(restored.analysisResult, '{"level": "orange"}');
      expect(restored.analysisType, 'L2');
    });

    test('toMap excludes id when not includeId', () {
      const history = CallHistory(
        id: 0,
        dateTime: 'now',
        riskLevel: 'GREEN',
        summary: 'safe',
        duration: '0s',
        flagCount: 0,
        transcript: '',
      );

      final map = history.toMap(includeId: false);
      expect(map.containsKey('id'), isFalse);
    });

    test('toMap excludes id when id is 0', () {
      const history = CallHistory(
        id: 0,
        dateTime: 'now',
        riskLevel: 'GREEN',
        summary: 'safe',
        duration: '0s',
        flagCount: 0,
        transcript: '',
      );

      final map = history.toMap(includeId: true);
      // id == 0, so it should be excluded
      expect(map.containsKey('id'), isFalse);
    });

    test('toMap includes id when id > 0 and includeId is true', () {
      const history = CallHistory(
        id: 5,
        dateTime: 'now',
        riskLevel: 'GREEN',
        summary: 'safe',
        duration: '0s',
        flagCount: 0,
        transcript: '',
      );

      final map = history.toMap();
      expect(map['id'], 5);
    });

    test('fromMap handles missing fields with defaults', () {
      final restored = CallHistory.fromMap(<String, Object?>{});

      expect(restored.id, 0);
      expect(restored.dateTime, '');
      expect(restored.riskLevel, 'GREEN');
      expect(restored.summary, '');
      expect(restored.duration, '');
      expect(restored.flagCount, 0);
      expect(restored.transcript, '');
      expect(restored.audioPath, isNull);
      expect(restored.analysisResult, isNull);
      expect(restored.analysisType, isNull);
      expect(restored.alertHistory, isNull);
    });
  });

  group('CallHistory — alertHistory parsing', () {
    test('parses valid alert history JSON', () {
      final alerts = [
        AlertHistoryEntry(
          timestamp: DateTime(2026, 5, 5, 10, 0, 0).millisecondsSinceEpoch,
          analysisLevel: 'L2',
          riskLevel: 'RED',
          alertCount: 1,
          displayedReason: 'OTP detected',
        ),
        AlertHistoryEntry(
          timestamp: DateTime(2026, 5, 5, 10, 1, 0).millisecondsSinceEpoch,
          analysisLevel: 'L2',
          riskLevel: 'ORANGE',
          alertCount: 2,
          displayedReason: 'Chuyển tiền',
        ),
      ];

      final history = CallHistory(
        dateTime: 'now',
        riskLevel: 'RED',
        summary: 'test',
        duration: '60s',
        flagCount: 2,
        transcript: 'content',
        alertHistory: CallHistory.alertHistoryToJson(alerts),
      );

      final parsed = history.getAlertHistoryList();
      expect(parsed, hasLength(2));
      expect(parsed[0].riskLevel, 'RED');
      expect(parsed[1].riskLevel, 'ORANGE');
    });

    test('returns empty list for null alertHistory', () {
      const history = CallHistory(
        dateTime: 'now',
        riskLevel: 'GREEN',
        summary: 'safe',
        duration: '0s',
        flagCount: 0,
        transcript: '',
        alertHistory: null,
      );

      expect(history.getAlertHistoryList(), isEmpty);
    });

    test('returns empty list for empty string alertHistory', () {
      const history = CallHistory(
        dateTime: 'now',
        riskLevel: 'GREEN',
        summary: 'safe',
        duration: '0s',
        flagCount: 0,
        transcript: '',
        alertHistory: '',
      );

      expect(history.getAlertHistoryList(), isEmpty);
    });

    test('returns empty list for whitespace alertHistory', () {
      const history = CallHistory(
        dateTime: 'now',
        riskLevel: 'GREEN',
        summary: 'safe',
        duration: '0s',
        flagCount: 0,
        transcript: '',
        alertHistory: '   ',
      );

      expect(history.getAlertHistoryList(), isEmpty);
    });

    test('returns empty list for non-list JSON', () {
      const history = CallHistory(
        dateTime: 'now',
        riskLevel: 'GREEN',
        summary: 'safe',
        duration: '0s',
        flagCount: 0,
        transcript: '',
        alertHistory: '{"key": "value"}',
      );

      expect(history.getAlertHistoryList(), isEmpty);
    });

    test('returns empty list for invalid JSON', () {
      const history = CallHistory(
        dateTime: 'now',
        riskLevel: 'GREEN',
        summary: 'safe',
        duration: '0s',
        flagCount: 0,
        transcript: '',
        alertHistory: '{bad json!!!',
      );

      expect(history.getAlertHistoryList(), isEmpty);
    });
  });

  group('CallHistory — alertHistoryToJson', () {
    test('serializes empty list', () {
      expect(CallHistory.alertHistoryToJson([]), '[]');
    });

    test('serializes single entry', () {
      final json = CallHistory.alertHistoryToJson([
        const AlertHistoryEntry(
          timestamp: 0,
          analysisLevel: 'L1',
          riskLevel: 'GREEN',
          alertCount: 1,
          displayedReason: 'Test',
        ),
      ]);

      expect(json, contains('"riskLevel":"GREEN"'));
      expect(json, contains('"displayedReason":"Test"'));
    });
  });
}
