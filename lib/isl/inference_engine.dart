import 'dart:isolate';
import 'dart:math' as math;
import 'dart:typed_data';
import 'package:tflite_flutter/tflite_flutter.dart';
import 'feature_schema.dart';
import 'models/isl_prediction.dart';
import 'trained_signs.dart';

class ISLInferenceEngine {
  late Interpreter _interpreter;
  late List<String> _labels;
  final int windowSize = ISLFeatureSchema.windowSize;
  final int featureSize = ISLFeatureSchema.featureSize;

  late List<List<List<int>>> _inputTensor;
  late List<List<int>> _outputTensor;
  late double _inputScale;
  late int _inputZeroPoint;
  late double _outputScale;
  late int _outputZeroPoint;

  ISLInferenceEngine._();

  static Future<ISLInferenceEngine> create(
    List<String> labels,
    Uint8List modelBuffer,
  ) async {
    final instance = ISLInferenceEngine._();

    final options = InterpreterOptions()..threads = 2;

    instance._interpreter = Interpreter.fromBuffer(
      modelBuffer,
      options: options,
    );

    instance._labels = labels;

    final inputTensor = instance._interpreter.getInputTensor(0);
    final outputTensor = instance._interpreter.getOutputTensor(0);
    final inputShape = inputTensor.shape;
    final outputShape = outputTensor.shape;
    if (inputShape.length != 3 ||
        inputShape[1] != ISLFeatureSchema.windowSize ||
        inputShape[2] != ISLFeatureSchema.featureSize) {
      throw StateError(
        'ISL model input shape must be [1, ${ISLFeatureSchema.windowSize}, '
        '${ISLFeatureSchema.featureSize}], got $inputShape.',
      );
    }
    if (outputShape.isEmpty || outputShape.last != labels.length) {
      throw StateError(
        'ISL model output label count must be ${labels.length}, '
        'got shape $outputShape.',
      );
    }

    final inputParams = inputTensor.params;
    final outputParams = outputTensor.params;
    instance._inputScale = inputParams.scale;
    instance._inputZeroPoint = inputParams.zeroPoint;
    instance._outputScale = outputParams.scale;
    instance._outputZeroPoint = outputParams.zeroPoint;

    instance._inputTensor = List.generate(
      1,
      (_) => List.generate(
        ISLFeatureSchema.windowSize,
        (_) => List.filled(ISLFeatureSchema.featureSize, 0),
      ),
    );
    instance._outputTensor = List.generate(
      1,
      (_) => List.filled(labels.length, 0),
    );

    return instance;
  }

  ISLPrediction? infer(List<Float32List> window) {
    if (window.length != windowSize) return null;

    final oneHandLabel = _oneHandPositionLabel(window);
    if (oneHandLabel != null) {
      return ISLPrediction(
        sign: oneHandLabel,
        confidence: 0.95,
        margin: 0.95,
        timestamp: DateTime.now(),
      );
    }
    if (_isAmbiguousOneHandWindow(window)) return null;

    final twoHandLabel = _twoHandPositionLabel(window);
    if (twoHandLabel != null) {
      return ISLPrediction(
        sign: twoHandLabel,
        confidence: 0.95,
        margin: 0.95,
        timestamp: DateTime.now(),
      );
    }
    if (_isAmbiguousTwoHandWindow(window)) return null;

    final best = _bestFlexibleScore(window);

    final sign = _labels[best.index];
    if (!ISLTrainedSigns.isTrainedLabel(sign)) return null;

    return ISLPrediction(
      sign: sign,
      confidence: best.confidence,
      margin: best.margin,
      timestamp: DateTime.now(),
    );
  }

  String? _oneHandPositionLabel(List<Float32List> window) {
    final ratios = _handVisibilityRatios(window);
    final isOneHand =
        (ratios.left < 0.2 && ratios.right > 0.7) ||
        (ratios.right < 0.2 && ratios.left > 0.7);
    if (!isOneHand) return null;

    final handStart = ratios.right >= ratios.left
        ? ISLFeatureSchema.rightHandStart
        : ISLFeatureSchema.leftHandStart;
    final deltas = <double>[];
    for (final frame in window) {
      if (!_hasAnyFeature(
        frame,
        handStart,
        handStart + ISLFeatureSchema.handFeatureSize,
      )) {
        continue;
      }
      final handY = _averageY(
        frame,
        handStart,
        ISLFeatureSchema.handLandmarkCount,
      );
      final shoulderY =
          (frame[ISLFeatureSchema.poseStart + 1] +
              frame[ISLFeatureSchema.poseStart + 4]) /
          2;
      deltas.add(handY - shoulderY);
    }
    if (deltas.length < windowSize * 0.7) return null;

    final meanDelta = deltas.reduce((a, b) => a + b) / deltas.length;
    if (meanDelta < -0.12 && _isPalmFacingCamera(window, handStart)) {
      return 'BUKHAR';
    }
    if (meanDelta > 0.12) return 'PET-DARD';
    return null;
  }

  bool _isAmbiguousOneHandWindow(List<Float32List> window) {
    final ratios = _handVisibilityRatios(window);
    final isOneHand =
        (ratios.left < 0.2 && ratios.right > 0.7) ||
        (ratios.right < 0.2 && ratios.left > 0.7);
    if (!isOneHand) return false;
    return _oneHandPositionLabel(window) == null;
  }

  String? _twoHandPositionLabel(List<Float32List> window) {
    final ratios = _handVisibilityRatios(window);
    final isTwoHand = ratios.left > 0.7 && ratios.right > 0.7;
    if (!isTwoHand) return null;

    final deltas = <double>[];
    final wristDeltas = <double>[];
    for (final frame in window) {
      if (!_hasAnyFeature(
            frame,
            ISLFeatureSchema.leftHandStart,
            ISLFeatureSchema.rightHandStart,
          ) ||
          !_hasAnyFeature(
            frame,
            ISLFeatureSchema.rightHandStart,
            ISLFeatureSchema.poseStart,
          )) {
        continue;
      }
      final leftY = _averageY(
        frame,
        ISLFeatureSchema.leftHandStart,
        ISLFeatureSchema.handLandmarkCount,
      );
      final rightY = _averageY(
        frame,
        ISLFeatureSchema.rightHandStart,
        ISLFeatureSchema.handLandmarkCount,
      );
      final handsY = (leftY + rightY) / 2;
      final shoulderY =
          (frame[ISLFeatureSchema.poseStart + 1] +
              frame[ISLFeatureSchema.poseStart + 4]) /
          2;
      final wristY =
          (frame[ISLFeatureSchema.poseStart + 13] +
              frame[ISLFeatureSchema.poseStart + 16]) /
          2;
      deltas.add(handsY - shoulderY);
      wristDeltas.add(handsY - wristY);
    }
    if (deltas.length < windowSize * 0.7) return null;

    final meanDelta = deltas.reduce((a, b) => a + b) / deltas.length;
    final meanWristDelta =
        wristDeltas.reduce((a, b) => a + b) / wristDeltas.length;

    if (meanDelta < -0.10) return 'SAR-DARD';
    if (meanDelta > 0.07 && meanWristDelta.abs() < 0.04) {
      return 'SANS-TAKLEEF';
    }
    return null;
  }

  bool _isAmbiguousTwoHandWindow(List<Float32List> window) {
    final ratios = _handVisibilityRatios(window);
    final isTwoHand = ratios.left > 0.7 && ratios.right > 0.7;
    if (!isTwoHand) return false;
    return _twoHandPositionLabel(window) == null;
  }

  _HandRatios _handVisibilityRatios(List<Float32List> window) {
    var left = 0;
    var right = 0;
    for (final frame in window) {
      if (_hasAnyFeature(
        frame,
        ISLFeatureSchema.leftHandStart,
        ISLFeatureSchema.rightHandStart,
      )) {
        left++;
      }
      if (_hasAnyFeature(
        frame,
        ISLFeatureSchema.rightHandStart,
        ISLFeatureSchema.poseStart,
      )) {
        right++;
      }
    }
    return _HandRatios(left / window.length, right / window.length);
  }

  bool _hasAnyFeature(Float32List frame, int start, int end) {
    for (var i = start; i < end; i++) {
      if (frame[i].abs() > 1e-6) return true;
    }
    return false;
  }

  bool _isPalmFacingCamera(List<Float32List> window, int handStart) {
    var visibleFrames = 0;
    var palmFacingFrames = 0;

    for (final frame in window) {
      if (!_hasAnyFeature(
        frame,
        handStart,
        handStart + ISLFeatureSchema.handFeatureSize,
      )) {
        continue;
      }
      visibleFrames++;

      final palmZ =
          (_handValue(frame, handStart, 0, 2) +
              _handValue(frame, handStart, 5, 2) +
              _handValue(frame, handStart, 9, 2) +
              _handValue(frame, handStart, 17, 2)) /
          4;
      final fingertipZ =
          (_handValue(frame, handStart, 8, 2) +
              _handValue(frame, handStart, 12, 2) +
              _handValue(frame, handStart, 16, 2) +
              _handValue(frame, handStart, 20, 2)) /
          4;
      final palmWidth = _distance2D(frame, handStart, 5, 17);
      final palmHeight = _distance2D(frame, handStart, 0, 9);
      final openness = palmWidth / (palmHeight + 1e-6);

      if (fingertipZ - palmZ < -0.009 && openness > 0.40 && openness < 0.65) {
        palmFacingFrames++;
      }
    }

    return visibleFrames >= windowSize * 0.7 &&
        palmFacingFrames / visibleFrames >= 0.65;
  }

  double _handValue(
    Float32List frame,
    int handStart,
    int landmarkIndex,
    int axis,
  ) {
    return frame[handStart + (landmarkIndex * 3) + axis];
  }

  double _distance2D(
    Float32List frame,
    int handStart,
    int firstLandmark,
    int secondLandmark,
  ) {
    final dx =
        _handValue(frame, handStart, firstLandmark, 0) -
        _handValue(frame, handStart, secondLandmark, 0);
    final dy =
        _handValue(frame, handStart, firstLandmark, 1) -
        _handValue(frame, handStart, secondLandmark, 1);
    return math.sqrt((dx * dx) + (dy * dy));
  }

  double _averageY(Float32List frame, int start, int landmarkCount) {
    var sum = 0.0;
    for (var i = 0; i < landmarkCount; i++) {
      sum += frame[start + 1 + (i * 3)];
    }
    return sum / landmarkCount;
  }

  _Score _bestFlexibleScore(List<Float32List> window) {
    var best = _scoresForWindow(window);

    for (final candidate in _coordinateVariants(window)) {
      final score = _scoresForWindow(candidate);
      if (score.confidence > best.confidence) {
        best = score;
      }
    }

    return best;
  }

  Iterable<List<Float32List>> _coordinateVariants(
    List<Float32List> window,
  ) sync* {
    yield _transformWindow(window, mirrorX: true);
    yield _transformWindow(window, mirrorY: true);
    yield _transformWindow(window, mirrorX: true, mirrorY: true);

    yield _transformWindow(window, scale: 0.75);
    yield _transformWindow(window, scale: 1.25);
  }

  _Score _scoresForWindow(List<Float32List> window) {
    for (int t = 0; t < windowSize; t++) {
      if (window[t].length != featureSize) return const _Score(0, 0, 0);
      for (int f = 0; f < featureSize; f++) {
        _inputTensor[0][t][f] = _quantizeInput(window[t][f]);
      }
    }

    _interpreter.runForMultipleInputs([_inputTensor], {0: _outputTensor});

    final scores = _outputTensor[0]
        .map((score) => (score - _outputZeroPoint) * _outputScale)
        .toList(growable: false);
    int argmax = 0;
    double maxConf = scores[0];
    double secondConf = double.negativeInfinity;
    for (int i = 1; i < scores.length; i++) {
      if (scores[i] > maxConf) {
        secondConf = maxConf;
        maxConf = scores[i];
        argmax = i;
      } else if (scores[i] > secondConf) {
        secondConf = scores[i];
      }
    }
    if (secondConf == double.negativeInfinity) secondConf = 0;

    return _Score(argmax, maxConf, maxConf - secondConf);
  }

  List<Float32List> _transformWindow(
    List<Float32List> window, {
    bool mirrorX = false,
    bool mirrorY = false,
    double scale = 1.0,
  }) {
    return window
        .map((frame) {
          final transformed = Float32List.fromList(frame);
          for (var i = 0; i < featureSize; i += 3) {
            if (mirrorX) transformed[i] = -transformed[i];
            if (mirrorY) transformed[i + 1] = -transformed[i + 1];
            if (scale != 1.0) {
              transformed[i] *= scale;
              transformed[i + 1] *= scale;
              transformed[i + 2] *= scale;
            }
          }
          return transformed;
        })
        .toList(growable: false);
  }

  void close() {
    _interpreter.close();
  }

  int _quantizeInput(double value) {
    final quantized = (value / _inputScale + _inputZeroPoint).round();
    return quantized.clamp(-128, 127).toInt();
  }
}

class _Score {
  final int index;
  final double confidence;
  final double margin;
  const _Score(this.index, this.confidence, this.margin);
}

class _HandRatios {
  final double left;
  final double right;

  const _HandRatios(this.left, this.right);
}

class InferMessage {
  final List<Float32List> window;
  final SendPort replyPort;
  const InferMessage(this.window, this.replyPort);
}

class InferIsolateConfig {
  final SendPort mainSendPort;
  final List<String> labels;
  final TransferableTypedData modelData;
  const InferIsolateConfig(this.mainSendPort, this.labels, this.modelData);
}

class InferBootResult {
  final SendPort? sendPort;
  final String? error;

  const InferBootResult.ready(this.sendPort) : error = null;
  const InferBootResult.failed(this.error) : sendPort = null;
}

Future<void> inferenceIsolateEntry(InferIsolateConfig config) async {
  final receivePort = ReceivePort();

  late final ISLInferenceEngine engine;
  try {
    final modelBuffer = config.modelData.materialize().asUint8List();
    engine = await ISLInferenceEngine.create(config.labels, modelBuffer);
    config.mainSendPort.send(InferBootResult.ready(receivePort.sendPort));
  } catch (e) {
    config.mainSendPort.send(InferBootResult.failed(e.toString()));
    receivePort.close();
    return;
  }

  await for (final message in receivePort) {
    if (message == null) {
      engine.close();
      receivePort.close();
      break;
    }

    if (message is InferMessage) {
      try {
        final result = engine.infer(message.window);
        message.replyPort.send(result);
      } catch (_) {
        message.replyPort.send(null);
      }
    }
  }
}
