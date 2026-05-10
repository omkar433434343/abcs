enum DeviceTier { high, mid, low, budget }

class ISLPrediction {
  final String sign;
  final double confidence;
  final double margin;
  final DateTime timestamp;

  const ISLPrediction({
    required this.sign,
    required this.confidence,
    this.margin = 0,
    required this.timestamp,
  });
}

class PipelineStats {
  final double fps;
  final int droppedFrames;
  final double avgLatencyMs;
  final DeviceTier deviceTier;
  final bool hasHand;
  final bool hasLeftHand;
  final bool hasRightHand;
  final bool hasPose;
  final int windowCount;
  final String? topSign;
  final double topConfidence;
  final String inferenceStatus;

  const PipelineStats({
    required this.fps,
    required this.droppedFrames,
    required this.avgLatencyMs,
    required this.deviceTier,
    this.hasHand = false,
    this.hasLeftHand = false,
    this.hasRightHand = false,
    this.hasPose = false,
    this.windowCount = 0,
    this.topSign,
    this.topConfidence = 0,
    this.inferenceStatus = 'waiting',
  });

  PipelineStats copyWith({
    double? fps,
    int? droppedFrames,
    double? avgLatencyMs,
    DeviceTier? deviceTier,
    bool? hasHand,
    bool? hasLeftHand,
    bool? hasRightHand,
    bool? hasPose,
    int? windowCount,
    String? topSign,
    double? topConfidence,
    String? inferenceStatus,
  }) {
    return PipelineStats(
      fps: fps ?? this.fps,
      droppedFrames: droppedFrames ?? this.droppedFrames,
      avgLatencyMs: avgLatencyMs ?? this.avgLatencyMs,
      deviceTier: deviceTier ?? this.deviceTier,
      hasHand: hasHand ?? this.hasHand,
      hasLeftHand: hasLeftHand ?? this.hasLeftHand,
      hasRightHand: hasRightHand ?? this.hasRightHand,
      hasPose: hasPose ?? this.hasPose,
      windowCount: windowCount ?? this.windowCount,
      topSign: topSign ?? this.topSign,
      topConfidence: topConfidence ?? this.topConfidence,
      inferenceStatus: inferenceStatus ?? this.inferenceStatus,
    );
  }

  @override
  String toString() {
    return 'PipelineStats(fps: ${fps.toStringAsFixed(1)}, '
        'droppedFrames: $droppedFrames, '
        'avgLatencyMs: ${avgLatencyMs.toStringAsFixed(2)}, '
        'deviceTier: ${deviceTier.name}, '
        'hasHand: $hasHand, '
        'hasLeftHand: $hasLeftHand, '
        'hasRightHand: $hasRightHand, '
        'hasPose: $hasPose, '
        'windowCount: $windowCount, '
        'topSign: $topSign, '
        'topConfidence: ${topConfidence.toStringAsFixed(2)}, '
        'inferenceStatus: $inferenceStatus)';
  }
}
