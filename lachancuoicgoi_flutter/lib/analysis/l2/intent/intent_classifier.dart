import 'scam_intent.dart';

abstract interface class IntentClassifier {
  Future<void> initialize();

  bool get isReady;

  Future<List<IntentPrediction>> predictIntent(String transcript);

  void close();
}

class DisabledIntentClassifier implements IntentClassifier {
  const DisabledIntentClassifier();

  @override
  Future<void> initialize() async {}

  @override
  bool get isReady => false;

  @override
  Future<List<IntentPrediction>> predictIntent(String transcript) async {
    return const <IntentPrediction>[];
  }

  @override
  void close() {}
}
