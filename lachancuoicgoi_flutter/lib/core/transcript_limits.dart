import 'dart:convert';

import '../core/system_logger.dart';

class TranscriptLimits {
  const TranscriptLimits._();

  static const TranscriptLimits instance = TranscriptLimits._();

  static const int maxTranscriptLength = 50 * 1024;

  static const int maxSessionSnapshotBytes = 1 * 1024 * 1024;

  static const int maxLogEntries = 500;

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

    final truncated = transcript.substring(
      originalLength - maxTranscriptLength,
    );

    return (
      text: truncated,
      wasTruncated: true,
      originalLength: originalLength,
    );
  }

  bool isSnapshotSizeValid(String jsonEncoded) {
    return utf8.encode(jsonEncoded).length <= maxSessionSnapshotBytes;
  }

  void logTruncationWarning(int originalLength) {
    final msg =
        'Transcript truncated from $originalLength bytes to '
        '$maxTranscriptLength bytes';
    SystemLogger.instance.log(
      LogCategory.analysis,
      msg,
      level: LogLevel.warning,
    );
  }
}
