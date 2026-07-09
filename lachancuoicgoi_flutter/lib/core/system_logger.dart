import 'dart:async';
import 'package:flutter/foundation.dart';

import 'logger.dart';

enum LogCategory {
  system,
  recording,
  stt,
  analysis,
  model,
  bridge,
  permission,
}

extension LogCategoryExtension on LogCategory {
  String get vietnameseName {
    return switch (this) {
      LogCategory.system => 'Hệ thống',
      LogCategory.recording => 'Ghi âm',
      LogCategory.stt => 'Nhận diện giọng nói',
      LogCategory.analysis => 'Phân tích cuộc gọi',
      LogCategory.model => 'Mô hình AI/STT',
      LogCategory.bridge => 'Kết nối nền tảng',
      LogCategory.permission => 'Quyền truy cập',
    };
  }
}

enum LogLevel {
  debug,
  info,
  warning,
  error,
}

class LogEntry {
  final DateTime timestamp;
  final LogCategory category;
  final LogLevel level;
  final String message;

  LogEntry({
    required this.timestamp,
    required this.category,
    required this.level,
    required this.message,
  });

  String get formattedTime {
    final hh = timestamp.hour.toString().padLeft(2, '0');
    final mm = timestamp.minute.toString().padLeft(2, '0');
    final ss = timestamp.second.toString().padLeft(2, '0');
    final ms = timestamp.millisecond.toString().padLeft(3, '0');
    return '$hh:$mm:$ss.$ms';
  }
}

/// Unified logger that implements [AppLogger] for dependency injection
/// and provides a buffered, streamed log for the UI System Log viewer.
///
/// All logging in the app should go through this singleton to ensure:
/// 1. Logs are visible in the UI log viewer
/// 2. Logs are printed to console with consistent formatting
/// 3. The analysis layer can use [AppLogger] interface via DI
class SystemLogger extends ChangeNotifier implements AppLogger {
  SystemLogger._();
  static final SystemLogger instance = SystemLogger._();

  final List<LogEntry> _logs = [];
  List<LogEntry> get logs => List.unmodifiable(_logs);

  final _logController = StreamController<LogEntry>.broadcast();
  Stream<LogEntry> get logStream => _logController.stream;

  /// Logs a message with the given [category] and [level].
  void log(LogCategory category, String message, {LogLevel level = LogLevel.info}) {
    final entry = LogEntry(
      timestamp: DateTime.now(),
      category: category,
      level: level,
      message: message,
    );
    _logs.add(entry);
    if (_logs.length > 500) {
      _logs.removeAt(0);
    }
    _logController.add(entry);
    notifyListeners();
    debugPrint('[${category.name.toUpperCase()}] [${level.name.toUpperCase()}] $message');
  }

  // ─── AppLogger implementation ─────────────────────────────────────
  //
  // These methods route through [log()] so all output appears in the
  // UI System Log viewer with consistent formatting.

  @override
  void debug(String message) {
    log(LogCategory.system, message, level: LogLevel.debug);
  }

  @override
  void info(String message) {
    log(LogCategory.system, message, level: LogLevel.info);
  }

  @override
  void warning(String message, [Object? error, StackTrace? stackTrace]) {
    final msg = error != null ? '$message: $error' : message;
    log(LogCategory.system, msg, level: LogLevel.warning);
  }

  @override
  void error(String message, [Object? error, StackTrace? stackTrace]) {
    final msg = error != null ? '$message: $error' : message;
    log(LogCategory.system, msg, level: LogLevel.error);
  }

  void clear() {
    _logs.clear();
    notifyListeners();
  }

  @override
  void dispose() {
    _logController.close();
    super.dispose();
  }
}
