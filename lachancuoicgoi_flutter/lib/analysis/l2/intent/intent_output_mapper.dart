import 'dart:math' as math;

import 'scam_intent.dart';

enum IntentOutputType { float32, uint8, int8 }

class IntentOutputMapper {
  const IntentOutputMapper._();

  static List<double> decodeFlatOutput(
    List<num> rawOutput, {
    IntentOutputType outputType = IntentOutputType.float32,
    double scale = 1,
    int zeroPoint = 0,
  }) {
    if (rawOutput.length < intentLabels.length) {
      return const <double>[];
    }

    final logits = List<double>.filled(intentLabels.length, 0);
    for (var i = 0; i < intentLabels.length; i++) {
      final rawValue = rawOutput[i];
      logits[i] = switch (outputType) {
        IntentOutputType.uint8 =>
          ((rawValue.toInt() & 0xFF) - zeroPoint) * scale,
        IntentOutputType.int8 => (rawValue.toInt() - zeroPoint) * scale,
        IntentOutputType.float32 => rawValue.toDouble(),
      };
    }
    return logits;
  }

  static List<IntentPrediction> predictionsFromLogits(List<double> logits) {
    if (logits.length < intentLabels.length) {
      return const <IntentPrediction>[];
    }
    final probabilities = softmax(logits.take(intentLabels.length).toList());
    final predictions = <IntentPrediction>[];
    for (var i = 0; i < intentLabels.length; i++) {
      predictions.add(
        IntentPrediction(intent: intentLabels[i], confidence: probabilities[i]),
      );
    }
    predictions.sort((a, b) => b.confidence.compareTo(a.confidence));
    return predictions;
  }

  static List<double> softmax(List<double> logits) {
    if (logits.isEmpty) return const <double>[];
    var maxLogit = -double.infinity;
    for (final logit in logits) {
      if (logit > maxLogit) maxLogit = logit;
    }
    var sum = 0.0;
    final probabilities = List<double>.filled(logits.length, 0);
    for (var i = 0; i < logits.length; i++) {
      final expValue = math.exp(logits[i] - maxLogit);
      probabilities[i] = expValue;
      sum += expValue;
    }
    if (sum == 0 || sum.isNaN) return List<double>.filled(logits.length, 0);
    for (var i = 0; i < probabilities.length; i++) {
      probabilities[i] /= sum;
    }
    return probabilities;
  }
}
