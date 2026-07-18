import 'package:flutter_test/flutter_test.dart';
import 'package:lachancuocgoi_flutter/core/analysis_availability.dart';

void main() {
  group('AnalysisAvailability.fromStoredSession', () {
    test('recording errors always override a green risk assessment', () {
      expect(
        AnalysisAvailability.fromStoredSession(
          recordingError: 'noAudio',
          hasTranscript: false,
          analysisCompleted: true,
        ),
        AnalysisAvailability.noAudio,
      );
      expect(
        AnalysisAvailability.fromStoredSession(
          recordingError: 'sttFailed',
          hasTranscript: false,
          analysisCompleted: true,
        ),
        AnalysisAvailability.sttUnavailable,
      );
      expect(
        AnalysisAvailability.fromStoredSession(
          recordingError: 'killed',
          hasTranscript: true,
          analysisCompleted: true,
        ),
        AnalysisAvailability.interrupted,
      );
    });

    test('requires both transcript and completed analysis', () {
      expect(
        AnalysisAvailability.fromStoredSession(
          recordingError: null,
          hasTranscript: true,
          analysisCompleted: false,
        ),
        AnalysisAvailability.interrupted,
      );
      expect(
        AnalysisAvailability.fromStoredSession(
          recordingError: null,
          hasTranscript: true,
          analysisCompleted: true,
        ),
        AnalysisAvailability.sufficient,
      );
    });
  });
}
