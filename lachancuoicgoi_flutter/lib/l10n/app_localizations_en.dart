// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class AppLocalizationsEn extends AppLocalizations {
  AppLocalizationsEn([String locale = 'en']) : super(locale);

  @override
  String get appTitle => 'Call Shield';

  @override
  String get settings => 'Settings';

  @override
  String get permissions => 'Permissions';

  @override
  String get instructions => 'Guide';

  @override
  String get homeSubtitle => 'Real-time call analysis to detect scams.';

  @override
  String get homeLiveCaptionTip =>
      'Recommended: turn on Live Caption for best protection';

  @override
  String get appInfoSemantic => 'Call Shield app information';

  @override
  String get startMonitoring => 'Start monitoring';

  @override
  String get startMonitoringSemantic => 'Start call monitoring';

  @override
  String get simulationMode => 'Simulation mode';

  @override
  String get history => 'History';

  @override
  String get antiScamTips => 'Anti-scam tips';

  @override
  String get homePermissionWarning =>
      'Some permissions are missing — monitoring may be less effective.';

  @override
  String get demoMode => 'Demo mode';

  @override
  String get demoModeDescription =>
      'This platform does not attach to real calls. The app runs simulated scripts to try the AI. Full features (STT, overlay, call screening) are on Android.';

  @override
  String get demoModeSemantic => 'Demo mode — not attached to real calls';

  @override
  String get featuresOnThisDevice => 'Features on this device';

  @override
  String get monitoringSubtitle => 'Scam & abuse detection';

  @override
  String get monitoringEndCall => 'End call';

  @override
  String get monitoringSavingResult => 'Saving result...';

  @override
  String get monitoringEndCallSemantic => 'End call and save result';

  @override
  String get monitoringLiveConversation => 'Live conversation';

  @override
  String get monitoringSimulationTranscript => 'Simulation script';

  @override
  String get monitoringSystemLog => 'System log';

  @override
  String monitoringSimulationPrefix(String title) {
    return 'Simulation: $title';
  }

  @override
  String get monitoringSimulationDefault => 'Simulation';

  @override
  String monitoringRiskSemantic(String level) {
    return 'Current call risk level: $level';
  }

  @override
  String get monitoringWaveformSemantic => 'Live call audio waveform';

  @override
  String monitoringModeTarget(String mode) {
    return 'Target: $mode';
  }

  @override
  String monitoringModeRunning(String mode) {
    return 'Running: $mode';
  }

  @override
  String get monitoringNetworkOk => 'Network: OK';

  @override
  String get monitoringNetworkError => 'Network: Error';

  @override
  String get monitoringSttFatal =>
      'Mic/STT error — speech cannot be heard. Check microphone permission and try again.';

  @override
  String monitoringSttFatalWithReason(String reason) {
    return 'Mic/STT error — speech cannot be heard ($reason). Check microphone permission and try again.';
  }

  @override
  String get monitoringNotificationDegraded =>
      'Enable notifications for stable monitoring. Android may stop the app mid-call without notification permission.';

  @override
  String get monitoringWatchdogFailed =>
      'Could not recover the background monitoring service. Stop and start the session again.';

  @override
  String get monitoringSttFallbackOffline =>
      'STT switched to offline mode (Vosk)';

  @override
  String monitoringSttFallbackWithReason(String reason) {
    return 'Offline STT (Vosk): $reason';
  }

  @override
  String get riskLevelLabel => 'Risk level';

  @override
  String get warningDismissButton => 'GOT IT';

  @override
  String get warningRedTitle => 'DANGER';

  @override
  String get warningOrangeTitle => 'WARNING';
}
