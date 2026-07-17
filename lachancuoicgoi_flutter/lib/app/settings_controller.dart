import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../analysis/analysis_mode.dart';

class SettingsState {
  const SettingsState({
    required this.isDarkTheme,
    required this.followSystemTheme,
    required this.analysisMode,
    required this.audioBoost,
    required this.autoEnableSpeakerphone,
    required this.creatorAudioCapture,
    this.callScreeningBlockEnabled = false,
    this.blockedNumbers = const [],
    this.useSmallSttModel = false,
    this.isLoaded = false,
  });

  final bool isDarkTheme;

  /// When true, [ThemeMode.system] is used (ignores [isDarkTheme] for mode).
  final bool followSystemTheme;
  final AnalysisMode analysisMode;
  final bool audioBoost;
  final bool autoEnableSpeakerphone;
  final bool creatorAudioCapture;

  /// Phase 2 (P2-4): Call screening opt-in — block/reject known scam numbers.
  /// Default OFF. The user must explicitly enable this in Settings with consent.
  final bool callScreeningBlockEnabled;

  /// Phase 2 (P2-4): List of phone numbers to block when
  /// [callScreeningBlockEnabled] is true.
  final List<String> blockedNumbers;

  /// Phase 2 (P2-5): When true, use `model-vn-small` (lighter, faster
  /// cold-start). When false, use `model-vn` (larger, more accurate).
  /// The native [VoskSttManager] reads this via MethodChannel.
  final bool useSmallSttModel;

  /// Whether persisted settings have finished loading from SharedPreferences.
  final bool isLoaded;

  SettingsState copyWith({
    bool? isDarkTheme,
    bool? followSystemTheme,
    AnalysisMode? analysisMode,
    bool? audioBoost,
    bool? autoEnableSpeakerphone,
    bool? creatorAudioCapture,
    bool? callScreeningBlockEnabled,
    List<String>? blockedNumbers,
    bool? useSmallSttModel,
    bool? isLoaded,
  }) {
    return SettingsState(
      isDarkTheme: isDarkTheme ?? this.isDarkTheme,
      followSystemTheme: followSystemTheme ?? this.followSystemTheme,
      analysisMode: analysisMode ?? this.analysisMode,
      audioBoost: audioBoost ?? this.audioBoost,
      autoEnableSpeakerphone:
          autoEnableSpeakerphone ?? this.autoEnableSpeakerphone,
      creatorAudioCapture: creatorAudioCapture ?? this.creatorAudioCapture,
      callScreeningBlockEnabled:
          callScreeningBlockEnabled ?? this.callScreeningBlockEnabled,
      blockedNumbers: blockedNumbers ?? this.blockedNumbers,
      useSmallSttModel: useSmallSttModel ?? this.useSmallSttModel,
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
      followSystemTheme: true,
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
      followSystemTheme: prefs.getBool('FOLLOW_SYSTEM_THEME') ?? true,
      analysisMode: AnalysisModeX.fromName(
        prefs.getString('ANALYSIS_MODE'),
        fallback: AnalysisMode.gDetection,
      ),
      audioBoost: prefs.getBool('AUDIO_BOOST') ?? false,
      autoEnableSpeakerphone:
          prefs.getBool('AUTO_ENABLE_SPEAKERPHONE') ?? false,
      creatorAudioCapture: prefs.getBool('CREATOR_AUDIO_CAPTURE') ?? false,
      callScreeningBlockEnabled:
          prefs.getBool('CALL_SCREENING_BLOCK_ENABLED') ?? false,
      blockedNumbers: prefs.getStringList('BLOCKED_NUMBERS') ?? const [],
      useSmallSttModel: prefs.getBool('USE_SMALL_STT_MODEL') ?? false,
    );
    _loaded = true;
    if (!ref.mounted) return;
    state = loadedState.copyWith(isLoaded: true);
  }

  Future<void> update(SettingsState next) async {
    _generation++;
    state = next;
    final prefs = await SharedPreferences.getInstance();
    await Future.wait([
      prefs.setBool('IS_DARK_THEME', next.isDarkTheme),
      prefs.setBool('FOLLOW_SYSTEM_THEME', next.followSystemTheme),
      prefs.setString('ANALYSIS_MODE', next.analysisMode.storageName),
      prefs.setBool('AUDIO_BOOST', next.audioBoost),
      prefs.setBool('AUTO_ENABLE_SPEAKERPHONE', next.autoEnableSpeakerphone),
      prefs.setBool('CREATOR_AUDIO_CAPTURE', next.creatorAudioCapture),
      prefs.setBool(
        'CALL_SCREENING_BLOCK_ENABLED', next.callScreeningBlockEnabled,
      ),
      prefs.setStringList('BLOCKED_NUMBERS', next.blockedNumbers),
      prefs.setBool('USE_SMALL_STT_MODEL', next.useSmallSttModel),
    ]);
  }
}
