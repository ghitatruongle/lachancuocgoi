import 'package:flutter_test/flutter_test.dart';
import 'package:lachancuocgoi_flutter/core/platform_capabilities.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('feature matrix has rows and AI always supported', () {
    final caps = PlatformCapabilities.current;
    expect(caps.featureMatrix, isNotEmpty);
    final ai = caps.featureMatrix.firstWhere((r) => r.label.contains('AI'));
    expect(ai.supported, isTrue);
  });

  test('demo mode is inverse of Android capability', () {
    final caps = PlatformCapabilities.current;
    expect(caps.isDemoMode, isNot(caps.isAndroid));
    expect(caps.realCallMonitoring, caps.isAndroid);
  });
}
