import 'dart:typed_data';

class ISLFeatureSchema {
  static const String version = 'isl_holistic_168_v1';
  static const int windowSize = 30;
  static const int featureSize = 168;

  static const int handLandmarkCount = 21;
  static const int handFeatureSize = handLandmarkCount * 3;
  static const int leftHandStart = 0;
  static const int rightHandStart = 63;
  static const int poseStart = 126;
  static const int poseLandmarkCount = 6;
  static const int faceStart = 144;

  static const List<String> poseLandmarkOrder = [
    'rightShoulder',
    'leftShoulder',
    'rightElbow',
    'leftElbow',
    'rightWrist',
    'leftWrist',
  ];

  static Map<String, Object> metadata() => {
    'schema_version': version,
    'collection_mode': 'single_or_two_hand_slots',
    'window_size': windowSize,
    'feature_size': featureSize,
    'normalization_anchor': 'right_shoulder',
    'layout': {
      'left_hand': '0..62, 21 landmarks x xyz',
      'right_hand': '63..125, 21 landmarks x xyz',
      'pose': '126..143, 6 landmarks x xyz',
      'face_nmm': '144..167, reserved zero-padded',
    },
    'pose_landmark_order': poseLandmarkOrder,
  };

  static void validateFrame(Float32List features) {
    if (features.length != featureSize) {
      throw StateError(
        'Expected $featureSize ISL features, got ${features.length}.',
      );
    }
  }
}

class ISLFeatureFrame {
  final DateTime timestamp;
  final Float32List features;
  final bool hasHand;
  final bool hasLeftHand;
  final bool hasRightHand;
  final bool hasPose;
  final int windowCount;

  const ISLFeatureFrame({
    required this.timestamp,
    required this.features,
    required this.hasHand,
    this.hasLeftHand = false,
    this.hasRightHand = false,
    required this.hasPose,
    required this.windowCount,
  });

  Map<String, Object> toJson() => {
    'timestamp': timestamp.toIso8601String(),
    'has_hand': hasHand,
    'has_left_hand': hasLeftHand,
    'has_right_hand': hasRightHand,
    'has_pose': hasPose,
    'window_count': windowCount,
    'features': features.toList(growable: false),
  };
}
