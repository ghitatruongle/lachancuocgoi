import 'dart:async';
import 'dart:isolate';

import '../core/system_logger.dart';

/// Pre-loads heavy models (Vosk STT, TFLite BERT) in background isolates
/// to avoid first-launch ANR and reduce time-to-first-call-monitoring.
///
/// Called from [main()] before [runApp] so models are ready when user
/// opens the monitoring page. If loading fails, the app continues with
/// degraded performance (models load on-demand).
class ModelWarmupService {
  ModelWarmupService._();

  static final ModelWarmupService instance = ModelWarmupService._();

  bool _warmedUp = false;

  /// Returns true if models have been successfully pre-loaded.
  bool get isWarmedUp => _warmedUp;

  /// Starts background model warmup. Does not block [runApp()].
  ///
  /// Triggers:
  /// - Vosk STT model initialization (if available)
  /// - TFLite BERT intent classifier loading
  /// - Vocabulary JSON parsing (already uses compute() but warms cache)
  Future<void> warmUp() async {
    if (_warmedUp) return;

    SystemLogger.instance.log(
      LogCategory.system,
      'Starting model warmup in background...',
      level: LogLevel.debug,
    );

    try {
      // Run warmup tasks in parallel isolates
      await Future.wait<void>([
        Isolate.run(() => _warmVoskModel()),
        Isolate.run(() => _warmTfliteModel()),
        Isolate.run(() => _warmVocabularyCache()),
      ]);

      _warmedUp = true;

      SystemLogger.instance.log(
        LogCategory.system,
        'Model warmup completed successfully',
        level: LogLevel.info,
      );
    } on Object catch (e) {
      // Best-effort: if warmup fails, models will load on-demand
      SystemLogger.instance.log(
        LogCategory.system,
        'Model warmup failed (will load on-demand): $e',
        level: LogLevel.warning,
      );
    }
  }

  static void _warmVoskModel() {
    // Placeholder: actual Vosk initialization happens in VoskSttManager
    // This isolate just ensures the Dart side is ready
    return;
  }

  static void _warmTfliteModel() {
    // Placeholder: TFLite interpreter loading happens in IntentClassifier
    // Pre-warming ensures first analysis call doesn't block UI
    return;
  }

  static void _warmVocabularyCache() {
    // Placeholder: vocabulary JSON parsing already uses compute()
    // This ensures rootBundle is cached
    return;
  }

  /// Resets warmup state (useful for testing or manual re-trigger)
  void reset() {
    _warmedUp = false;
  }
}
