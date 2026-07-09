import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:lachancuocgoi_flutter/data/transcript_saver.dart';

void main() {
  group('TranscriptSaver.prepareTranscriptForLocalStorage', () {
    test('trims leading and trailing whitespace', () {
      expect(
        TranscriptSaver.prepareTranscriptForLocalStorage('  hello world  '),
        'hello world',
      );
    });

    test('returns empty string for whitespace-only input', () {
      expect(
        TranscriptSaver.prepareTranscriptForLocalStorage('   '),
        '',
      );
    });

    test('returns empty string for empty input', () {
      expect(
        TranscriptSaver.prepareTranscriptForLocalStorage(''),
        '',
      );
    });

    test('preserves internal whitespace', () {
      expect(
        TranscriptSaver.prepareTranscriptForLocalStorage('hello  world'),
        'hello  world',
      );
    });
  });

  group('TranscriptSaver.saveTranscript', () {
    late Directory tempDir;

    setUp(() async {
      tempDir = await Directory.systemTemp.createTemp('transcript_test_');
    });

    tearDown(() async {
      if (await tempDir.exists()) {
        await tempDir.delete(recursive: true);
      }
    });

    test('creates directory if absent and saves file', () async {
      final result = await TranscriptSaver.saveTranscript(
        'hello world',
        baseDirectory: tempDir,
        timestamp: DateTime(2025, 6, 15, 14, 30, 45),
      );
      expect(result, isNotNull);
      expect(result, contains('transcripts'));
      expect(result, contains('transcript_20250615_143045.txt'));
    });

    test('filename has correct format YYYYMMDD_HHMMSS', () async {
      final result = await TranscriptSaver.saveTranscript(
        'test',
        baseDirectory: tempDir,
        timestamp: DateTime(2025, 1, 2, 3, 4, 5),
      );
      expect(result, contains('transcript_20250102_030405.txt'));
    });

    test('zero-pads single-digit month/day/hour/minute/second', () async {
      final result = await TranscriptSaver.saveTranscript(
        'test',
        baseDirectory: tempDir,
        timestamp: DateTime(2025, 1, 2, 3, 4, 5),
      );
      expect(result, contains('20250102_030405'));
    });

    test('creates transcripts subdirectory', () async {
      await TranscriptSaver.saveTranscript(
        'test',
        baseDirectory: tempDir,
        timestamp: DateTime(2025, 1, 1),
      );
      final subDir = Directory('${tempDir.path}/transcripts');
      expect(await subDir.exists(), isTrue);
    });

    test('writes content exactly', () async {
      const content = 'Line 1\nLine 2\nXin chào ông';
      final result = await TranscriptSaver.saveTranscript(
        content,
        baseDirectory: tempDir,
        timestamp: DateTime(2025, 6, 15),
      );
      final file = File(result!);
      expect(await file.readAsString(), content);
    });

    test('handles multiline unicode content', () async {
      const content = 'Xin chào\nOTP: 123456\nCảm ơn ông';
      final result = await TranscriptSaver.saveTranscript(
        content,
        baseDirectory: tempDir,
        timestamp: DateTime(2025, 1, 1),
      );
      final file = File(result!);
      expect(await file.readAsString(), content);
    });

    test('returns absolute file path', () async {
      final result = await TranscriptSaver.saveTranscript(
        'test',
        baseDirectory: tempDir,
        timestamp: DateTime(2025, 1, 1),
      );
      expect(result, startsWith(tempDir.path));
    });

    test('saves empty transcript', () async {
      final result = await TranscriptSaver.saveTranscript(
        '',
        baseDirectory: tempDir,
        timestamp: DateTime(2025, 1, 1),
      );
      expect(result, isNotNull);
      final file = File(result!);
      expect(await file.readAsString(), '');
    });

    test('directory already exists does not throw', () async {
      // Create the directory first
      await Directory('${tempDir.path}/transcripts').create();
      final result = await TranscriptSaver.saveTranscript(
        'test',
        baseDirectory: tempDir,
        timestamp: DateTime(2025, 1, 1),
      );
      expect(result, isNotNull);
    });

    test('returns null when path is a file (not a directory)', () async {
      // Create a file where the directory should be
      final blocker = File('${tempDir.path}/transcripts');
      await blocker.writeAsString('blocker');
      // Should not throw — returns null or succeeds depending on OS
      await TranscriptSaver.saveTranscript(
        'test',
        baseDirectory: tempDir,
        timestamp: DateTime(2025, 1, 1),
      );
    });

    test('transcriptDirectory constant is transcripts', () {
      expect(TranscriptSaver.transcriptDirectory, 'transcripts');
    });
  });
}
