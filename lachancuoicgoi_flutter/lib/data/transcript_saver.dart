import 'dart:io';
import 'dart:convert';

import 'package:path/path.dart' as path;
import 'package:path_provider/path_provider.dart';

class TranscriptSaver {
  TranscriptSaver._();

  static const String transcriptDirectory = 'transcripts';
  static const int maxTranscriptBytes = 5 * 1024 * 1024;

  static String prepareTranscriptForLocalStorage(String transcript) {
    return transcript.trim();
  }

  static Future<String?> saveTranscript(
    String transcript, {
    Directory? baseDirectory,
    DateTime? timestamp,
  }) async {
    File? temporaryFile;
    try {
      final prepared = prepareTranscriptForLocalStorage(transcript);
      if (prepared.isEmpty ||
          utf8.encode(prepared).length > maxTranscriptBytes) {
        return null;
      }

      // Application support storage is private app data and is not exposed as
      // a user document. Callers may still inject a directory in tests.
      final base = baseDirectory ?? await getApplicationSupportDirectory();
      final directory = Directory(path.join(base.path, transcriptDirectory));
      if (!await directory.exists()) {
        await directory.create(recursive: true);
      }

      final time = timestamp ?? DateTime.now();
      final stem = 'transcript_${_formatTimestamp(time)}';
      var suffix = 0;
      while (suffix < 1000) {
        final suffixText = suffix == 0 ? '' : '_$suffix';
        final file = File(path.join(directory.path, '$stem$suffixText.txt'));
        temporaryFile = File('${file.path}.tmp');
        if (await file.exists() || await temporaryFile.exists()) {
          suffix++;
          continue;
        }
        await temporaryFile.create(exclusive: true);
        await temporaryFile.writeAsString(prepared, flush: true);
        await temporaryFile.rename(file.path);
        return file.path;
      }
      return null;
    } on FileSystemException {
      return null;
    } on Exception {
      return null;
    } finally {
      final temp = temporaryFile;
      if (temp != null) {
        try {
          if (await temp.exists()) await temp.delete();
        } on FileSystemException {
          // Best-effort removal of an interrupted atomic write.
        }
      }
    }
  }

  /// Deletes all locally exported transcripts and returns the file count.
  static Future<int> deleteAll({Directory? baseDirectory}) async {
    try {
      final base = baseDirectory ?? await getApplicationSupportDirectory();
      final directory = Directory(path.join(base.path, transcriptDirectory));
      if (!await directory.exists()) return 0;
      var count = 0;
      await for (final entity in directory.list(followLinks: false)) {
        if (entity is File) count++;
      }
      await directory.delete(recursive: true);
      return count;
    } on FileSystemException {
      return 0;
    } on Exception {
      return 0;
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
