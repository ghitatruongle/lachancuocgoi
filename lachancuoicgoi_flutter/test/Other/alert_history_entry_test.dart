import 'package:flutter_test/flutter_test.dart';
import 'package:lachancuocgoi_flutter/data/alert_history_entry.dart';

void main() {
  group('AlertHistoryEntry — JSON serialization', () {
    test('round-trips through toJson and fromJson', () {
      final original = AlertHistoryEntry(
        timestamp: DateTime(2026, 3, 15, 14, 30, 0).millisecondsSinceEpoch,
        analysisLevel: 'L3',
        riskLevel: 'RED',
        alertCount: 5,
        displayedReason: 'Giả danh công an',
        allReasons: const ['Giả danh', 'Chuyển tiền', 'OTP'],
      );

      final json = original.toJson();
      final restored = AlertHistoryEntry.fromJson(json);

      expect(restored.timestamp, original.timestamp);
      expect(restored.analysisLevel, 'L3');
      expect(restored.riskLevel, 'RED');
      expect(restored.alertCount, 5);
      expect(restored.displayedReason, 'Giả danh công an');
      expect(restored.allReasons, hasLength(3));
    });

    test('fromJson handles missing fields with defaults', () {
      final entry = AlertHistoryEntry.fromJson(<String, Object?>{});

      expect(entry.timestamp, 0);
      expect(entry.analysisLevel, '');
      expect(entry.riskLevel, 'GREEN');
      expect(entry.alertCount, 1);
      expect(entry.displayedReason, '');
      expect(entry.allReasons, isNull);
    });

    test('fromJson handles partial data', () {
      final entry = AlertHistoryEntry.fromJson(<String, Object?>{
        'timestamp': 1234567890,
        'riskLevel': 'ORANGE',
      });

      expect(entry.timestamp, 1234567890);
      expect(entry.riskLevel, 'ORANGE');
      expect(entry.analysisLevel, '');
    });
  });

  group('AlertHistoryEntry — formatting', () {
    test('getFormattedTime formats correctly with zero-padding', () {
      final entry = AlertHistoryEntry(
        timestamp: DateTime(2026, 1, 1, 3, 5, 7).millisecondsSinceEpoch,
        analysisLevel: 'L1',
        riskLevel: 'GREEN',
        alertCount: 1,
        displayedReason: '',
      );

      expect(entry.getFormattedTime(), '03:05:07');
    });

    test('getFormattedTime handles midnight', () {
      final entry = AlertHistoryEntry(
        timestamp: DateTime(2026, 6, 15, 0, 0, 0).millisecondsSinceEpoch,
        analysisLevel: 'L1',
        riskLevel: 'GREEN',
        alertCount: 1,
        displayedReason: '',
      );

      expect(entry.getFormattedTime(), '00:00:00');
    });
  });

  group('AlertHistoryEntry — risk level color', () {
    test('RED returns correct ARGB color', () {
      const entry = AlertHistoryEntry(
        timestamp: 0,
        analysisLevel: 'L1',
        riskLevel: 'RED',
        alertCount: 1,
        displayedReason: '',
      );

      expect(entry.getRiskLevelColor().toARGB32(), 0xFFD32F2F);
    });

    test('ORANGE returns correct ARGB color', () {
      const entry = AlertHistoryEntry(
        timestamp: 0,
        analysisLevel: 'L1',
        riskLevel: 'ORANGE',
        alertCount: 1,
        displayedReason: '',
      );

      expect(entry.getRiskLevelColor().toARGB32(), 0xFFFF9800);
    });

    test('GREEN falls back to grey', () {
      const entry = AlertHistoryEntry(
        timestamp: 0,
        analysisLevel: 'L1',
        riskLevel: 'GREEN',
        alertCount: 1,
        displayedReason: '',
      );

      expect(entry.getRiskLevelColor().toARGB32(), 0xFF9E9E9E);
    });

    test('case insensitive riskLevel for color', () {
      const entry = AlertHistoryEntry(
        timestamp: 0,
        analysisLevel: 'L1',
        riskLevel: 'red',
        alertCount: 1,
        displayedReason: '',
      );

      expect(entry.getRiskLevelColor().toARGB32(), 0xFFD32F2F);
    });
  });

  group('AlertHistoryEntry — risk level icon', () {
    test('returns correct icon string per level', () {
      const red = AlertHistoryEntry(
        timestamp: 0,
        analysisLevel: '',
        riskLevel: 'RED',
        alertCount: 1,
        displayedReason: '',
      );
      const orange = AlertHistoryEntry(
        timestamp: 0,
        analysisLevel: '',
        riskLevel: 'ORANGE',
        alertCount: 1,
        displayedReason: '',
      );
      const green = AlertHistoryEntry(
        timestamp: 0,
        analysisLevel: '',
        riskLevel: 'GREEN',
        alertCount: 1,
        displayedReason: '',
      );

      expect(red.getRiskLevelIcon(), 'red');
      expect(orange.getRiskLevelIcon(), 'orange');
      expect(green.getRiskLevelIcon(), 'neutral');
    });
  });
}
