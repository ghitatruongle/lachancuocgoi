import 'dart:async';
import 'dart:io';
import 'dart:isolate';

import 'package:flutter/foundation.dart';
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

  Isolate? _isolate;
  SendPort? _isolateSendPort;
  bool _isReady = false;
  bool _hasAttemptedInit = false;

  int _lastInputHash = 0;
  int _lastInputLength = 0;
  List<IntentPrediction> _cachedResult = const <IntentPrediction>[];

  /// Mutex to serialise concurrent [predictIntent] calls.
  /// L2Analyzer runs intent + gDetection in parallel via Future.wait,
  /// and a transcript update mid-flight could race with cache writes.
  Future<void>? _inferenceMutex;

  @override
  bool get isReady => _isReady;

  @override
  Future<void> initialize() async {
    if (_hasAttemptedInit) return;
    _hasAttemptedInit = true;

    try {
      final vocab = await _loadVocab();
      final ByteData modelData = await _assetBundle.load(modelAsset);
      final Uint8List modelBytes = modelData.buffer.asUint8List(
        modelData.offsetInBytes,
        modelData.lengthInBytes,
      );

      final mainReceivePort = ReceivePort();
      _isolate = await Isolate.spawn(
        _isolateMain,
        mainReceivePort.sendPort,
        debugName: 'TFLiteIntentClassifierIsolate',
      );

      final dynamic firstMsg = await mainReceivePort.first;
      if (firstMsg is SendPort) {
        _isolateSendPort = firstMsg;
      } else {
        throw StateError('Failed to get SendPort from background Isolate.');
      }

      final responsePort = ReceivePort();
      _isolateSendPort!.send(
        _IsolateInitRequest(
          modelBytes: modelBytes,
          vocab: vocab,
          replyPort: responsePort.sendPort,
        ),
      );

      final dynamic initResponse = await responsePort.first;
      responsePort.close();

      if (initResponse is _IsolateInitResponse) {
        if (initResponse.isReady) {
          _isReady = true;
        } else {
          throw StateError(
            initResponse.errorMessage ?? 'Isolate initialization failed.',
          );
        }
      } else {
        throw StateError('Invalid init response from background Isolate.');
      }
    } catch (e) {
      debugPrint('[TFLiteIntentClassifier] Initialization failed: $e');
      close();
      _isReady = false;
    }
  }

  @override
  Future<List<IntentPrediction>> predictIntent(String transcript) async {
    // Wait for any in-flight inference to complete before reading/writing cache.
    await _inferenceMutex;
    final completer = Completer<void>();
    _inferenceMutex = completer.future;

    try {
      if (!_isReady || _isolateSendPort == null) {
        throw StateError('TFLite model is not ready.');
      }
      if (transcript.trim().isEmpty) return const <IntentPrediction>[];

      final currentHash = transcript.hashCode;
      final lengthDelta = transcript.length - _lastInputLength;
      final changeRatio = _lastInputLength > 0
          ? lengthDelta / _lastInputLength
          : 1.0;
      if (currentHash == _lastInputHash) return _cachedResult;
      // Re-run inference if text changed (>= 20% growth). A negative ratio
      // (transcript shortened) falls through to re-run, since shorter
      // input is a meaningfully different inference problem.
      if (_cachedResult.isNotEmpty && changeRatio >= 0 && changeRatio < 0.20) {
        return _cachedResult;
      }

      final responsePort = ReceivePort();
      _isolateSendPort!.send(
        _IsolateInferenceRequest(
          transcript: transcript,
          replyPort: responsePort.sendPort,
        ),
      );

      final dynamic inferenceResponse = await responsePort.first;
      responsePort.close();

      if (inferenceResponse is _IsolateInferenceResponse) {
        if (inferenceResponse.errorMessage != null) {
          throw StateError(inferenceResponse.errorMessage!);
        }
        final predictions = inferenceResponse.predictions;
        _lastInputHash = currentHash;
        _lastInputLength = transcript.length;
        _cachedResult = predictions;
        return predictions;
      } else {
        throw StateError('Invalid inference response from background Isolate.');
      }
    } finally {
      completer.complete();
    }
  }

  @override
  void close() {
    // Prevent new inference requests
    _isReady = false;

    if (_isolateSendPort != null) {
      // Send 'CLOSE' message - isolate will finish current inference and exit gracefully
      _isolateSendPort!.send('CLOSE');
      _isolateSendPort = null;

      // Don't kill immediately! Let isolate finish in-flight inference.
      // The isolate exits when it processes the 'CLOSE' message from its queue.
      //
      // Safety: if isolate hangs (never processes CLOSE), force-kill after 5s
      final isolate = _isolate;
      if (isolate != null) {
        Timer(const Duration(seconds: 5), () {
          isolate.kill(priority: Isolate.immediate);
        });
      }
    }

    _isolate = null;
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
}

/// Isolate entry point
void _isolateMain(SendPort mainSendPort) async {
  final isolateReceivePort = ReceivePort();
  mainSendPort.send(isolateReceivePort.sendPort);

  Interpreter? interpreter;
  BertIntentTokenizer? tokenizer;
  IntentOutputType outputType = IntentOutputType.float32;
  double outputScale = 1;
  int outputZeroPoint = 0;

  await for (final dynamic message in isolateReceivePort) {
    if (message is _IsolateInitRequest) {
      try {
        final threadCount = Platform.numberOfProcessors.clamp(1, 4).toInt();
        final options = InterpreterOptions()..threads = threadCount;
        interpreter = Interpreter.fromBuffer(
          message.modelBytes,
          options: options,
        );

        final outputTensor = interpreter.getOutputTensor(0);
        final numClasses = outputTensor.shape.isEmpty
            ? 0
            : outputTensor.shape.last;

        if (numClasses != intentLabels.length) {
          debugPrint(
            '[TFLiteIntent] Model output classes ($numClasses) != app intents (${intentLabels.length}). '
            'Using min($numClasses, ${intentLabels.length}) classes.',
          );
        }

        outputType = switch (outputTensor.type) {
          TensorType.uint8 => IntentOutputType.uint8,
          TensorType.int8 => IntentOutputType.int8,
          _ => IntentOutputType.float32,
        };
        if (outputType != IntentOutputType.float32) {
          final params = outputTensor.params;
          outputScale = params.scale == 0 ? 1 : params.scale;
          outputZeroPoint = params.zeroPoint;
        }

        tokenizer = BertIntentTokenizer(message.vocab);

        message.replyPort.send(const _IsolateInitResponse(isReady: true));
      } catch (e) {
        interpreter?.close();
        interpreter = null;
        tokenizer = null;
        message.replyPort.send(
          _IsolateInitResponse(isReady: false, errorMessage: e.toString()),
        );
      }
    } else if (message is _IsolateInferenceRequest) {
      if (interpreter == null || tokenizer == null) {
        message.replyPort.send(
          const _IsolateInferenceResponse(
            predictions: <IntentPrediction>[],
            errorMessage: 'Interpreter or Tokenizer is not initialized.',
          ),
        );
        continue;
      }
      try {
        final tokens = tokenizer.tokenize(message.transcript);
        final inputs = tokenizer.buildInputs(tokens);

        final Object output = switch (outputType) {
          IntentOutputType.uint8 || IntentOutputType.int8 => <List<int>>[
            List<int>.filled(intentLabels.length, 0),
          ],
          IntentOutputType.float32 => <List<double>>[
            List<double>.filled(intentLabels.length, 0),
          ],
        };

        interpreter.runForMultipleInputs(
          <Object>[
            <List<int>>[inputs.inputIds],
            <List<int>>[inputs.attentionMask],
            <List<int>>[inputs.tokenTypeIds],
          ],
          <int, Object>{0: output},
        );

        // Flatten the multi-dimensional output array
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

        final logits = IntentOutputMapper.decodeFlatOutput(
          values,
          outputType: outputType,
          scale: outputScale,
          zeroPoint: outputZeroPoint,
        );
        final predictions = IntentOutputMapper.predictionsFromLogits(logits);

        message.replyPort.send(
          _IsolateInferenceResponse(predictions: predictions),
        );
      } catch (e) {
        message.replyPort.send(
          _IsolateInferenceResponse(
            predictions: const <IntentPrediction>[],
            errorMessage: e.toString(),
          ),
        );
      }
    } else if (message == 'CLOSE') {
      interpreter?.close();
      interpreter = null;
      tokenizer = null;
      isolateReceivePort.close();
      break;
    }
  }
}

class _IsolateInitRequest {
  const _IsolateInitRequest({
    required this.modelBytes,
    required this.vocab,
    required this.replyPort,
  });
  final Uint8List modelBytes;
  final Map<String, int> vocab;
  final SendPort replyPort;
}

class _IsolateInitResponse {
  const _IsolateInitResponse({required this.isReady, this.errorMessage});
  final bool isReady;
  final String? errorMessage;
}

class _IsolateInferenceRequest {
  const _IsolateInferenceRequest({
    required this.transcript,
    required this.replyPort,
  });
  final String transcript;
  final SendPort replyPort;
}

class _IsolateInferenceResponse {
  const _IsolateInferenceResponse({
    required this.predictions,
    this.errorMessage,
  });
  final List<IntentPrediction> predictions;
  final String? errorMessage;
}
