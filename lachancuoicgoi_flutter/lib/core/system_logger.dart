import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';

import 'local_log_store.dart';
import 'logger.dart';

enum LogCategory { system, recording, stt, analysis, model, bridge, permission }

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

enum LogLevel { debug, info, warning, error }

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

  static final RegExp _geminiKeyPattern = RegExp(r'AIza[0-9A-Za-z_-]{16,}');
  static final RegExp _bearerPattern = RegExp(
    r'\bBearer\s+[A-Za-z0-9._~+/=-]+',
    caseSensitive: false,
  );
  static final RegExp _phonePattern = RegExp(
    r'(?<!\d)(?:\+?84|0)(?:[ .-]?\d){8,10}(?!\d)',
  );
  static final RegExp _emailPattern = RegExp(
    r'\b[A-Z0-9._%+-]+@[A-Z0-9.-]+\.[A-Z]{2,}\b',
    caseSensitive: false,
  );
  static final RegExp _sensitiveJsonFieldPattern = RegExp(
    r'("?(?:api[_ -]?key|authorization|prompt|transcript|response(?:Body)?|phone(?:Number)?)"?\s*:\s*)("[^"\r\n]*"|[^,}\]\r\n]+)',
    caseSensitive: false,
  );
  static final RegExp _sensitiveTextFieldPattern = RegExp(
    r'\b(api[_ -]?key|authorization|prompt|transcript|response(?: body)?|phone(?: number)?)\s*[=:]\s*[^\r\n]+',
    caseSensitive: false,
  );

  /// Removes secrets and user content before it reaches memory, disk or
  /// console output. The scrubber intentionally favours over-redaction.
  @visibleForTesting
  static String scrubForLogging(String value) {
    var scrubbed = value
        .replaceAll(_geminiKeyPattern, '[API_KEY_REDACTED]')
        .replaceAll(_bearerPattern, 'Bearer [REDACTED]')
        .replaceAllMapped(
          _sensitiveJsonFieldPattern,
          (match) => '${match.group(1)}"[REDACTED]"',
        )
        .replaceAllMapped(
          _sensitiveTextFieldPattern,
          (match) => '${match.group(1)}=[REDACTED]',
        )
        .replaceAll(_emailPattern, '[EMAIL_REDACTED]');
    scrubbed = scrubbed.replaceAllMapped(_phonePattern, (match) {
      final digits = match.group(0)!.replaceAll(RegExp(r'\D'), '');
      final suffix = digits.length >= 3
          ? digits.substring(digits.length - 3)
          : '';
      return '[PHONE_MASKED:***$suffix]';
    });
    const maxLogLength = 12000;
    if (scrubbed.length > maxLogLength) {
      return '${scrubbed.substring(0, maxLogLength)}\n[TRUNCATED]';
    }
    return scrubbed;
  }

  /// Logs a message with the given [category] and [level].
  void log(
    LogCategory category,
    String message, {
    LogLevel level = LogLevel.info,
  }) {
    final safeMessage = scrubForLogging(message);
    final entry = LogEntry(
      timestamp: DateTime.now(),
      category: category,
      level: level,
      message: safeMessage,
    );
    _logs.add(entry);
    if (_logs.length > 500) {
      _logs.removeAt(0);
    }
    _logController.add(entry);
    notifyListeners();
    debugPrint(
      '[${category.name.toUpperCase()}] '
      '[${level.name.toUpperCase()}] $safeMessage',
    );
    unawaited(_persist(entry));
  }

  Future<void> _persist(LogEntry entry) async {
    try {
      await LocalLogStore.instance.append(
        jsonEncode(<String, Object>{
          'timestamp': entry.timestamp.toUtc().toIso8601String(),
          'category': entry.category.name,
          'level': entry.level.name,
          'message': entry.message,
        }),
      );
    } on Object {
      // Never recurse into the logger when its own best-effort store fails.
    }
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
    final msg = _diagnosticMessage(message, error, stackTrace);
    log(LogCategory.system, msg, level: LogLevel.warning);
  }

  @override
  void error(String message, [Object? error, StackTrace? stackTrace]) {
    final msg = _diagnosticMessage(message, error, stackTrace);
    log(LogCategory.system, msg, level: LogLevel.error);
  }

  static String _diagnosticMessage(
    String message,
    Object? error,
    StackTrace? stackTrace,
  ) {
    final buffer = StringBuffer(message);
    if (error != null) {
      buffer.write(': $error');
    }
    if (stackTrace != null) {
      buffer.write('\n$stackTrace');
    }
    return buffer.toString();
  }

  /// Returns at most the most recent 500 already-scrubbed entries.
  String exportScrubbed({int maxEntries = 500}) {
    final bounded = maxEntries.clamp(0, 500);
    final start = _logs.length > bounded ? _logs.length - bounded : 0;
    return _logs
        .skip(start)
        .map((entry) {
          return '[${entry.timestamp.toUtc().toIso8601String()}] '
              '[${entry.category.name.toUpperCase()}] '
              '[${entry.level.name.toUpperCase()}] ${entry.message}';
        })
        .join('\n');
  }

  Future<void> clearPersisted() async {
    try {
      await LocalLogStore.instance.clear();
    } on Object {
      // Best effort only: an unavailable filesystem must not break reset.
    }
  }

  void clear() {
    _logs.clear();
    notifyListeners();
    unawaited(clearPersisted());
  }

  @override
  void dispose() {
    _logController.close();
    super.dispose();
  }
}
