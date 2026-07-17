import 'package:flutter_test/flutter_test.dart';
import 'package:lachancuocgoi_flutter/analysis/analysis_mode.dart';
import 'package:lachancuocgoi_flutter/analysis/analysis_mode_policy.dart';

void main() {
  group('AnalysisModePolicy.resolveEffectiveMode', () {
    test('returns selectedMode when not geminiApi regardless of network', () {
      expect(
        AnalysisModePolicy.resolveEffectiveMode(AnalysisMode.normal, true),
        AnalysisMode.normal,
      );
      expect(
        AnalysisModePolicy.resolveEffectiveMode(AnalysisMode.normal, false),
        AnalysisMode.normal,
      );
      expect(
        AnalysisModePolicy.resolveEffectiveMode(AnalysisMode.gDetection, true),
        AnalysisMode.gDetection,
      );
      expect(
        AnalysisModePolicy.resolveEffectiveMode(AnalysisMode.gDetection, false),
        AnalysisMode.gDetection,
      );
    });

    test('returns geminiApi when geminiApi selected and network available', () {
      expect(
        AnalysisModePolicy.resolveEffectiveMode(AnalysisMode.geminiApi, true),
        AnalysisMode.geminiApi,
      );
    });

    test('returns gDetection when geminiApi selected but network unavailable '
        '(fallback)', () {
      expect(
        AnalysisModePolicy.resolveEffectiveMode(AnalysisMode.geminiApi, false),
        AnalysisMode.gDetection,
      );
    });
  });

  group('AnalysisModePolicy.createRuntimeState', () {
    test('normal mode with network available', () {
      final state = AnalysisModePolicy.createRuntimeState(
        AnalysisMode.normal,
        true,
      );
      expect(state.selectedMode, AnalysisMode.normal);
      expect(state.effectiveMode, AnalysisMode.normal);
      expect(state.networkAvailable, true);
      expect(state.isFallbackActive, false);
    });

    test('normal mode with network unavailable', () {
      final state = AnalysisModePolicy.createRuntimeState(
        AnalysisMode.normal,
        false,
      );
      expect(state.selectedMode, AnalysisMode.normal);
      expect(state.effectiveMode, AnalysisMode.normal);
      expect(state.networkAvailable, false);
      expect(state.isFallbackActive, false);
    });

    test('gDetection mode with network available', () {
      final state = AnalysisModePolicy.createRuntimeState(
        AnalysisMode.gDetection,
        true,
      );
      expect(state.selectedMode, AnalysisMode.gDetection);
      expect(state.effectiveMode, AnalysisMode.gDetection);
      expect(state.networkAvailable, true);
      expect(state.isFallbackActive, false);
    });

    test('gDetection mode with network unavailable', () {
      final state = AnalysisModePolicy.createRuntimeState(
        AnalysisMode.gDetection,
        false,
      );
      expect(state.selectedMode, AnalysisMode.gDetection);
      expect(state.effectiveMode, AnalysisMode.gDetection);
      expect(state.networkAvailable, false);
      expect(state.isFallbackActive, false);
    });

    test('geminiApi mode with network available - no fallback', () {
      final state = AnalysisModePolicy.createRuntimeState(
        AnalysisMode.geminiApi,
        true,
      );
      expect(state.selectedMode, AnalysisMode.geminiApi);
      expect(state.effectiveMode, AnalysisMode.geminiApi);
      expect(state.networkAvailable, true);
      expect(state.isFallbackActive, false);
    });

    test('geminiApi mode with network unavailable - triggers fallback', () {
      final state = AnalysisModePolicy.createRuntimeState(
        AnalysisMode.geminiApi,
        false,
      );
      expect(state.selectedMode, AnalysisMode.geminiApi);
      expect(state.effectiveMode, AnalysisMode.gDetection);
      expect(state.networkAvailable, false);
      expect(state.isFallbackActive, true);
    });
  });

  group('AnalysisRuntimeState equality', () {
    test('equal instances are equal', () {
      const a = AnalysisRuntimeState(
        selectedMode: AnalysisMode.geminiApi,
        effectiveMode: AnalysisMode.gDetection,
        networkAvailable: false,
        isFallbackActive: true,
      );
      const b = AnalysisRuntimeState(
        selectedMode: AnalysisMode.geminiApi,
        effectiveMode: AnalysisMode.gDetection,
        networkAvailable: false,
        isFallbackActive: true,
      );
      expect(a, equals(b));
      expect(a.hashCode, equals(b.hashCode));
    });

    test('different instances are not equal', () {
      const a = AnalysisRuntimeState(
        selectedMode: AnalysisMode.geminiApi,
        effectiveMode: AnalysisMode.geminiApi,
        networkAvailable: true,
        isFallbackActive: false,
      );
      const b = AnalysisRuntimeState(
        selectedMode: AnalysisMode.geminiApi,
        effectiveMode: AnalysisMode.gDetection,
        networkAvailable: false,
        isFallbackActive: true,
      );
      expect(a, isNot(equals(b)));
    });
  });

  group('AnalysisRuntimeState toString', () {
    test('contains all field values', () {
      const state = AnalysisRuntimeState(
        selectedMode: AnalysisMode.geminiApi,
        effectiveMode: AnalysisMode.gDetection,
        networkAvailable: false,
        isFallbackActive: true,
      );
      final str = state.toString();
      expect(str, contains('geminiApi'));
      expect(str, contains('gDetection'));
      expect(str, contains('false'));
      expect(str, contains('true'));
    });
  });

  group('fallback consistency invariant', () {
    test(
      'isFallbackActive is true iff selected is geminiApi and effective is not',
      () {
        // Test all 9 combinations of 3 modes x {network on, off}
        for (final selected in AnalysisMode.values) {
          for (final network in [true, false]) {
            final state = AnalysisModePolicy.createRuntimeState(
              selected,
              network,
            );
            final expectedFallback =
                selected == AnalysisMode.geminiApi &&
                state.effectiveMode != AnalysisMode.geminiApi;
            expect(
              state.isFallbackActive,
              expectedFallback,
              reason: 'selected=$selected, network=$network',
            );
          }
        }
      },
    );
  });
}
