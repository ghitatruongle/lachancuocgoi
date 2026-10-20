library;

import 'native_bridge_interface.dart' show TranscriptUpdate;

bool _isBlank(String s) => s.trim().isEmpty;

TranscriptUpdate? combineTranscriptSources({
  required String stt,
  required String partial,
  required String accessibility,
}) {
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
