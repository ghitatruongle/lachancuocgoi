/// Synchronous consent gate for any analysis that sends user content to a
/// cloud service.
///
/// Cloud clients should call [requireConsent] immediately before every
/// network request. Reading the value on every call is intentional: consent
/// can be revoked while a long-lived analyzer instance remains alive.
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
