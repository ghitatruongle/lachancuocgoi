import 'dart:math' as math;

import 'scam_intent.dart';

enum IntentOutputType { float32, uint8, int8 }

/// Result of multi-label intent classification.
class MultiLabelResult {
  final List<IntentPrediction> activeIntents;
  final ScamIntent? primaryIntent;
  final List<IntentSuperCategory> activeCategories;

  const MultiLabelResult({
    required this.activeIntents,
    this.primaryIntent,
    this.activeCategories = const [],
  });

  bool get hasMultipleIntents => activeIntents.length > 1;
}

class IntentOutputMapper {
  const IntentOutputMapper._();

  /// Platt scaling parameters (sigmoid calibration).
  /// calibrated = 1 / (1 + exp(a * logit + b))
  /// Default a=-1.2, b=0.3 — gentle calibration that reduces overconfidence
  /// without collapsing the distribution.
  static const double _plattA = -1.2;
  static const double _plattB = 0.3;

  /// Apply Platt scaling to raw logits, returning calibrated probabilities.
  /// Each logit is passed through a sigmoid: p = 1/(1+exp(a*x+b))
  /// then the result is re-normalised to sum to 1.
  static List<double> plattCalibrate(
    List<double> logits, {
    double a = _plattA,
    double b = _plattB,
  }) {
    if (logits.isEmpty) return const <double>[];
    final calibrated = List<double>.generate(logits.length, (i) {
      final p = 1.0 / (1.0 + math.exp(a * logits[i] + b));
      return p;
    });
    // Re-normalise so probabilities sum to 1.
    final sum = calibrated.fold<double>(0, (s, v) => s + v);
    if (sum == 0 || sum.isNaN) {
      return List<double>.filled(logits.length, 1.0 / logits.length);
    }
    for (var i = 0; i < calibrated.length; i++) {
      calibrated[i] /= sum;
    }
    return calibrated;
  }

  /// Multi-label classification: returns all intents whose calibrated
  /// confidence >= [threshold]. Also computes active super-categories.
  static MultiLabelResult multiLabelPredict(
    List<double> logits, {
    double threshold = 0.15,
  }) {
    if (logits.isEmpty) {
      return const MultiLabelResult(activeIntents: []);
    }
    final calibrated = plattCalibrate(logits);
    final classCount = math.min(calibrated.length, intentLabels.length);

    final active = <IntentPrediction>[];
    for (var i = 0; i < classCount; i++) {
      if (calibrated[i] >= threshold) {
        active.add(
          IntentPrediction(intent: intentLabels[i], confidence: calibrated[i]),
        );
      }
    }
    active.sort((a, b) => b.confidence.compareTo(a.confidence));

    // Derive active super-categories.
    final categories = <IntentSuperCategory>{};
    for (final p in active) {
      categories.add(p.intent.superCategory);
    }

    return MultiLabelResult(
      activeIntents: active,
      primaryIntent: active.isNotEmpty ? active.first.intent : null,
      activeCategories: categories.toList(),
    );
  }

  static List<double> decodeFlatOutput(
    List<num> rawOutput, {
    IntentOutputType outputType = IntentOutputType.float32,
    double scale = 1,
    int zeroPoint = 0,
  }) {
    // Use min(rawOutput, intentLabels) to handle model/intent count mismatch.
    // New intents added to intentLabels that the model doesn't know about
    // will simply not get logits (default 0).
    final classCount = math.min(rawOutput.length, intentLabels.length);
    if (classCount == 0) return const <double>[];

    final logits = List<double>.filled(intentLabels.length, 0);
    for (var i = 0; i < classCount; i++) {
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
    if (logits.isEmpty) return const <IntentPrediction>[];
    final classCount = math.min(logits.length, intentLabels.length);
    final probabilities = softmax(logits.take(classCount).toList());
    final predictions = <IntentPrediction>[];
    for (var i = 0; i < classCount; i++) {
      predictions.add(
        IntentPrediction(intent: intentLabels[i], confidence: probabilities[i]),
      );
    }
    predictions.sort((a, b) => b.confidence.compareTo(a.confidence));
    return predictions;
  }

  /// Convenience: decode raw TFLite output → Platt-calibrated predictions.
  static List<IntentPrediction> calibratedPredictions(
    List<num> rawOutput, {
    IntentOutputType outputType = IntentOutputType.float32,
    double scale = 1,
    int zeroPoint = 0,
  }) {
    final logits = decodeFlatOutput(
      rawOutput,
      outputType: outputType,
      scale: scale,
      zeroPoint: zeroPoint,
    );
    if (logits.isEmpty) return const <IntentPrediction>[];
    final calibrated = plattCalibrate(logits);
    final predictions = <IntentPrediction>[];
    for (var i = 0; i < calibrated.length; i++) {
      predictions.add(
        IntentPrediction(intent: intentLabels[i], confidence: calibrated[i]),
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
