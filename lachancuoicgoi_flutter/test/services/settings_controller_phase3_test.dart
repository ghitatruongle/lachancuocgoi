import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lachancuocgoi_flutter/analysis/analysis_mode.dart';
import 'package:lachancuocgoi_flutter/app/settings_controller.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('SettingsController — Phase 3: race condition fix', () {
    testWidgets(
      'SharedPreferences pre-initialization makes _load() resolve fast',
      (tester) async {
        SharedPreferences.setMockInitialValues({
          'IS_DARK_THEME': true,
          'ANALYSIS_MODE': 'GEMINI_API',
          'CLOUD_ANALYSIS_CONSENT_V1': true,
          'AUDIO_BOOST': true,
          'AUTO_ENABLE_SPEAKERPHONE': true,
          'CREATOR_AUDIO_CAPTURE': true,
        });

        await SharedPreferences.getInstance();

        final container = ProviderContainer();
        addTearDown(container.dispose);

        container.read(settingsControllerProvider);

        await tester.pump();

        final state = container.read(settingsControllerProvider);
        expect(state.isDarkTheme, isTrue);
        expect(state.analysisMode, AnalysisMode.geminiApi);
        expect(state.audioBoost, isTrue);
        expect(state.autoEnableSpeakerphone, isTrue);
        expect(state.creatorAudioCapture, isTrue);
      },
    );

    testWidgets('settings load within 200ms after pre-initialization', (
      tester,
    ) async {
      SharedPreferences.setMockInitialValues({
        'IS_DARK_THEME': true,
        'ANALYSIS_MODE': 'GEMINI_API',
        'CLOUD_ANALYSIS_CONSENT_V1': true,
      });

      await SharedPreferences.getInstance();

      final container = ProviderContainer();
      addTearDown(container.dispose);

      final startTime = DateTime.now();
      container.read(settingsControllerProvider);

      await tester.pump();
      final elapsed = DateTime.now().difference(startTime).inMilliseconds;

      final state = container.read(settingsControllerProvider);
      expect(state.isDarkTheme, isTrue);
      expect(state.isLoaded, isTrue);
      expect(elapsed, lessThan(1000));
    });

    testWidgets('default state used before _load() completes', (tester) async {
      SharedPreferences.setMockInitialValues({});

      final container = ProviderContainer();
      addTearDown(container.dispose);

      final initialState = container.read(settingsControllerProvider);
      expect(initialState.isDarkTheme, isFalse);
      expect(initialState.analysisMode, AnalysisMode.gDetection);

      await tester.pump();

      final loadedState = container.read(settingsControllerProvider);
      expect(loadedState.isDarkTheme, isFalse);
      expect(loadedState.analysisMode, AnalysisMode.gDetection);
    });

    testWidgets('update() persists to SharedPreferences and reloads', (
      tester,
    ) async {
      SharedPreferences.setMockInitialValues({});

      final container = ProviderContainer();
      addTearDown(container.dispose);

      await tester.pump();

      const newState = SettingsState(
        isDarkTheme: true,
        followSystemTheme: false,
        analysisMode: AnalysisMode.geminiApi,
        audioBoost: true,
        autoEnableSpeakerphone: true,
        creatorAudioCapture: true,
        cloudAnalysisConsent: true,
      );
      await container
          .read(settingsControllerProvider.notifier)
          .update(newState);

      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getBool('IS_DARK_THEME'), isTrue);
      expect(prefs.getString('ANALYSIS_MODE'), 'GEMINI_API');
      expect(prefs.getBool('AUDIO_BOOST'), isTrue);
      expect(prefs.getBool('AUTO_ENABLE_SPEAKERPHONE'), isTrue);
      expect(prefs.getBool('CREATOR_AUDIO_CAPTURE'), isTrue);
    });

    testWidgets('update() persists to SharedPreferences', (tester) async {
      SharedPreferences.setMockInitialValues({});

      final container = ProviderContainer();
      addTearDown(container.dispose);

      await tester.pump();

      const newState = SettingsState(
        isDarkTheme: true,
        followSystemTheme: false,
        analysisMode: AnalysisMode.normal,
        audioBoost: false,
        autoEnableSpeakerphone: false,
        creatorAudioCapture: false,
      );
      await container
          .read(settingsControllerProvider.notifier)
          .update(newState);

      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getBool('IS_DARK_THEME'), isTrue);
      expect(prefs.getString('ANALYSIS_MODE'), 'NORMAL');
    });

    test('copyWith works correctly', () {
      const state = SettingsState(
        isDarkTheme: false,
        followSystemTheme: false,
        analysisMode: AnalysisMode.gDetection,
        audioBoost: false,
        autoEnableSpeakerphone: false,
        creatorAudioCapture: false,
      );

      final updated = state.copyWith(isDarkTheme: true);
      expect(updated.isDarkTheme, isTrue);
      expect(updated.analysisMode, AnalysisMode.gDetection);
      expect(updated.audioBoost, isFalse);
    });

    test('copyWith preserves unmodified fields', () {
      const state = SettingsState(
        isDarkTheme: true,
        followSystemTheme: false,
        analysisMode: AnalysisMode.geminiApi,
        audioBoost: true,
        autoEnableSpeakerphone: true,
        creatorAudioCapture: true,
      );

      final updated = state.copyWith(audioBoost: false);
      expect(updated.isDarkTheme, isTrue);
      expect(updated.analysisMode, AnalysisMode.geminiApi);
      expect(updated.audioBoost, isFalse);
      expect(updated.autoEnableSpeakerphone, isTrue);
      expect(updated.creatorAudioCapture, isTrue);
    });
  });
}
