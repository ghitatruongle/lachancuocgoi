abstract class CloudAnalysisConsentStore {
  const CloudAnalysisConsentStore();

  bool get isGranted;

  void requireConsent() {
    if (!isGranted) {
      throw const CloudAnalysisConsentRequiredException();
    }
  }
}

class CloudAnalysisConsentRequiredException implements Exception {
  const CloudAnalysisConsentRequiredException();

  @override
  String toString() =>
      'Cloud analysis requires explicit, currently active user consent.';
}
