import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../analysis/analysis_mode.dart';
import '../data/call_history_retention.dart';
import '../data/cloud_analysis_consent_store.dart';
import '../data/sensitive_data_reset_service.dart';

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
    this.onboardingCompleted = false,
    this.callHistoryRetention = CallHistoryRetention.thirtyDays,
    this.cloudAnalysisConsent = false,
    this.isLoaded = false,
  });

  final bool isDarkTheme;

  final bool followSystemTheme;
  final AnalysisMode analysisMode;
  final bool audioBoost;
  final bool autoEnableSpeakerphone;
  final bool creatorAudioCapture;

  final bool callScreeningBlockEnabled;

  final List<String> blockedNumbers;

  final bool onboardingCompleted;

  final CallHistoryRetention callHistoryRetention;

  final bool cloudAnalysisConsent;

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
    bool? onboardingCompleted,
    CallHistoryRetention? callHistoryRetention,
    bool? cloudAnalysisConsent,
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
      onboardingCompleted: onboardingCompleted ?? this.onboardingCompleted,
      callHistoryRetention: callHistoryRetention ?? this.callHistoryRetention,
      cloudAnalysisConsent: cloudAnalysisConsent ?? this.cloudAnalysisConsent,
      isLoaded: isLoaded ?? this.isLoaded,
    );
  }
}

final settingsControllerProvider =
    NotifierProvider<SettingsController, SettingsState>(SettingsController.new);

final cloudAnalysisConsentProvider = Provider<bool>((ref) {
  return ref.watch(
    settingsControllerProvider.select((state) => state.cloudAnalysisConsent),
  );
});

final cloudAnalysisConsentStoreProvider = Provider<CloudAnalysisConsentStore>((
  ref,
) {
  return _SettingsCloudAnalysisConsentStore(
    () => ref.read(settingsControllerProvider).cloudAnalysisConsent,
  );
});

final callHistoryRetentionServiceProvider =
    Provider<CallHistoryRetentionService>(
      (ref) => const CallHistoryRetentionService(),
    );

final sensitiveDataResetServiceProvider = Provider<SensitiveDataResetService>(
  (ref) => const SensitiveDataResetService(),
);

class _SettingsCloudAnalysisConsentStore extends CloudAnalysisConsentStore {
  const _SettingsCloudAnalysisConsentStore(this._readConsent);

  final bool Function() _readConsent;

  @override
  bool get isGranted => _readConsent();
}

class SettingsController extends Notifier<SettingsState> {
  static const _cloudConsentKey = 'CLOUD_ANALYSIS_CONSENT_V1';
  static const _legacyCloudConsentKey = 'CLOUD_ANALYSIS_CONSENT';

  int _generation = 0;

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

      autoEnableSpeakerphone: true,
      creatorAudioCapture: false,
    );
  }

  Future<void> _load() async {
    final generationAtStart = _generation;
    late final SharedPreferences prefs;
    try {
      prefs = await SharedPreferences.getInstance();
    } on Exception {
      _loaded = true;
      if (ref.mounted && generationAtStart == _generation) {
        state = state.copyWith(isLoaded: true);
      }
      return;
    }

    if (generationAtStart != _generation) return;
    final loadedState = _enforceCloudConsent(
      SettingsState(
        isDarkTheme: prefs.getBool('IS_DARK_THEME') ?? false,
        followSystemTheme: prefs.getBool('FOLLOW_SYSTEM_THEME') ?? true,
        analysisMode: AnalysisModeX.fromName(
          prefs.getString('ANALYSIS_MODE'),
          fallback: AnalysisMode.gDetection,
        ),
        audioBoost: prefs.getBool('AUDIO_BOOST') ?? false,
        autoEnableSpeakerphone:
            prefs.getBool('AUTO_ENABLE_SPEAKERPHONE') ?? true,
        creatorAudioCapture: prefs.getBool('CREATOR_AUDIO_CAPTURE') ?? false,
        callScreeningBlockEnabled:
            prefs.getBool('CALL_SCREENING_BLOCK_ENABLED') ?? false,
        blockedNumbers: prefs.getStringList('BLOCKED_NUMBERS') ?? const [],
        onboardingCompleted: prefs.getBool('onboarding_completed') ?? false,
        callHistoryRetention: CallHistoryRetention.fromStorageName(
          prefs.getString('CALL_HISTORY_RETENTION'),
        ),
        cloudAnalysisConsent:
            prefs.getBool(_cloudConsentKey) ??
            prefs.getBool(_legacyCloudConsentKey) ??
            false,
      ),
    );

    unawaited(prefs.remove('USE_SMALL_STT_MODEL'));
    _loaded = true;
    if (!ref.mounted) return;
    state = loadedState.copyWith(isLoaded: true);
  }

  Future<void> update(SettingsState next) async {
    _generation++;
    final effective = _enforceCloudConsent(next);
    state = effective;
    final prefs = await SharedPreferences.getInstance();
    await Future.wait([
      prefs.setBool('IS_DARK_THEME', effective.isDarkTheme),
      prefs.setBool('FOLLOW_SYSTEM_THEME', effective.followSystemTheme),
      prefs.setString('ANALYSIS_MODE', effective.analysisMode.storageName),
      prefs.setBool('AUDIO_BOOST', effective.audioBoost),
      prefs.setBool(
        'AUTO_ENABLE_SPEAKERPHONE',
        effective.autoEnableSpeakerphone,
      ),
      prefs.setBool('CREATOR_AUDIO_CAPTURE', effective.creatorAudioCapture),
      prefs.setBool(
        'CALL_SCREENING_BLOCK_ENABLED',
        effective.callScreeningBlockEnabled,
      ),
      prefs.setStringList('BLOCKED_NUMBERS', effective.blockedNumbers),
      prefs.setBool('onboarding_completed', effective.onboardingCompleted),
      prefs.setString(
        'CALL_HISTORY_RETENTION',
        effective.callHistoryRetention.storageName,
      ),
      prefs.setBool(_cloudConsentKey, effective.cloudAnalysisConsent),
      prefs.remove(_legacyCloudConsentKey),
      prefs.remove('USE_SMALL_STT_MODEL'),
    ]);
  }

  Future<void> completeOnboarding() {
    return update(state.copyWith(onboardingCompleted: true));
  }

  Future<void> setCloudAnalysisConsent(bool granted) {
    return update(state.copyWith(cloudAnalysisConsent: granted));
  }

  Future<SettingsState> resetSensitivePreferences() async {
    final next = state.copyWith(
      cloudAnalysisConsent: false,
      callScreeningBlockEnabled: false,
      blockedNumbers: const [],
      creatorAudioCapture: false,
    );
    await update(next);
    return state;
  }

  static SettingsState _enforceCloudConsent(SettingsState candidate) {
    final usesCloud =
        candidate.analysisMode == AnalysisMode.geminiApi ||
        candidate.analysisMode == AnalysisMode.parallel;
    if (!candidate.cloudAnalysisConsent && usesCloud) {
      return candidate.copyWith(analysisMode: AnalysisMode.gDetection);
    }
    return candidate;
  }
}
