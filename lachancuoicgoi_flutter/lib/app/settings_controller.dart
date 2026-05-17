import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../analysis/analysis_mode.dart';

class SettingsState {
  const SettingsState({
    required this.isDarkTheme,
    required this.analysisMode,
    required this.audioBoost,
    required this.autoEnableSpeakerphone,
    required this.creatorAudioCapture,
  });

  final bool isDarkTheme;
  final AnalysisMode analysisMode;
  final bool audioBoost;
  final bool autoEnableSpeakerphone;
  final bool creatorAudioCapture;

  SettingsState copyWith({
    bool? isDarkTheme,
    AnalysisMode? analysisMode,
    bool? audioBoost,
    bool? autoEnableSpeakerphone,
    bool? creatorAudioCapture,
  }) {
    return SettingsState(
      isDarkTheme: isDarkTheme ?? this.isDarkTheme,
      analysisMode: analysisMode ?? this.analysisMode,
      audioBoost: audioBoost ?? this.audioBoost,
      autoEnableSpeakerphone: autoEnableSpeakerphone ?? this.autoEnableSpeakerphone,
      creatorAudioCapture: creatorAudioCapture ?? this.creatorAudioCapture,
    );
  }
}

final settingsControllerProvider =
    NotifierProvider<SettingsController, SettingsState>(SettingsController.new);

class SettingsController extends Notifier<SettingsState> {
  @override
  SettingsState build() {
    _load();
    return const SettingsState(
      isDarkTheme: false,
      analysisMode: AnalysisMode.gDetection,
      audioBoost: false,
      autoEnableSpeakerphone: false,
      creatorAudioCapture: false,
    );
  }

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    state = SettingsState(
      isDarkTheme: prefs.getBool('IS_DARK_THEME') ?? false,
      analysisMode: AnalysisModeX.fromName(
        prefs.getString('ANALYSIS_MODE'),
        fallback: AnalysisMode.gDetection,
      ),
      audioBoost: prefs.getBool('AUDIO_BOOST') ?? false,
      autoEnableSpeakerphone: prefs.getBool('AUTO_ENABLE_SPEAKERPHONE') ?? false,
      creatorAudioCapture: prefs.getBool('CREATOR_AUDIO_CAPTURE') ?? false,
    );
  }

  Future<void> update(SettingsState next) async {
    state = next;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('IS_DARK_THEME', next.isDarkTheme);
    await prefs.setString('ANALYSIS_MODE', next.analysisMode.storageName);
    await prefs.setBool('AUDIO_BOOST', next.audioBoost);
    await prefs.setBool('AUTO_ENABLE_SPEAKERPHONE', next.autoEnableSpeakerphone);
    await prefs.setBool('CREATOR_AUDIO_CAPTURE', next.creatorAudioCapture);
  }
}
