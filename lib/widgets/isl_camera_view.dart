import 'dart:async';
import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import '../isl/feature_schema.dart';
import '../isl/feature_extractor.dart';
import '../isl/isl_pipeline.dart';
import '../isl/models/isl_prediction.dart';

class ISLCameraView extends StatefulWidget {
  const ISLCameraView({
    super.key,
    required this.onSign,
    this.onStats,
    this.onFeatureFrame,
  });

  final void Function(String sign) onSign;
  final void Function(PipelineStats stats)? onStats;
  final void Function(ISLFeatureFrame frame)? onFeatureFrame;

  @override
  State<ISLCameraView> createState() => _ISLCameraViewState();
}

class _ISLCameraViewState extends State<ISLCameraView> {
  ISLPipeline? _pipeline;
  CameraController? _cameraController;

  String _currentSign = '';
  double _confidence = 0.0;
  bool _isTracking = false;
  PipelineOverlayFrame _overlayFrame = const PipelineOverlayFrame();
  PipelineStats? _stats;
  bool _isLoading = true;
  String? _errorMessage;

  StreamSubscription<String>? _signSub;
  StreamSubscription<PipelineStats>? _statsSub;
  StreamSubscription<bool>? _trackingSub;
  StreamSubscription<PipelineOverlayFrame>? _overlaySub;
  StreamSubscription<ISLFeatureFrame>? _featureFrameSub;
  Timer? _clearSignTimer;

  @override
  void initState() {
    super.initState();
    _initialise();
  }

  Future<void> _initialise() async {
    final cameras = await availableCameras();
    if (cameras.isEmpty) {
      setState(() {
        _errorMessage = 'No cameras available on this device.';
        _isLoading = false;
      });
      return;
    }

    final camera = cameras.firstWhere(
      (cam) => cam.lensDirection == CameraLensDirection.back,
      orElse: () => cameras.first,
    );

    _cameraController = CameraController(
      camera,
      ResolutionPreset.medium,
      enableAudio: false,
    );
    try {
      await _cameraController!.initialize();
    } on CameraException catch (e) {
      setState(() {
        _errorMessage = e.code == 'CameraAccessDenied'
            ? 'Camera permission denied. Please grant camera access in Settings.'
            : 'Camera error: ${e.description}';
        _isLoading = false;
      });
      return;
    }

    _pipeline = ISLPipeline();
    try {
      await _pipeline!.init(_cameraController!);
    } catch (e) {
      setState(() {
        _errorMessage = 'Failed to initialise ISL pipeline: $e';
        _isLoading = false;
      });
      return;
    }

    _signSub = _pipeline!.signStream.listen(
      (sign) {
        debugPrint('[ISL CameraView] signStream emitted=$sign');
        setState(() => _currentSign = sign);
        _clearSignTimer?.cancel();
        _clearSignTimer = Timer(const Duration(milliseconds: 900), () {
          if (mounted) setState(() => _currentSign = '');
        });
        widget.onSign(sign);
      },
      onError: (Object error) {
        if (!mounted) return;
        setState(() => _errorMessage = 'ISL detection error: $error');
      },
    );
    _statsSub = _pipeline!.statsStream.listen((stats) {
      if (mounted) {
        setState(() {
          _stats = stats;
          _confidence = stats.topConfidence.clamp(0.0, 1.0).toDouble();
        });
      }
      widget.onStats?.call(stats);
    });
    _trackingSub = _pipeline!.trackingStream.listen((isTracking) {
      if (!mounted) return;
      setState(() => _isTracking = isTracking);
      if (!isTracking) {
        _clearSignTimer?.cancel();
        setState(() => _currentSign = '');
      }
    });
    _overlaySub = _pipeline!.overlayStream.listen((overlayFrame) {
      if (mounted) setState(() => _overlayFrame = overlayFrame);
    });
    _featureFrameSub = _pipeline!.featureFrameStream.listen((frame) {
      widget.onFeatureFrame?.call(frame);
    });

    setState(() => _isLoading = false);
  }

  @override
  void dispose() {
    _signSub?.cancel();
    _statsSub?.cancel();
    _trackingSub?.cancel();
    _overlaySub?.cancel();
    _featureFrameSub?.cancel();
    _clearSignTimer?.cancel();
    _pipeline?.dispose();
    _cameraController?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(backgroundColor: Colors.black, body: _buildBody());
  }

  Widget _buildBody() {
    if (_isLoading) {
      return Container(
        color: Colors.black,
        child: const Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              CircularProgressIndicator(),
              SizedBox(height: 16),
              Text(
                'Initialising ISL pipeline…',
                style: TextStyle(color: Colors.white70),
              ),
            ],
          ),
        ),
      );
    }

    if (_errorMessage != null) {
      return Container(
        color: Colors.black,
        child: Center(child: _buildError()),
      );
    }

    return Stack(
      fit: StackFit.expand,
      children: [
        CameraPreview(_cameraController!),
        Positioned.fill(
          child: IgnorePointer(
            child: CustomPaint(
              painter: _PipelineOverlayPainter(
                frame: _overlayFrame,
                mirrorX:
                    _cameraController!.description.lensDirection ==
                    CameraLensDirection.front,
              ),
            ),
          ),
        ),
        _buildConfidenceBar(),
        _buildTrackingHint(),
        _buildSignOverlay(),
      ],
    );
  }

  Widget _buildTrackingHint() {
    return Positioned(
      top: 18,
      left: 16,
      right: 16,
      child: IgnorePointer(
        child: Center(
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: Colors.black54,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: Colors.white24),
            ),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    _isTracking
                        ? 'Tracking hands and upper body'
                        : 'Show hand(s) plus shoulders for ISL detection',
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  if (_stats != null) ...[
                    const SizedBox(height: 4),
                    Text(
                      'Left: ${_stats!.hasLeftHand ? 'YES' : 'NO'}  '
                      'Right: ${_stats!.hasRightHand ? 'YES' : 'NO'}  '
                      'Body: ${_stats!.hasPose ? 'YES' : 'NO'}  '
                      'Window: ${_stats!.windowCount}/30\n'
                      'Top: ${_stats!.topSign ?? '-'} '
                      '${(_stats!.topConfidence * 100).toStringAsFixed(0)}%\n'
                      'Infer: ${_stats!.inferenceStatus}',
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        color: Colors.white70,
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildConfidenceBar() {
    return Positioned(
      top: 0,
      left: 0,
      right: 0,
      child: LinearProgressIndicator(
        value: _confidence,
        minHeight: 4,
        backgroundColor: Colors.white24,
        valueColor: const AlwaysStoppedAnimation<Color>(Color(0xFF4CAF50)),
      ),
    );
  }

  Widget _buildSignOverlay() {
    return Positioned(
      bottom: 32,
      left: 0,
      right: 0,
      child: Center(
        child: AnimatedSwitcher(
          duration: const Duration(milliseconds: 200),
          child: _currentSign.isEmpty
              ? const SizedBox.shrink()
              : Container(
                  key: ValueKey(_currentSign),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 24,
                    vertical: 12,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.black54,
                    borderRadius: BorderRadius.circular(30),
                  ),
                  child: Text(
                    _currentSign,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 28,
                      fontWeight: FontWeight.w600,
                      letterSpacing: 0.5,
                    ),
                  ),
                ),
        ),
      ),
    );
  }

  Widget _buildError() {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        const Icon(Icons.error_outline, color: Colors.red, size: 48),
        const SizedBox(height: 16),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 32),
          child: Text(
            _errorMessage!,
            textAlign: TextAlign.center,
            style: const TextStyle(color: Colors.white70),
          ),
        ),
        const SizedBox(height: 24),
        ElevatedButton(
          onPressed: () {
            setState(() {
              _errorMessage = null;
              _isLoading = true;
            });
            _initialise();
          },
          child: const Text('Retry'),
        ),
      ],
    );
  }
}

class _PipelineOverlayPainter extends CustomPainter {
  static const List<(int, int)> _handConnections = [
    (0, 1),
    (1, 2),
    (2, 3),
    (3, 4),
    (0, 5),
    (5, 6),
    (6, 7),
    (7, 8),
    (5, 9),
    (9, 10),
    (10, 11),
    (11, 12),
    (9, 13),
    (13, 14),
    (14, 15),
    (15, 16),
    (13, 17),
    (17, 18),
    (18, 19),
    (19, 20),
    (0, 17),
  ];

  static const List<(int, int)> _poseConnections = [
    (0, 1),
    (0, 2),
    (1, 3),
    (2, 4),
    (3, 5),
  ];

  final PipelineOverlayFrame frame;
  final bool mirrorX;

  const _PipelineOverlayPainter({required this.frame, required this.mirrorX});

  @override
  void paint(Canvas canvas, Size size) {
    final leftPaint = _linePaint(const Color(0xFF28D8FF));
    final rightPaint = _linePaint(const Color(0xFFFFC857));
    final posePaint = _linePaint(const Color(0xFF71E06F));
    final jointPaint = Paint()..style = PaintingStyle.fill;

    _drawHand(canvas, size, frame.leftHand, leftPaint, jointPaint);
    _drawHand(canvas, size, frame.rightHand, rightPaint, jointPaint);
    _drawPose(canvas, size, frame.pose, posePaint, jointPaint);
  }

  Paint _linePaint(Color color) {
    return Paint()
      ..color = color
      ..strokeWidth = 3
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;
  }

  void _drawHand(
    Canvas canvas,
    Size size,
    List<Offset> points,
    Paint linePaint,
    Paint jointPaint,
  ) {
    if (points.length < 21) return;
    for (final (a, b) in _handConnections) {
      canvas.drawLine(
        _scale(points[a], size),
        _scale(points[b], size),
        linePaint,
      );
    }
    jointPaint.color = linePaint.color;
    for (final point in points) {
      canvas.drawCircle(_scale(point, size), 4, jointPaint);
    }
  }

  void _drawPose(
    Canvas canvas,
    Size size,
    List<Offset> points,
    Paint linePaint,
    Paint jointPaint,
  ) {
    if (points.length < 6) return;
    for (final (a, b) in _poseConnections) {
      canvas.drawLine(
        _scale(points[a], size),
        _scale(points[b], size),
        linePaint,
      );
    }
    jointPaint.color = linePaint.color;
    for (final point in points) {
      canvas.drawCircle(_scale(point, size), 5, jointPaint);
    }
  }

  Offset _scale(Offset point, Size size) {
    final x = mirrorX ? 1 - point.dx : point.dx;
    return Offset(x * size.width, point.dy * size.height);
  }

  @override
  bool shouldRepaint(covariant _PipelineOverlayPainter oldDelegate) {
    return oldDelegate.frame != frame || oldDelegate.mirrorX != mirrorX;
  }
}
