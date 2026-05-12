import 'dart:io';

import 'package:flutter/services.dart';
import 'package:tflite_flutter/tflite_flutter.dart';

import 'bert_intent_tokenizer.dart';
import 'intent_classifier.dart';
import 'intent_output_mapper.dart';
import 'scam_intent.dart';

class TFLiteIntentClassifier implements IntentClassifier {
  TFLiteIntentClassifier({
    AssetBundle? assetBundle,
    this.modelAsset = 'assets/ghitav3.tflite',
    this.vocabAsset = 'assets/vocab.txt',
  }) : _assetBundle = assetBundle ?? rootBundle;

  final AssetBundle _assetBundle;
  final String modelAsset;
  final String vocabAsset;

  Interpreter? _interpreter;
  BertIntentTokenizer? _tokenizer;
  IntentOutputType _outputType = IntentOutputType.float32;
  double _outputScale = 1;
  int _outputZeroPoint = 0;
  bool _isReady = false;
  bool _hasAttemptedInit = false;

  int _lastInputHash = 0;
  int _lastInputLength = 0;
  List<IntentPrediction> _cachedResult = const <IntentPrediction>[];

  static const double cacheChangeThreshold = 0.20;

  @override
  bool get isReady => _isReady;

  @override
  Future<void> initialize() async {
    if (_hasAttemptedInit) return;
    _hasAttemptedInit = true;

    try {
      final vocab = await _loadVocab();
      final threadCount = Platform.numberOfProcessors.clamp(1, 4).toInt();
      final options = InterpreterOptions()..threads = threadCount;
      final interpreter = await Interpreter.fromAsset(
        modelAsset,
        options: options,
      );

      final outputTensor = interpreter.getOutputTensor(0);
      final numClasses = outputTensor.shape.isEmpty
          ? 0
          : outputTensor.shape.last;
      if (numClasses != intentLabels.length) {
        interpreter.close();
        _isReady = false;
        return;
      }

      _outputType = switch (outputTensor.type) {
        TensorType.uint8 => IntentOutputType.uint8,
        TensorType.int8 => IntentOutputType.int8,
        _ => IntentOutputType.float32,
      };
      if (_outputType != IntentOutputType.float32) {
        final params = outputTensor.params;
        _outputScale = params.scale == 0 ? 1 : params.scale;
        _outputZeroPoint = params.zeroPoint;
      }

      _tokenizer = BertIntentTokenizer(vocab);
      _interpreter = interpreter;
      _isReady = true;
    } catch (_) {
      close();
      _isReady = false;
    }
  }

  @override
  Future<List<IntentPrediction>> predictIntent(String transcript) async {
    if (!_isReady || _interpreter == null || _tokenizer == null) {
      throw StateError('TFLite model is not ready.');
    }
    if (transcript.trim().isEmpty) return const <IntentPrediction>[];

    final currentHash = transcript.hashCode;
    final lengthDelta = transcript.length - _lastInputLength;
    final changeRatio = _lastInputLength > 0
        ? lengthDelta / _lastInputLength
        : 1.0;
    if (currentHash == _lastInputHash) return _cachedResult;
    if (_cachedResult.isNotEmpty &&
        changeRatio >= 0 &&
        changeRatio < cacheChangeThreshold) {
      return _cachedResult;
    }

    final predictions = _runInference(transcript);
    _lastInputHash = currentHash;
    _lastInputLength = transcript.length;
    _cachedResult = predictions;
    return predictions;
  }

  List<IntentPrediction> _runInference(String transcript) {
    final tokenizer = _tokenizer!;
    final tokens = tokenizer.tokenize(transcript);
    final inputs = tokenizer.buildInputs(tokens);
    final output = _allocateOutput();

    _interpreter!.runForMultipleInputs(
      <Object>[
        <List<int>>[inputs.inputIds],
        <List<int>>[inputs.attentionMask],
        <List<int>>[inputs.tokenTypeIds],
      ],
      <int, Object>{0: output},
    );

    final logits = IntentOutputMapper.decodeFlatOutput(
      _flattenOutput(output),
      outputType: _outputType,
      scale: _outputScale,
      zeroPoint: _outputZeroPoint,
    );
    return IntentOutputMapper.predictionsFromLogits(logits);
  }

  Object _allocateOutput() {
    return switch (_outputType) {
      IntentOutputType.uint8 || IntentOutputType.int8 => <List<int>>[
        List<int>.filled(intentLabels.length, 0),
      ],
      IntentOutputType.float32 => <List<double>>[
        List<double>.filled(intentLabels.length, 0),
      ],
    };
  }

  List<num> _flattenOutput(Object output) {
    final values = <num>[];
    void visit(Object? node) {
      if (node is num) {
        values.add(node);
      } else if (node is Iterable) {
        for (final child in node) {
          visit(child);
        }
      }
    }

    visit(output);
    return values;
  }

  Future<Map<String, int>> _loadVocab() async {
    final vocabText = await _assetBundle.loadString(vocabAsset);
    final vocab = <String, int>{};
    var index = 0;
    for (final line in vocabText.split(RegExp(r'\r?\n'))) {
      final token = line.trim();
      if (token.isNotEmpty) vocab[token] = index;
      index += 1;
    }
    return vocab;
  }

  @override
  void close() {
    _interpreter?.close();
    _interpreter = null;
    _tokenizer = null;
    _isReady = false;
  }
}
