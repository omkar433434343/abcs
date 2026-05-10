import 'dart:async';
import 'dart:convert';
import 'dart:isolate';
import 'package:camera/camera.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'feature_schema.dart';
import 'feature_extractor.dart';
import 'inference_engine.dart';
import 'sign_debouncer.dart';
import 'trained_signs.dart';
import 'window_buffer.dart';
import 'models/isl_prediction.dart';

class ISLPipeline {
  CameraController? _cameraController;
  SelectiveHolisticExtractor? _extractor;
  final SlidingWindowBuffer _windowBuffer = SlidingWindowBuffer();
  final SignDebouncer _debouncer = SignDebouncer();

  Isolate? _inferenceIsolate;
  SendPort? _inferenceSendPort;

  final StreamController<String> _signStreamController =
      StreamController<String>.broadcast();
  final StreamController<PipelineStats> _statsStreamController =
      StreamController<PipelineStats>.broadcast();
  final StreamController<bool> _trackingStreamController =
      StreamController<bool>.broadcast();
  final StreamController<PipelineOverlayFrame> _overlayStreamController =
      StreamController<PipelineOverlayFrame>.broadcast();
  final StreamController<ISLFeatureFrame> _featureFrameStreamController =
      StreamController<ISLFeatureFrame>.broadcast();

  int _frameCount = 0;
  int _droppedCount = 0;
  final List<double> _latencySamples = [];
  DateTime _statsWindowStart = DateTime.now();
  Timer? _statsTimer;
  bool _hasHand = false;
  bool _hasLeftHand = false;
  bool _hasRightHand = false;
  bool _hasPose = false;
  ISLPrediction? _lastPrediction;
  String _inferenceStatus = 'waiting for hand/body';
  static const double _emitConfidenceThreshold = 0.82;
  static const double _emitMarginThreshold = 0.22;

  bool _isInitialised = false;
  bool _isDisposed = false;
  bool _isProcessing = false;
  bool _isInferring = false;
  DateTime _frameStart = DateTime.now();

  Stream<String> get signStream => _signStreamController.stream;
  Stream<PipelineStats> get statsStream => _statsStreamController.stream;
  Stream<bool> get trackingStream => _trackingStreamController.stream;
  Stream<PipelineOverlayFrame> get overlayStream =>
      _overlayStreamController.stream;
  Stream<ISLFeatureFrame> get featureFrameStream =>
      _featureFrameStreamController.stream;
  bool get isInitialised => _isInitialised;

  Future<void> init(CameraController controller) async {
    if (_isDisposed) throw StateError('ISLPipeline has been disposed');

    _cameraController = controller;

    final labelsJson = await rootBundle.loadString('assets/isl_labels.json');
    final labelsData = jsonDecode(labelsJson) as Map<String, dynamic>;
    final labels = List<String>.from(labelsData['labels'] as List);
    final trainedLabels = ISLTrainedSigns.labels;
    if (labels.any((label) => !trainedLabels.contains(label))) {
      throw StateError('assets/isl_labels.json contains untrained ISL labels.');
    }

    final modelBytes = await rootBundle.load(
      'assets/models/isl_lstm_int8.tflite',
    );
    final modelData = TransferableTypedData.fromList([
      modelBytes.buffer.asUint8List(
        modelBytes.offsetInBytes,
        modelBytes.lengthInBytes,
      ),
    ]);

    _extractor = SelectiveHolisticExtractor.create();

    final inferBootPort = ReceivePort();
    _inferenceIsolate = await Isolate.spawn(
      inferenceIsolateEntry,
      InferIsolateConfig(inferBootPort.sendPort, labels, modelData),
    );
    final bootResult = await inferBootPort.first as InferBootResult;
    inferBootPort.close();
    if (bootResult.error != null || bootResult.sendPort == null) {
      throw StateError(
        'Failed to link ISL TFLite model: ${bootResult.error ?? 'unknown'}',
      );
    }
    _inferenceSendPort = bootResult.sendPort;

    await controller.startImageStream(_onCameraFrame);

    _statsTimer = Timer.periodic(
      const Duration(seconds: 1),
      (_) => _emitStats(),
    );
    _isInitialised = true;
  }

  void _onCameraFrame(CameraImage image) {
    if (_isProcessing) {
      _droppedCount++;
      return;
    }

    _isProcessing = true;
    _frameStart = DateTime.now();
    _frameCount++;
    _extractFrame(image);
  }

  Future<void> _extractFrame(CameraImage image) async {
    try {
      final features = await _extractor!.extract(
        image,
        _cameraController!.description.sensorOrientation,
      );
      if (!_overlayStreamController.isClosed) {
        _overlayStreamController.add(_extractor!.lastOverlay);
      }
      if (!_isDisposed) _onFeatureExtracted(features);
    } catch (e, st) {
      if (!_trackingStreamController.isClosed) {
        _trackingStreamController.add(false);
      }
      if (!_overlayStreamController.isClosed) {
        _overlayStreamController.add(const PipelineOverlayFrame());
      }
      if (!_signStreamController.isClosed) {
        _signStreamController.addError(e, st);
      }
      _isProcessing = false;
    }
  }

  void _onFeatureExtracted(Float32List features) {
    ISLFeatureSchema.validateFrame(features);
    _hasLeftHand = _featuresHaveLeftHand(features);
    _hasRightHand = _featuresHaveRightHand(features);
    _hasHand = _hasLeftHand || _hasRightHand;
    _hasPose = _featuresHavePose(features);

    if (!_hasHand || !_hasPose) {
      _windowBuffer.clear();
      _debouncer.reset();
      _inferenceStatus = 'waiting for hand/body';
      if (!_trackingStreamController.isClosed) {
        _trackingStreamController.add(false);
      }
      if (!_overlayStreamController.isClosed) {
        _overlayStreamController.add(const PipelineOverlayFrame());
      }
      _isProcessing = false;
      return;
    }

    if (!_trackingStreamController.isClosed) {
      _trackingStreamController.add(true);
    }

    _windowBuffer.push(features);
    if (!_featureFrameStreamController.isClosed) {
      _featureFrameStreamController.add(
        ISLFeatureFrame(
          timestamp: DateTime.now(),
          features: Float32List.fromList(features),
          hasHand: _hasHand,
          hasLeftHand: _hasLeftHand,
          hasRightHand: _hasRightHand,
          hasPose: _hasPose,
          windowCount: _windowBuffer.count,
        ),
      );
    }

    _isProcessing = false;
    if (!_windowBuffer.isFull) {
      _inferenceStatus =
          'collecting window ${_windowBuffer.count}/${ISLFeatureSchema.windowSize}';
      return;
    }
    if (_isInferring) {
      _inferenceStatus = 'landmarks live, inference busy';
      return;
    }

    _isInferring = true;
    _inferenceStatus = 'running TFLite';
    final replyPort = ReceivePort();
    var replyHandled = false;
    Timer? inferenceTimeout;
    void finishInference({String? status}) {
      if (replyHandled) return;
      replyHandled = true;
      if (status != null) _inferenceStatus = status;
      inferenceTimeout?.cancel();
      replyPort.close();
      _isInferring = false;
    }

    inferenceTimeout = Timer(
      const Duration(seconds: 3),
      () => finishInference(status: 'TFLite timeout'),
    );
    replyPort.first
        .then((result) {
          final prediction = result as ISLPrediction?;
          _onPrediction(prediction);
          finishInference(
            status: prediction == null
                ? 'TFLite returned no sign'
                : 'TFLite OK',
          );
        })
        .catchError((_) {
          finishInference(status: 'TFLite error');
        });

    final windowSnapshot = _windowBuffer.paddedWindow
        .map(Float32List.fromList)
        .toList(growable: false);
    _inferenceSendPort!.send(InferMessage(windowSnapshot, replyPort.sendPort));
  }

  bool _featuresHaveLeftHand(Float32List features) {
    for (
      var i = ISLFeatureSchema.leftHandStart;
      i < ISLFeatureSchema.rightHandStart;
      i++
    ) {
      if (features[i].abs() > 1e-6) {
        return true;
      }
    }
    return false;
  }

  bool _featuresHaveRightHand(Float32List features) {
    for (
      var i = ISLFeatureSchema.rightHandStart;
      i < ISLFeatureSchema.poseStart;
      i++
    ) {
      if (features[i].abs() > 1e-6) {
        return true;
      }
    }
    return false;
  }

  bool _featuresHavePose(Float32List features) {
    for (
      var i = ISLFeatureSchema.poseStart;
      i < ISLFeatureSchema.faceStart;
      i++
    ) {
      if (features[i].abs() > 1e-6) {
        return true;
      }
    }
    return false;
  }

  void _onPrediction(ISLPrediction? prediction) {
    final latencyMs = DateTime.now()
        .difference(_frameStart)
        .inMilliseconds
        .toDouble();
    _latencySamples.add(latencyMs);

    if (prediction == null) return;
    _lastPrediction = prediction;
    _inferenceStatus =
        '${prediction.sign} ${(prediction.confidence * 100).toStringAsFixed(0)}%';
    debugPrint(
      '[ISL Pipeline] predicted=${prediction.sign} '
      'confidence=${prediction.confidence.toStringAsFixed(3)} '
      'margin=${prediction.margin.toStringAsFixed(3)}',
    );
    if (ISLTrainedSigns.isNoSignLabel(prediction.sign)) {
      _debouncer.reset();
      return;
    }
    if (prediction.confidence < _emitConfidenceThreshold) return;
    if (prediction.margin < _emitMarginThreshold) return;

    final emitted = _debouncer.process(prediction.sign);
    if (emitted != null && !_signStreamController.isClosed) {
      debugPrint('[ISL Pipeline] emitted=$emitted');
      _signStreamController.add(emitted);
    }
  }

  void _emitStats() {
    if (_statsStreamController.isClosed) return;
    final elapsed =
        DateTime.now().difference(_statsWindowStart).inMilliseconds / 1000.0;
    final fps = elapsed > 0 ? _frameCount / elapsed : 0.0;
    final avgLatency = _latencySamples.isEmpty
        ? 0.0
        : _latencySamples.reduce((a, b) => a + b) / _latencySamples.length;

    _statsStreamController.add(
      PipelineStats(
        fps: fps,
        droppedFrames: _droppedCount,
        avgLatencyMs: avgLatency,
        deviceTier: _classifyDevice(fps),
        hasHand: _hasHand,
        hasLeftHand: _hasLeftHand,
        hasRightHand: _hasRightHand,
        hasPose: _hasPose,
        windowCount: _windowBuffer.count,
        topSign: _lastPrediction?.sign,
        topConfidence: _lastPrediction?.confidence ?? 0,
        inferenceStatus: _inferenceStatus,
      ),
    );

    _frameCount = 0;
    _droppedCount = 0;
    _latencySamples.clear();
    _statsWindowStart = DateTime.now();
  }

  DeviceTier _classifyDevice(double fps) {
    if (fps >= 25) return DeviceTier.high;
    if (fps >= 15) return DeviceTier.mid;
    if (fps >= 8) return DeviceTier.low;
    return DeviceTier.budget;
  }

  Future<void> dispose() async {
    if (_isDisposed) return;
    _isDisposed = true;
    _isInitialised = false;

    _statsTimer?.cancel();

    try {
      await _cameraController?.stopImageStream();
    } catch (_) {}

    await _extractor?.close();

    _inferenceSendPort?.send(null);
    await Future.delayed(const Duration(milliseconds: 100));
    _inferenceIsolate?.kill(priority: Isolate.immediate);

    await _signStreamController.close();
    await _statsStreamController.close();
    await _trackingStreamController.close();
    await _overlayStreamController.close();
    await _featureFrameStreamController.close();

    _windowBuffer.clear();
    _debouncer.reset();
  }
}
