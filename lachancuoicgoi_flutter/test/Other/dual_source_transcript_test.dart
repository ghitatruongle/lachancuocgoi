import 'package:flutter_test/flutter_test.dart';
import 'package:lachancuocgoi_flutter/services/native_call_shield_bridge.dart';
import 'package:lachancuocgoi_flutter/services/transcript_combiner.dart';

void main() {
  group('combineTranscriptSources', () {
    test('all blank → null (no update emitted)', () {
      final result = combineTranscriptSources(
        stt: '',
        partial: '',
        accessibility: '',
      );
      expect(result, isNull);
    });

    test('whitespace-only sources → null', () {
      final result = combineTranscriptSources(
        stt: '   ',
        partial: '\n',
        accessibility: '\t  ',
      );
      expect(result, isNull);
    });

    test('stt only (no partial, no accessibility) → final transcript', () {
      final result = combineTranscriptSources(
        stt: 'hello',
        partial: '',
        accessibility: '',
      );
      expect(result, isNotNull);
      expect(result!.text, 'hello');
      expect(result.isPartial, isFalse);
    });

    test('partial only (no cumulative) → null (mirrors Kotlin combine)', () {
      final result = combineTranscriptSources(
        stt: '',
        partial: 'wor',
        accessibility: '',
      );
      expect(result, isNull);
    });

    test('stt + partial → cumulative then partial on a new line', () {
      final result = combineTranscriptSources(
        stt: 'hello',
        partial: 'wor',
        accessibility: '',
      );
      expect(result, isNotNull);
      expect(result!.text, 'hello\nwor');
      expect(result.isPartial, isTrue);
    });

    test('accessibility wins over stt when accessibility is longer', () {
      final result = combineTranscriptSources(
        stt: 'hi',
        partial: '',
        accessibility: 'hello world',
      );
      expect(result, isNotNull);
      expect(result!.text, 'hello world');
      expect(result.isPartial, isFalse);
    });

    test('stt wins when stt is longer than accessibility', () {
      final result = combineTranscriptSources(
        stt: 'hello world again',
        partial: '',
        accessibility: 'hi',
      );
      expect(result, isNotNull);
      expect(result!.text, 'hello world again');
    });

    test('stt and accessibility equal length → stt is picked (>=) ', () {
      final result = combineTranscriptSources(
        stt: 'equal',
        partial: '',
        accessibility: 'equal',
      );
      expect(result, isNotNull);
      expect(result!.text, 'equal');
    });

    test('all three: stt+partial+accessibility, accessibility wins', () {
      final result = combineTranscriptSources(
        stt: 'hi',
        partial: 'wor',
        accessibility: 'world',
      );
      expect(result, isNotNull);

      expect(result!.text, 'world\nwor');
      expect(result.isPartial, isTrue);
    });

    test('all three: stt+partial+accessibility, stt wins', () {
      final result = combineTranscriptSources(
        stt: 'hello world',
        partial: 'wor',
        accessibility: 'hi',
      );
      expect(result, isNotNull);
      expect(result!.text, 'hello world\nwor');
      expect(result.isPartial, isTrue);
    });

    test('partial present but cumulative blank → null (no emit)', () {
      final result = combineTranscriptSources(
        stt: '',
        partial: 'wor',
        accessibility: '',
      );
      expect(result, isNull);
    });

    test('returns a TranscriptUpdate instance', () {
      final result = combineTranscriptSources(
        stt: 'hello',
        partial: '',
        accessibility: '',
      );
      expect(result, isA<TranscriptUpdate>());
    });
  });
}
