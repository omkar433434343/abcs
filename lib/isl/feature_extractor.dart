import 'dart:typed_data';
import 'dart:isolate';
import 'package:camera/camera.dart';
import 'package:flutter/services.dart';
import 'package:google_mlkit_pose_detection/google_mlkit_pose_detection.dart';
import 'package:hand_landmarker/hand_landmarker.dart';
import 'feature_schema.dart';

// ---------------------------------------------------------------------------
// Helper message type for isolate communication
// ---------------------------------------------------------------------------

class PipelineOverlayFrame {
  final List<Offset> leftHand;
  final List<Offset> rightHand;
  final List<Offset> pose;

  const PipelineOverlayFrame({
    this.leftHand = const <Offset>[],
    this.rightHand = const <Offset>[],
    this.pose = const <Offset>[],
  });

  bool get hasHand => leftHand.isNotEmpty || rightHand.isNotEmpty;
  bool get hasPose => pose.isNotEmpty;
}

class FrameMessage {
  final CameraImage image;
  final int sensorOrientation;
  final SendPort replyPort;
  const FrameMessage(this.image, this.sensorOrientation, this.replyPort);
}

// ---------------------------------------------------------------------------
// SelectiveHolisticExtractor
// ---------------------------------------------------------------------------

/// Runs inside Isolate 1.
/// Takes a [CameraImage], runs MLKit pose + hand detection, extracts 168
/// specific floats, normalises them relative to the right shoulder anchor,
/// and returns a pre-allocated [Float32List].
///
/// Layout of the 168-float output buffer:
///   [0   – 62]  Left hand  : zero-padded for one-hand collection
///   [63  – 125] Right hand : detected hand, 21 landmarks × 3 (x, y, z)
///   [126 – 143] Pose body  :  6 landmarks × 3 (x, y, z)
///   [144 – 167] Face/NMM  :  8 face mesh × 3  (zero-padded)
class SelectiveHolisticExtractor {
  final PoseDetector _poseDetector;
  final HandLandmarkerPlugin _handDetector;

  // Pre-allocated output buffer — never allocate inside extract().
  final Float32List _output = Float32List(ISLFeatureSchema.featureSize);
  PipelineOverlayFrame _lastOverlay = const PipelineOverlayFrame();

  SelectiveHolisticExtractor._(this._poseDetector, this._handDetector);

  PipelineOverlayFrame get lastOverlay => _lastOverlay;

  /// Creates a [SelectiveHolisticExtractor] with the recommended detector
  /// settings for real-time ISL recognition.
  static SelectiveHolisticExtractor create() {
    final poseDetector = PoseDetector(
      options: PoseDetectorOptions(
        model: PoseDetectionModel.base,
        mode: PoseDetectionMode.stream,
      ),
    );

    final handDetector = HandLandmarkerPlugin.create(
      numHands: 2,
      minHandDetectionConfidence: 0.5,
      delegate: HandLandmarkerDelegate.gpu,
    );

    return SelectiveHolisticExtractor._(poseDetector, handDetector);
  }

  // -------------------------------------------------------------------------
  // extract
  // -------------------------------------------------------------------------

  /// Processes [image] through the pose and hand detectors concurrently and
  /// returns the pre-allocated [Float32List] filled with 168 normalised floats.
  ///
  /// IMPORTANT: The returned list is the same pre-allocated instance every
  /// call. The caller must fully consume / copy the data before calling
  /// [extract] again.
  Future<Float32List> extract(CameraImage image, int sensorOrientation) async {
    final rotated = sensorOrientation == 90 || sensorOrientation == 270;
    final poseWidth = rotated
        ? image.height.toDouble()
        : image.width.toDouble();
    final poseHeight = rotated
        ? image.width.toDouble()
        : image.height.toDouble();

    // ------------------------------------------------------------------
    // Step 1: Convert CameraImage to InputImage
    // ------------------------------------------------------------------
    final inputImage = InputImage.fromBytes(
      bytes: _toNv21(image),
      metadata: InputImageMetadata(
        size: Size(image.width.toDouble(), image.height.toDouble()),
        rotation:
            InputImageRotationValue.fromRawValue(sensorOrientation) ??
            InputImageRotation.rotation0deg,
        format: InputImageFormat.nv21,
        bytesPerRow: image.planes[0].bytesPerRow,
      ),
    );

    // ------------------------------------------------------------------
    // Step 2: Run both detectors concurrently
    // ------------------------------------------------------------------
    final results = await Future.wait([
      _poseDetector.processImage(inputImage),
      Future<List<Hand>>(() {
        if (image.planes.length < 3) return <Hand>[];
        return _handDetector.detect(image, sensorOrientation);
      }),
    ]);
    final List<Pose> poses = results[0] as List<Pose>;
    final List<Hand> hands = results[1] as List<Hand>;

    // ------------------------------------------------------------------
    // Step 3: Extract normalisation anchor (right shoulder, index 12)
    // ------------------------------------------------------------------
    double anchorX = 0.0, anchorY = 0.0, anchorZ = 0.0;
    if (poses.isNotEmpty) {
      final shoulder = poses.first.landmarks[PoseLandmarkType.rightShoulder];
      if (shoulder != null) {
        anchorX = shoulder.x / poseWidth;
        anchorY = shoulder.y / poseHeight;
        anchorZ = shoulder.z / poseWidth;
      }
    }

    // ------------------------------------------------------------------
    // Step 4: Fill output buffer
    // ------------------------------------------------------------------

    final handsBySide = _handsBySide(hands);
    final posePoints = <Offset>[];

    // -- 4a: Left hand slot is used when two hands are visible.
    _fillHandLandmarks(
      hand: handsBySide.left,
      startIndex: 0,
      sensorOrientation: sensorOrientation,
      anchorX: anchorX,
      anchorY: anchorY,
      anchorZ: anchorZ,
    );

    // -- 4b: Store a single detected hand in the right hand slot.
    _fillHandLandmarks(
      hand: handsBySide.right,
      startIndex: 63,
      sensorOrientation: sensorOrientation,
      anchorX: anchorX,
      anchorY: anchorY,
      anchorZ: anchorZ,
    );

    // -- 4c: Pose body landmarks (indices 126–143), 6 landmarks × 3 -----
    // Order: rightShoulder(12), leftShoulder(11), rightElbow(14),
    //        leftElbow(13), rightWrist(16), leftWrist(15)
    const List<PoseLandmarkType> poseTypes = [
      PoseLandmarkType.rightShoulder, // 12
      PoseLandmarkType.leftShoulder, // 11
      PoseLandmarkType.rightElbow, // 14
      PoseLandmarkType.leftElbow, // 13
      PoseLandmarkType.rightWrist, // 16
      PoseLandmarkType.leftWrist, // 15
    ];

    int poseOffset = ISLFeatureSchema.poseStart;
    for (final type in poseTypes) {
      if (poses.isNotEmpty) {
        final lm = poses.first.landmarks[type];
        if (lm != null) {
          final x = lm.x / poseWidth;
          final y = lm.y / poseHeight;
          final z = lm.z / poseWidth;
          posePoints.add(Offset(x, y));
          _output[poseOffset] = x - anchorX;
          _output[poseOffset + 1] = y - anchorY;
          _output[poseOffset + 2] = z - anchorZ;
        } else {
          _output[poseOffset] = 0.0;
          _output[poseOffset + 1] = 0.0;
          _output[poseOffset + 2] = 0.0;
        }
      } else {
        _output[poseOffset] = 0.0;
        _output[poseOffset + 1] = 0.0;
        _output[poseOffset + 2] = 0.0;
      }
      poseOffset += 3;
    }

    // -- 4d: Face/NMM landmarks (indices 144–167), 8 × 3 ----------------
    // Face mesh requires google_mlkit_face_mesh — zero-padded for now
    for (
      int i = ISLFeatureSchema.faceStart;
      i < ISLFeatureSchema.featureSize;
      i++
    ) {
      _output[i] = 0.0;
    }

    _lastOverlay = PipelineOverlayFrame(
      leftHand: _normalizedHandPoints(handsBySide.left, sensorOrientation),
      rightHand: _normalizedHandPoints(handsBySide.right, sensorOrientation),
      pose: List<Offset>.unmodifiable(posePoints),
    );

    // ------------------------------------------------------------------
    // Step 5: Return pre-allocated buffer
    // ------------------------------------------------------------------
    return _output;
  }

  // -------------------------------------------------------------------------
  // close
  // -------------------------------------------------------------------------

  Future<void> close() async {
    await _poseDetector.close();
    _handDetector.dispose();
  }

  Uint8List _toNv21(CameraImage image) {
    if (image.planes.length == 1) return image.planes.first.bytes;

    final width = image.width;
    final height = image.height;
    final yPlane = image.planes[0];
    final uPlane = image.planes[1];
    final vPlane = image.planes[2];
    final out = Uint8List(width * height + (width * height ~/ 2));

    var offset = 0;
    for (var row = 0; row < height; row++) {
      final rowStart = row * yPlane.bytesPerRow;
      out.setRange(offset, offset + width, yPlane.bytes, rowStart);
      offset += width;
    }

    final uvHeight = height ~/ 2;
    final uvWidth = width ~/ 2;
    final uPixelStride = uPlane.bytesPerPixel ?? 1;
    final vPixelStride = vPlane.bytesPerPixel ?? 1;
    for (var row = 0; row < uvHeight; row++) {
      for (var col = 0; col < uvWidth; col++) {
        final uIndex = row * uPlane.bytesPerRow + col * uPixelStride;
        final vIndex = row * vPlane.bytesPerRow + col * vPixelStride;
        out[offset++] = vPlane.bytes[vIndex];
        out[offset++] = uPlane.bytes[uIndex];
      }
    }
    return out;
  }

  // -------------------------------------------------------------------------
  // Private helpers
  // -------------------------------------------------------------------------

  /// A single detected hand is written into the right-hand slot for
  /// compatibility with older samples. When two hands are visible, both slots
  /// are populated and the model learns from the full feature window.
  _HandsBySide _handsBySide(List<Hand> hands) {
    if (hands.isEmpty) return const _HandsBySide();
    if (hands.length == 1) return _HandsBySide(right: hands.first);

    final sorted = List<Hand>.from(hands)
      ..sort((a, b) => _averageHandX(a).compareTo(_averageHandX(b)));
    return _HandsBySide(left: sorted.first, right: sorted.last);
  }

  double _averageHandX(Hand hand) {
    if (hand.landmarks.isEmpty) return 0;
    var sum = 0.0;
    for (final landmark in hand.landmarks) {
      sum += landmark.x;
    }
    return sum / hand.landmarks.length;
  }

  /// Fills 63 floats (21 landmarks × 3) in [_output] starting at [startIndex].
  /// If [hand] is null, writes 0.0 for all 63 values (zero-pad).
  List<Offset> _normalizedHandPoints(Hand? hand, int sensorOrientation) {
    if (hand == null) return const <Offset>[];
    return List<Offset>.unmodifiable(
      hand.landmarks.map((lm) => _normalizeHandPoint(lm, sensorOrientation)),
    );
  }

  Offset _normalizeHandPoint(Landmark lm, int sensorOrientation) {
    final x = lm.x;
    final y = lm.y;

    final rotated = switch (sensorOrientation) {
      90 => Offset(y, 1 - x),
      180 => Offset(1 - x, 1 - y),
      270 => Offset(1 - y, x),
      _ => Offset(x, y),
    };

    return Offset(1 - rotated.dx, 1 - rotated.dy);
  }

  void _fillHandLandmarks({
    required Hand? hand,
    required int startIndex,
    required int sensorOrientation,
    required double anchorX,
    required double anchorY,
    required double anchorZ,
  }) {
    if (hand == null) {
      for (
        int i = startIndex;
        i < startIndex + ISLFeatureSchema.handFeatureSize;
        i++
      ) {
        _output[i] = 0.0;
      }
      return;
    }

    int offset = startIndex;
    for (int lmIndex = 0; lmIndex < 21; lmIndex++) {
      if (lmIndex < hand.landmarks.length) {
        final lm = hand.landmarks[lmIndex];
        final point = _normalizeHandPoint(lm, sensorOrientation);
        _output[offset] = point.dx - anchorX;
        _output[offset + 1] = point.dy - anchorY;
        _output[offset + 2] = lm.z - anchorZ;
      } else {
        _output[offset] = 0.0;
        _output[offset + 1] = 0.0;
        _output[offset + 2] = 0.0;
      }
      offset += 3;
    }
  }
}

class _HandsBySide {
  final Hand? left;
  final Hand? right;

  const _HandsBySide({this.left, this.right});
}

// ---------------------------------------------------------------------------
// Isolate entry point
// ---------------------------------------------------------------------------

/// Top-level isolate entry point. Pass this to [Isolate.spawn].
///
/// Protocol:
///   • Sends its own [SendPort] to [mainSendPort] so the main isolate can
///     forward [FrameMessage] objects.
///   • On each [FrameMessage]: extracts features and sends the resulting
///     [Float32List] back via [FrameMessage.replyPort].
///   • On receiving `null`: shuts down cleanly.
///   • Errors during extraction are caught; zeros ([Float32List(168)]) are
///     sent back so the isolate never crashes.
Future<void> featureExtractorIsolateEntry(SendPort mainSendPort) async {
  final receivePort = ReceivePort();

  // Tell the main isolate where to send frames.
  mainSendPort.send(receivePort.sendPort);

  final extractor = SelectiveHolisticExtractor.create();

  await for (final message in receivePort) {
    // Null is the shutdown signal.
    if (message == null) {
      await extractor.close();
      receivePort.close();
      break;
    }

    if (message is FrameMessage) {
      Float32List result;
      try {
        result = await extractor.extract(
          message.image,
          message.sensorOrientation,
        );
      } catch (_) {
        // Never crash the isolate — send back a zero buffer on error.
        result = Float32List(ISLFeatureSchema.featureSize);
      }
      message.replyPort.send(result);
    }
  }
}
