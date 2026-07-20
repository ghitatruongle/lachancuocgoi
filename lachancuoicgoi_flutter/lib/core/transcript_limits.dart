import 'dart:convert';

import '../core/system_logger.dart';

/// Transcript size limits and memory safeguards.
///
/// Prevents ANR/crashes from extremely long transcripts or oversized
/// session snapshots by enforcing hard limits and graceful degradation.
class TranscriptLimits {
  const TranscriptLimits._();

  static const TranscriptLimits instance = TranscriptLimits._();

  /// Maximum transcript length before truncation (50KB).
  ///
  /// Beyond this, the analysis pipeline becomes slow and memory-intensive.
  /// Transcripts are truncated from the beginning (oldest text) to keep
  /// the most recent conversation context.
  static const int maxTranscriptLength = 50 * 1024; // 50 KB

  /// Maximum session snapshot size in SharedPreferences (1MB).
  ///
  /// Session snapshots include full transcript + analysis result JSON.
  /// Exceeding this triggers deletion to prevent SharedPreferences bloat.
  static const int maxSessionSnapshotBytes = 1 * 1024 * 1024; // 1 MB

  /// Maximum number of log entries retained in memory.
  static const int maxLogEntries = 500;

  /// Truncates [transcript] to [maxLength] if it exceeds the limit.
  ///
  /// Returns a record with:
  /// - [text]: possibly truncated transcript
  /// - [wasTruncated]: true if truncation occurred
  /// - [originalLength]: length before truncation
  ({String text, bool wasTruncated, int originalLength}) truncateIfNeeded(
    String transcript,
  ) {
    final originalLength = transcript.length;
    if (originalLength <= maxTranscriptLength) {
      return (
        text: transcript,
        wasTruncated: false,
        originalLength: originalLength,
      );
    }

    // Keep last N characters (most recent conversation)
    final truncated = transcript.substring(
      originalLength - maxTranscriptLength,
    );

    return (
      text: truncated,
      wasTruncated: true,
      originalLength: originalLength,
    );
  }

  /// Validates that a session snapshot JSON does not exceed size limit.
  ///
  /// Returns true if valid, false if too large.
  bool isSnapshotSizeValid(String jsonEncoded) {
    return utf8.encode(jsonEncoded).length <= maxSessionSnapshotBytes;
  }

  /// Logs a warning if transcript was truncated.
  void logTruncationWarning(int originalLength) {
    final msg = 'Transcript truncated from $originalLength bytes to '
        '$maxTranscriptLength bytes';
    SystemLogger.instance.log(
      LogCategory.analysis,
      msg,
      level: LogLevel.warning,
    );
  }
}
