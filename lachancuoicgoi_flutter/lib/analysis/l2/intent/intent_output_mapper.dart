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

  /// Parse a labels.txt file (one ScamIntent name per line, matching the
  /// TFLite model's output tensor class order) into a [ScamIntent] list.
  ///
  /// This is the critical bridge between the trained model's class ordering
  /// and the app's [ScamIntent] enum. Without it, the code assumes
  /// `intentLabels[i] == model neuron i`, which breaks when intents are added
  /// to the enum without retraining the model.
  ///
  /// Lines starting with `#` or empty lines are ignored.
  /// Throws [ArgumentError] if any line is not a valid [ScamIntent] name.
  static List<ScamIntent> parseLabelFile(String content) {
    final labels = <ScamIntent>[];
    for (final rawLine in content.split(RegExp(r'\r?\n'))) {
      final line = rawLine.trim();
      if (line.isEmpty || line.startsWith('#')) continue;
      final intent = ScamIntent.values.cast<ScamIntent?>().firstWhere(
        (e) => e?.name == line,
        orElse: () => null,
      );
      if (intent == null) {
        throw ArgumentError.value(
          line,
          'label',
          'Unknown ScamIntent name in labels file',
        );
      }
      labels.add(intent);
    }
    return labels;
  }

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
    List<ScamIntent>? labelOrder,
  }) {
    // When labelOrder is provided (from model_labels.txt), use it to size the
    // output. Otherwise fall back to intentLabels for backward compatibility.
    final labels = labelOrder ?? intentLabels;
    final classCount = math.min(rawOutput.length, labels.length);
    if (classCount == 0) return const <double>[];

    final logits = List<double>.filled(labels.length, 0);
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

  static List<IntentPrediction> predictionsFromLogits(
    List<double> logits, {
    List<ScamIntent>? labelOrder,
  }) {
    if (logits.isEmpty) return const <IntentPrediction>[];
    final labels = labelOrder ?? intentLabels;
    final classCount = math.min(logits.length, labels.length);
    final probabilities = softmax(logits.take(classCount).toList());
    final predictions = <IntentPrediction>[];
    for (var i = 0; i < classCount; i++) {
      predictions.add(
        IntentPrediction(intent: labels[i], confidence: probabilities[i]),
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
    List<ScamIntent>? labelOrder,
  }) {
    final labels = labelOrder ?? intentLabels;
    final logits = decodeFlatOutput(
      rawOutput,
      outputType: outputType,
      scale: scale,
      zeroPoint: zeroPoint,
      labelOrder: labelOrder,
    );
    if (logits.isEmpty) return const <IntentPrediction>[];
    final calibrated = plattCalibrate(logits);
    final predictions = <IntentPrediction>[];
    for (var i = 0; i < calibrated.length && i < labels.length; i++) {
      predictions.add(
        IntentPrediction(intent: labels[i], confidence: calibrated[i]),
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
