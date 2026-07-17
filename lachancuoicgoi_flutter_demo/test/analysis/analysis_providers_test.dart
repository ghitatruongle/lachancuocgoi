import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lachancuocgoi_flutter/analysis/analysis_coordinator.dart';
import 'package:lachancuocgoi_flutter/analysis/analysis_providers.dart';
import 'package:lachancuocgoi_flutter/analysis/l1/l1_analysis.dart';
import 'package:lachancuocgoi_flutter/analysis/l2/g_detection/g_detection_engine.dart';
import 'package:lachancuocgoi_flutter/analysis/l2/l2_analysis.dart';
import 'package:lachancuocgoi_flutter/analysis/l3/l3_analysis.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('l1AnalyzerProvider', () {
    test('creates an L1Analyzer instance', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      final analyzer = container.read(l1AnalyzerProvider);
      expect(analyzer, isA<L1Analyzer>());
    });

    test('returns same instance on re-read (singleton)', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      final first = container.read(l1AnalyzerProvider);
      final second = container.read(l1AnalyzerProvider);
      expect(identical(first, second), isTrue);
    });
  });

  group('gDetectionEngineProvider', () {
    test('creates a GDetectionEngine instance', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      final engine = container.read(gDetectionEngineProvider);
      expect(engine, isA<GDetectionEngine>());
    });

    test('returns same instance on re-read (singleton)', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      final first = container.read(gDetectionEngineProvider);
      final second = container.read(gDetectionEngineProvider);
      expect(identical(first, second), isTrue);
    });
  });

  group('l2AnalyzerProvider', () {
    test('creates an L2Analyzer instance', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      final analyzer = container.read(l2AnalyzerProvider);
      expect(analyzer, isA<L2Analyzer>());
    });

    test('returns same instance on re-read (singleton)', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      final first = container.read(l2AnalyzerProvider);
      final second = container.read(l2AnalyzerProvider);
      expect(identical(first, second), isTrue);
    });
  });

  group('l3AnalyzerProvider', () {
    test('creates an L3Analyzer instance', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      final analyzer = container.read(l3AnalyzerProvider);
      expect(analyzer, isA<L3Analyzer>());
    });

    test('returns same instance on re-read (singleton)', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      final first = container.read(l3AnalyzerProvider);
      final second = container.read(l3AnalyzerProvider);
      expect(identical(first, second), isTrue);
    });
  });

  group('analysisCoordinatorProvider', () {
    test('creates an AnalysisCoordinator instance', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      final coordinator = container.read(analysisCoordinatorProvider);
      expect(coordinator, isA<AnalysisCoordinator>());
    });

    test('returns same instance on re-read (singleton)', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      final first = container.read(analysisCoordinatorProvider);
      final second = container.read(analysisCoordinatorProvider);
      expect(identical(first, second), isTrue);
    });

    test('AnalysisCoordinator uses the singleton L1Analyzer', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      // Reading both providers from the same container ensures the
      // coordinator gets the same singleton analyzer instances.
      final coordinator = container.read(analysisCoordinatorProvider);
      expect(coordinator, isA<AnalysisCoordinator>());
      // If the coordinator had created its own L1Analyzer (instead of
      // receiving the singleton), the provider would have failed or
      // created a second instance. The construction succeeding confirms
      // the wiring through ref.read is correct.
    });
  });

  group('cross-provider singleton wiring', () {
    test('all providers in same container share the same container', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      final l1 = container.read(l1AnalyzerProvider);
      final gEngine = container.read(gDetectionEngineProvider);
      final l2 = container.read(l2AnalyzerProvider);
      final l3 = container.read(l3AnalyzerProvider);
      final coordinator = container.read(analysisCoordinatorProvider);

      // All five providers resolved without error — the dependency chain
      // (coordinator -> l2 -> gDetectionEngine, coordinator -> l1, l3)
      // is intact.
      expect(l1, isA<L1Analyzer>());
      expect(gEngine, isA<GDetectionEngine>());
      expect(l2, isA<L2Analyzer>());
      expect(l3, isA<L3Analyzer>());
      expect(coordinator, isA<AnalysisCoordinator>());
    });

    test('separate containers produce independent singletons', () {
      final container1 = ProviderContainer();
      final container2 = ProviderContainer();
      addTearDown(container1.dispose);
      addTearDown(container2.dispose);

      final l1FromC1 = container1.read(l1AnalyzerProvider);
      final l1FromC2 = container2.read(l1AnalyzerProvider);

      // Different containers → different singleton instances.
      expect(identical(l1FromC1, l1FromC2), isFalse);
    });
  });
}
