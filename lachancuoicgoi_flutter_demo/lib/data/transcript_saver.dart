import 'dart:io';

import 'package:path/path.dart' as path;
import 'package:path_provider/path_provider.dart';

class TranscriptSaver {
  TranscriptSaver._();

  static const String transcriptDirectory = 'transcripts';

  static String prepareTranscriptForLocalStorage(String transcript) {
    return transcript.trim();
  }

  static Future<String?> saveTranscript(
    String transcript, {
    Directory? baseDirectory,
    DateTime? timestamp,
  }) async {
    try {
      final base = baseDirectory ?? await getApplicationDocumentsDirectory();
      final directory = Directory(path.join(base.path, transcriptDirectory));
      if (!await directory.exists()) {
        await directory.create(recursive: true);
      }

      final time = timestamp ?? DateTime.now();
      final fileName = 'transcript_${_formatTimestamp(time)}.txt';
      final file = File(path.join(directory.path, fileName));
      await file.writeAsString(transcript);
      return file.path;
    } on FileSystemException {
      return null;
    } on Exception {
      return null;
    }
  }

  static String _formatTimestamp(DateTime value) {
    return '${value.year.toString().padLeft(4, '0')}'
        '${value.month.toString().padLeft(2, '0')}'
        '${value.day.toString().padLeft(2, '0')}_'
        '${value.hour.toString().padLeft(2, '0')}'
        '${value.minute.toString().padLeft(2, '0')}'
        '${value.second.toString().padLeft(2, '0')}';
  }
}
