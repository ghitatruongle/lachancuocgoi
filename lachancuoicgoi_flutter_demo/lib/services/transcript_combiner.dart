/// Sprint 2 (C6): the `combine { ... }` block that produces a transcript
/// update inside `BackgroundMonitoringService` is a complex lambda that
/// mixes three sources (Google STT, partials, accessibility hub). It is
/// hard to unit-test as a private function inside a Service, so it has
/// been extracted here as a pure top-level function.
///
/// On the Kotlin side, `BackgroundMonitoringService.transcriptCollectorJob`
/// invokes the equivalent of this function. On the Dart side, the
/// `combine` block is unused — but extracting the algorithm into a
/// pure function lets us assert its behaviour in
/// `dual_source_transcript_test.dart` without spinning up a Service.
library;

import 'native_bridge_interface.dart' show TranscriptUpdate;

bool _isBlank(String s) => s.trim().isEmpty;

/// Combines the three STT sources into a single [TranscriptUpdate].
///
/// - [stt]   — full transcript from Google STT (or Vosk fallback).
/// - [partial] — current partial result from Google STT.
/// - [accessibility] — full transcript from the accessibility hub
///   (TranscriptionHub).
///
/// Returns `null` when all three sources are blank (no update to emit).
TranscriptUpdate? combineTranscriptSources({
  required String stt,
  required String partial,
  required String accessibility,
}) {
  // Pick the longer of stt/accessibility as the cumulative base —
  // they are both authoritative for "the transcript so far".
  final String cumulative;
  if (!_isBlank(stt) && !_isBlank(accessibility)) {
    cumulative = stt.length >= accessibility.length ? stt : accessibility;
  } else if (!_isBlank(stt)) {
    cumulative = stt;
  } else if (!_isBlank(accessibility)) {
    cumulative = accessibility;
  } else {
    cumulative = '';
  }

  final String composed;
  if (!_isBlank(partial) && !_isBlank(cumulative)) {
    composed = '$cumulative\n$partial';
  } else {
    composed = cumulative;
  }

  if (_isBlank(composed)) return null;
  return TranscriptUpdate(text: composed, isPartial: !_isBlank(partial));
}
