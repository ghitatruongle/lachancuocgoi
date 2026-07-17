@Tags(['perf'])
library;

// ignore_for_file: invalid_annotation_target
import 'package:flutter_test/flutter_test.dart';

/// Tests the parsing of transcript events received from the native
/// side via `transcriptStream`. The native side can send events in
/// two shapes:
///
/// 1. **Old style** — a bare `String`. Pre-Sprint 1 native builds
///    emitted raw transcript text. The Dart side has to wrap it as
///    `TranscriptUpdate(text: <string>, isPartial: false)`.
/// 2. **New style** — a `Map` with `{'text': '...', 'isPartial': <bool>}`.
///    `isPartial` is optional and defaults to `false`.
///
/// Additionally:
/// - Events with empty `text` are dropped (filtered by `.where(...)`).
/// - `null` events become `TranscriptUpdate(text: '', isPartial: false)`
///   and are then dropped.
///
/// ─────────────────────────────────────────────────────────────────────
/// We pin our own `TranscriptUpdate` and `parseTranscriptEvent` here
/// because the production class is part of the upcoming Sprint 1+2
/// refactor (`lib/services/native_call_shield_bridge.dart`) and
/// doesn't exist yet. Once the production class lands, this file
/// should be updated to import it.
///
/// The `parseTranscriptEvent` rule captured here:
/// - `Map` → `TranscriptUpdate(text, isPartial)`; missing `text` → '',
///   missing `isPartial` → false.
/// - `String` → `TranscriptUpdate(text, isPartial: false)`.
/// - everything else (including `null`) → `TranscriptUpdate('', false)`.
void main() {
  group('parseTranscriptEvent — payload shape tolerance', () {
    test('old-style event: a bare String → isPartial=false', () {
      final u = parseTranscriptEvent('hello world');
      expect(u.text, 'hello world');
      expect(u.isPartial, isFalse);
    });

    test('old-style event: empty String → empty text (filtered by stream)', () {
      final u = parseTranscriptEvent('');
      expect(u.text, isEmpty);
    });

    test('new-style event: full Map with isPartial=true', () {
      final u = parseTranscriptEvent(<String, Object?>{
        'text': 'wor',
        'isPartial': true,
      });
      expect(u.text, 'wor');
      expect(u.isPartial, isTrue);
    });

    test('new-style event: missing isPartial → defaults to false', () {
      final u = parseTranscriptEvent(<String, Object?>{'text': 'hello'});
      expect(u.text, 'hello');
      expect(u.isPartial, isFalse);
    });

    test('new-style event: missing text → empty (filtered by stream)', () {
      final u = parseTranscriptEvent(<String, Object?>{'isPartial': true});
      expect(u.text, isEmpty);
      expect(u.isPartial, isTrue);
    });

    test('new-style event: empty text → empty (filtered by stream)', () {
      final u = parseTranscriptEvent(<String, Object?>{'text': ''});
      expect(u.text, isEmpty);
    });

    test('null event → empty text, isPartial=false (filtered by stream)', () {
      final u = parseTranscriptEvent(null);
      expect(u.text, isEmpty);
      expect(u.isPartial, isFalse);
    });

    test('Map with extra keys is ignored', () {
      final u = parseTranscriptEvent(<String, Object?>{
        'text': 'ok',
        'isPartial': true,
        'extra': 42,
        'lang': 'vi',
      });
      expect(u.text, 'ok');
      expect(u.isPartial, isTrue);
    });

    test('non-Map, non-String → empty text (filtered by stream)', () {
      final u = parseTranscriptEvent(42);
      expect(u.text, isEmpty);
    });

    test('Vietnamese text is preserved verbatim', () {
      const t = 'Anh ơi cho em xin mã OTP 🙏';
      final u = parseTranscriptEvent(<String, Object?>{'text': t});
      expect(u.text, t);
    });

    test('very long text round-trips', () {
      final t = 'a' * 50000;
      final u = parseTranscriptEvent(<String, Object?>{'text': t});
      expect(u.text, t);
      expect(u.text.length, 50000);
    });
  });

  group('stream filter — empty events are dropped', () {
    test('bare empty string is dropped', () async {
      final events = mapAndFilter('');
      expect(await events.toList(), isEmpty);
    });

    test('null is dropped', () async {
      final events = mapAndFilter(null);
      expect(await events.toList(), isEmpty);
    });

    test('Map with empty text is dropped', () async {
      final events = mapAndFilter(<String, Object?>{'text': ''});
      expect(await events.toList(), isEmpty);
    });

    test('non-empty string passes through', () async {
      final events = mapAndFilter('hello');
      final list = await events.toList();
      expect(list, hasLength(1));
      expect(list.first.text, 'hello');
      expect(list.first.isPartial, isFalse);
    });

    test('non-empty Map passes through with correct isPartial', () async {
      final events = mapAndFilter(<String, Object?>{
        'text': 'wor',
        'isPartial': true,
      });
      final list = await events.toList();
      expect(list, hasLength(1));
      expect(list.first.text, 'wor');
      expect(list.first.isPartial, isTrue);
    });
  });
}

// ── Pinned test fixtures ──────────────────────────────────────────────

class TranscriptUpdate {
  const TranscriptUpdate({required this.text, required this.isPartial});
  final String text;
  final bool isPartial;
}

TranscriptUpdate parseTranscriptEvent(Object? event) {
  if (event is Map) {
    return TranscriptUpdate(
      text: (event['text'] as String?) ?? '',
      isPartial: (event['isPartial'] as bool?) ?? false,
    );
  }
  if (event is String) {
    return TranscriptUpdate(text: event, isPartial: false);
  }
  return const TranscriptUpdate(text: '', isPartial: false);
}

Stream<TranscriptUpdate> mapAndFilter(Object? event) async* {
  final u = parseTranscriptEvent(event);
  if (u.text.isNotEmpty) yield u;
}
