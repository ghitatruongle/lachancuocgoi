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
    this.isLoaded = false,
  });

  final bool isDarkTheme;
  final AnalysisMode analysisMode;
  final bool audioBoost;
  final bool autoEnableSpeakerphone;
  final bool creatorAudioCapture;

  /// Whether persisted settings have finished loading from SharedPreferences.
  final bool isLoaded;

  SettingsState copyWith({
    bool? isDarkTheme,
    AnalysisMode? analysisMode,
    bool? audioBoost,
    bool? autoEnableSpeakerphone,
    bool? creatorAudioCapture,
    bool? isLoaded,
  }) {
    return SettingsState(
      isDarkTheme: isDarkTheme ?? this.isDarkTheme,
      analysisMode: analysisMode ?? this.analysisMode,
      audioBoost: audioBoost ?? this.audioBoost,
      autoEnableSpeakerphone: autoEnableSpeakerphone ?? this.autoEnableSpeakerphone,
      creatorAudioCapture: creatorAudioCapture ?? this.creatorAudioCapture,
      isLoaded: isLoaded ?? this.isLoaded,
    );
  }
}

final settingsControllerProvider =
    NotifierProvider<SettingsController, SettingsState>(SettingsController.new);

class SettingsController extends Notifier<SettingsState> {
  // Generation counter: incremented on every update() call.
  // _load() captures the generation at start and only applies if unchanged.
  int _generation = 0;

  /// Whether the persisted settings have been loaded.
  /// Used to avoid a flash when the initial theme differs from persisted.
  bool _loaded = false;
  bool get loaded => _loaded;

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
    final generationAtStart = _generation;
    final prefs = await SharedPreferences.getInstance();
    // If update() was called while we were loading, don't overwrite.
    if (generationAtStart != _generation) return;
    final loadedState = SettingsState(
      isDarkTheme: prefs.getBool('IS_DARK_THEME') ?? false,
      analysisMode: AnalysisModeX.fromName(
        prefs.getString('ANALYSIS_MODE'),
        fallback: AnalysisMode.gDetection,
      ),
      audioBoost: prefs.getBool('AUDIO_BOOST') ?? false,
      autoEnableSpeakerphone: prefs.getBool('AUTO_ENABLE_SPEAKERPHONE') ?? false,
      creatorAudioCapture: prefs.getBool('CREATOR_AUDIO_CAPTURE') ?? false,
    );
    _loaded = true;
    state = loadedState.copyWith(isLoaded: true);
  }

  Future<void> update(SettingsState next) async {
    _generation++;
    state = next;
    final prefs = await SharedPreferences.getInstance();
    await Future.wait([
      prefs.setBool('IS_DARK_THEME', next.isDarkTheme),
      prefs.setString('ANALYSIS_MODE', next.analysisMode.storageName),
      prefs.setBool('AUDIO_BOOST', next.audioBoost),
      prefs.setBool('AUTO_ENABLE_SPEAKERPHONE', next.autoEnableSpeakerphone),
      prefs.setBool('CREATOR_AUDIO_CAPTURE', next.creatorAudioCapture),
    ]);
  }
}
