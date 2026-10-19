import 'package:flutter_test/flutter_test.dart';
import 'package:lachancuocgoi_flutter/analysis/metrics/detection_metrics.dart';

void main() {
  test('DetectionMetrics counts and p50', () {
    final m = DetectionMetrics();
    m.recordL1();
    m.recordL2();
    m.recordL3Success(100);
    m.recordL3Success(300);
    m.recordL3Success(200);
    m.recordL3Fallback(timeout: true);
    expect(m.l1Calls, 1);
    expect(m.l2Calls, 1);
    expect(m.l3Calls, 3);
    expect(m.l3Fallbacks, 1);
    expect(m.l3Timeouts, 1);
    expect(m.l3LatencyP50, 200);
    expect(m.toJson()['l3LatencySamples'], 3);
    m.reset();
    expect(m.l3Calls, 0);
  });
}
