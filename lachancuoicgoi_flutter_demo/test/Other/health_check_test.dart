import 'package:flutter_test/flutter_test.dart';
import 'package:lachancuocgoi_flutter/analysis/health_check.dart';

void main() {
  group('HealthStatus enum', () {
    test('has correct values', () {
      expect(HealthStatus.values, hasLength(3));
      expect(HealthStatus.healthy, isNotNull);
      expect(HealthStatus.degraded, isNotNull);
      expect(HealthStatus.down, isNotNull);
    });
  });

  group('HealthReport', () {
    test('isHealthy returns true for healthy status', () {
      const report = HealthReport(
        status: HealthStatus.healthy,
        component: 'L1',
        message: 'All good',
      );

      expect(report.isHealthy, isTrue);
      expect(report.component, 'L1');
      expect(report.message, 'All good');
    });

    test('isHealthy returns false for degraded status', () {
      const report = HealthReport(
        status: HealthStatus.degraded,
        component: 'L2',
        message: 'Missing AI model',
      );

      expect(report.isHealthy, isFalse);
    });

    test('isHealthy returns false for down status', () {
      const report = HealthReport(
        status: HealthStatus.down,
        component: 'L3',
        message: 'Service unavailable',
      );

      expect(report.isHealthy, isFalse);
    });
  });
}
