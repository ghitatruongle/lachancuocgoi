import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lachancuocgoi_flutter/analysis/analysis_mode.dart';
import 'package:lachancuocgoi_flutter/app/settings_controller.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('SettingsController — initial state', () {
    test('returns default state when no SharedPreferences data', () async {
      SharedPreferences.setMockInitialValues({});
      final container = ProviderContainer();
      addTearDown(container.dispose);

      final state = container.read(settingsControllerProvider);
      expect(state.isDarkTheme, isFalse);
      expect(state.analysisMode, AnalysisMode.gDetection);
      expect(state.audioBoost, isFalse);
      expect(state.autoEnableSpeakerphone, isTrue);
      expect(state.creatorAudioCapture, isFalse);
    });
  });

  group('SettingsController — _load', () {
    testWidgets('loads saved preferences', (tester) async {
      SharedPreferences.setMockInitialValues({
        'IS_DARK_THEME': true,
        'ANALYSIS_MODE': 'geminiApi',
        'CLOUD_ANALYSIS_CONSENT_V1': true,
        'AUDIO_BOOST': true,
        'AUTO_ENABLE_SPEAKERPHONE': true,
        'CREATOR_AUDIO_CAPTURE': true,
      });

      final container = ProviderContainer();
      addTearDown(container.dispose);

      // Read triggers build() which calls _load()
      container.read(settingsControllerProvider);

      // Wait for _load() to complete in fake time
      await tester.pump();

      final state = container.read(settingsControllerProvider);
      expect(state.isDarkTheme, isTrue);
      expect(state.analysisMode, AnalysisMode.geminiApi);
      expect(state.audioBoost, isTrue);
      expect(state.autoEnableSpeakerphone, isTrue);
      expect(state.creatorAudioCapture, isTrue);
    });

    testWidgets('uses defaults for missing keys', (tester) async {
      SharedPreferences.setMockInitialValues({'IS_DARK_THEME': true});

      final container = ProviderContainer();
      addTearDown(container.dispose);

      container.read(settingsControllerProvider);
      await tester.pump();

      final state = container.read(settingsControllerProvider);
      expect(state.isDarkTheme, isTrue);
      expect(state.analysisMode, AnalysisMode.gDetection);
      expect(state.audioBoost, isFalse);
    });

    testWidgets('handles invalid analysis mode gracefully', (tester) async {
      SharedPreferences.setMockInitialValues({
        'ANALYSIS_MODE': 'nonexistent_mode',
      });

      final container = ProviderContainer();
      addTearDown(container.dispose);

      container.read(settingsControllerProvider);
      await tester.pump();

      final state = container.read(settingsControllerProvider);
      expect(state.analysisMode, AnalysisMode.gDetection);
    });
  });

  group('SettingsController — update', () {
    testWidgets('persists state to SharedPreferences', (tester) async {
      SharedPreferences.setMockInitialValues({});
      final container = ProviderContainer();
      addTearDown(container.dispose);

      container.read(settingsControllerProvider);
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

      final state = container.read(settingsControllerProvider);
      expect(state.isDarkTheme, isTrue);
      expect(state.analysisMode, AnalysisMode.geminiApi);
      expect(state.audioBoost, isTrue);

      // Verify persistence
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getBool('IS_DARK_THEME'), isTrue);
      expect(prefs.getString('ANALYSIS_MODE'), 'GEMINI_API');
      expect(prefs.getBool('AUDIO_BOOST'), isTrue);
      expect(prefs.getBool('AUTO_ENABLE_SPEAKERPHONE'), isTrue);
      expect(prefs.getBool('CREATOR_AUDIO_CAPTURE'), isTrue);
    });

    testWidgets('update changes state immediately', (tester) async {
      SharedPreferences.setMockInitialValues({});
      final container = ProviderContainer();
      addTearDown(container.dispose);

      container.read(settingsControllerProvider);
      await tester.pump();

      expect(container.read(settingsControllerProvider).isDarkTheme, isFalse);

      final current = container.read(settingsControllerProvider);
      await container
          .read(settingsControllerProvider.notifier)
          .update(current.copyWith(isDarkTheme: true));

      expect(container.read(settingsControllerProvider).isDarkTheme, isTrue);
    });
  });

  group('SettingsState — copyWith', () {
    test('copies with no changes returns identical values', () {
      const state = SettingsState(
        isDarkTheme: true,
        followSystemTheme: false,
        analysisMode: AnalysisMode.normal,
        audioBoost: true,
        autoEnableSpeakerphone: false,
        creatorAudioCapture: true,
      );
      final copy = state.copyWith();

      expect(copy.isDarkTheme, state.isDarkTheme);
      expect(copy.analysisMode, state.analysisMode);
      expect(copy.audioBoost, state.audioBoost);
      expect(copy.autoEnableSpeakerphone, state.autoEnableSpeakerphone);
      expect(copy.creatorAudioCapture, state.creatorAudioCapture);
    });

    test('copies with changes only modifies specified fields', () {
      const state = SettingsState(
        isDarkTheme: false,
        followSystemTheme: false,
        analysisMode: AnalysisMode.normal,
        audioBoost: false,
        autoEnableSpeakerphone: false,
        creatorAudioCapture: false,
      );
      final copy = state.copyWith(
        isDarkTheme: true,
        followSystemTheme: false,
        audioBoost: true,
      );

      expect(copy.isDarkTheme, isTrue);
      expect(copy.analysisMode, AnalysisMode.normal);
      expect(copy.audioBoost, isTrue);
      expect(copy.autoEnableSpeakerphone, isFalse);
    });
  });
}
