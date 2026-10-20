import 'dart:async';
import 'dart:isolate';

import '../core/system_logger.dart';

class ModelWarmupService {
  ModelWarmupService._();

  static final ModelWarmupService instance = ModelWarmupService._();

  bool _warmedUp = false;

  bool get isWarmedUp => _warmedUp;

  Future<void> warmUp() async {
    if (_warmedUp) return;

    SystemLogger.instance.log(
      LogCategory.system,
      'Starting model warmup in background...',
      level: LogLevel.debug,
    );

    try {
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
      SystemLogger.instance.log(
        LogCategory.system,
        'Model warmup failed (will load on-demand): $e',
        level: LogLevel.warning,
      );
    }
  }

  static void _warmVoskModel() {
    return;
  }

  static void _warmTfliteModel() {
    return;
  }

  static void _warmVocabularyCache() {
    return;
  }

  void reset() {
    _warmedUp = false;
  }
}
