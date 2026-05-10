import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:path_provider/path_provider.dart';

import '../../../core/theme/app_theme.dart';
import '../../../isl/feature_schema.dart';
import '../../../isl/trained_signs.dart';
import '../../../widgets/isl_camera_view.dart';

class IslDataCollectionScreen extends StatefulWidget {
  const IslDataCollectionScreen({super.key});

  @override
  State<IslDataCollectionScreen> createState() =>
      _IslDataCollectionScreenState();
}

class _IslDataCollectionScreenState extends State<IslDataCollectionScreen> {
  static const int _recordSeconds = 3;
  static const int _maxRecordSeconds = 8;
  static const int _targetSamplesPerSign = 300;
  static const int _requiredValidFrames = ISLFeatureSchema.windowSize;
  static const int _minimumUsableFrames = 18;

  String _selectedLabel = ISLTrainedSigns.collectionSigns.first.label;
  final List<ISLFeatureFrame> _frames = [];
  final Map<String, int> _savedCountsByLabel = {};
  bool _isRecording = false;
  bool _isFinishingRecording = false;
  bool _isSavingRecording = false;
  int _secondsLeft = _recordSeconds;
  int _lastValidFrameCount = 0;
  String? _lastSavedPath;
  String? _status;
  Timer? _timer;
  DateTime? _recordDeadline;
  DateTime _lastFrameUiUpdate = DateTime.fromMillisecondsSinceEpoch(0);
  Directory? _publicDatasetDir;

  String get _selectedSymptom => ISLTrainedSigns.displayTextFor(_selectedLabel);

  int get _selectedSavedCount => _savedCountsByLabel[_selectedLabel] ?? 0;

  int get _totalSavedCount =>
      _savedCountsByLabel.values.fold(0, (sum, count) => sum + count);

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _refreshSavedCounts();
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  void _handleFeatureFrame(ISLFeatureFrame frame) {
    if (frame.hasHand && frame.hasPose) {
      _lastValidFrameCount = frame.windowCount;
    }
    if (!_isRecording) return;
    _frames.add(frame);

    if (_frames.length >= _requiredValidFrames && !_isFinishingRecording) {
      _isFinishingRecording = true;
      _timer?.cancel();
      unawaited(_finishRecording());
      return;
    }

    final now = DateTime.now();
    if (now.difference(_lastFrameUiUpdate) >
        const Duration(milliseconds: 250)) {
      _lastFrameUiUpdate = now;
      if (mounted) setState(() {});
    }
  }

  void _startRecording() {
    _timer?.cancel();
    final deadline = DateTime.now().add(
      const Duration(seconds: _maxRecordSeconds),
    );
    setState(() {
      _frames.clear();
      _isRecording = true;
      _isFinishingRecording = false;
      _secondsLeft = _maxRecordSeconds;
      _lastSavedPath = null;
      _recordDeadline = deadline;
      _status =
          'Recording $_selectedLabel -> $_selectedSymptom '
          '(need $_requiredValidFrames valid frames)...';
      _lastFrameUiUpdate = DateTime.now();
    });

    _timer = Timer.periodic(const Duration(milliseconds: 200), (timer) async {
      if (!mounted) return;
      if (!_isRecording || _recordDeadline == null) {
        timer.cancel();
        return;
      }

      final remaining = _recordDeadline!
          .difference(DateTime.now())
          .inMilliseconds;
      final nextSecondsLeft = remaining <= 0 ? 0 : ((remaining + 999) ~/ 1000);

      if (_frames.length >= _requiredValidFrames && !_isFinishingRecording) {
        _isFinishingRecording = true;
        timer.cancel();
        await _finishRecording();
        return;
      }

      if (nextSecondsLeft <= 0 && !_isFinishingRecording) {
        _isFinishingRecording = true;
        timer.cancel();
        await _finishRecording();
        return;
      }

      if (_secondsLeft != nextSecondsLeft) {
        setState(() => _secondsLeft = nextSecondsLeft);
      }
    });
  }

  Future<void> _finishRecording() async {
    if (_isSavingRecording) return;
    _isSavingRecording = true;

    final frames = List<ISLFeatureFrame>.from(_frames);
    if (mounted) {
      setState(() {
        _isRecording = false;
        _secondsLeft = 0;
        _recordDeadline = null;
        _status = 'Saving ${frames.length} valid frames...';
      });
    }

    try {
      if (frames.length < _minimumUsableFrames) {
        if (mounted) {
          setState(() {
            _status =
                'Too few valid frames (${frames.length}/$_minimumUsableFrames). '
                'Keep the signing hand(s) and both shoulders visible for longer.';
          });
        }
        return;
      }

      final sampleFrames = _padFramesToWindow(frames);
      final sampledFrameCount = sampleFrames.length;
      final capturedFrameCount = frames.length;
      final paddedFrameCount = math.max(
        0,
        sampledFrameCount - capturedFrameCount,
      );

      final dir = await _datasetDirectory();
      final publicDir = await _publicDatasetDirectory();
      final safeLabel = _selectedLabel.replaceAll(RegExp(r'[^A-Z0-9_-]'), '_');
      final stamp = DateTime.now()
          .toIso8601String()
          .replaceAll(':', '-')
          .replaceAll('.', '-');
      final file = File('${dir.path}/$safeLabel-$stamp.json');
      final publicFile = publicDir == null
          ? null
          : File('${publicDir.path}/$safeLabel-$stamp.json');
      final nextSampleNumber = _selectedSavedCount + 1;
      final payload = {
        ...ISLFeatureSchema.metadata(),
        'label': _selectedLabel,
        'symptom': _selectedSymptom,
        'sample_number': nextSampleNumber,
        'collection_mode': 'normal_collection',
        'capture_seconds': _recordSeconds,
        'frame_count': sampleFrames.length,
        'valid_frame_count': capturedFrameCount,
        'padded_frame_count': paddedFrameCount,
        'captured_at': DateTime.now().toIso8601String(),
        'platform': Platform.operatingSystem,
        'frames': sampleFrames.map((f) => f.toJson()).toList(growable: false),
      };
      await file.writeAsString(
        const JsonEncoder.withIndent('  ').convert(payload),
      );
      if (publicFile != null) {
        await publicFile.writeAsString(
          const JsonEncoder.withIndent('  ').convert(payload),
        );
      }

      if (!mounted) return;
      setState(() {
        _savedCountsByLabel[_selectedLabel] = nextSampleNumber;
        _lastSavedPath = publicFile?.path ?? file.path;
        _status =
            'Saved sample $nextSampleNumber/$_targetSamplesPerSign for '
            '$_selectedLabel -> $_selectedSymptom'
            '${_sampleStatusSuffix(capturedFrameCount, sampledFrameCount)}';
      });
      await _refreshSavedCounts();
    } finally {
      _isSavingRecording = false;
      _isFinishingRecording = false;
    }
  }

  List<ISLFeatureFrame> _padFramesToWindow(List<ISLFeatureFrame> frames) {
    if (frames.length >= _requiredValidFrames) {
      return frames.take(_requiredValidFrames).toList(growable: false);
    }

    final missing = _requiredValidFrames - frames.length;
    final firstFrame = frames.first;
    return [
      for (var i = 0; i < missing; i++)
        ISLFeatureFrame(
          timestamp: firstFrame.timestamp,
          features: firstFrame.features,
          hasHand: firstFrame.hasHand,
          hasLeftHand: firstFrame.hasLeftHand,
          hasRightHand: firstFrame.hasRightHand,
          hasPose: firstFrame.hasPose,
          windowCount: firstFrame.windowCount,
        ),
      ...frames,
    ];
  }

  String _sampleStatusSuffix(int capturedFrameCount, int sampledFrameCount) {
    if (capturedFrameCount < sampledFrameCount) {
      return ' ($capturedFrameCount captured + '
          '${sampledFrameCount - capturedFrameCount} padded)';
    }
    if (capturedFrameCount > sampledFrameCount) {
      return ' ($capturedFrameCount captured, trimmed to $sampledFrameCount)';
    }
    return '';
  }

  Future<Directory> _datasetDirectory() async {
    final root = await getApplicationDocumentsDirectory();
    final dir = Directory('${root.path}/isl_dataset');
    if (!await dir.exists()) await dir.create(recursive: true);
    return dir;
  }

  Future<Directory?> _publicDatasetDirectory() async {
    if (!Platform.isAndroid) return null;
    if (_publicDatasetDir != null) return _publicDatasetDir;

    final root = await getExternalStorageDirectory();
    if (root == null) return null;

    final dir = Directory('${root.path}/isl_dataset');
    if (!await dir.exists()) await dir.create(recursive: true);
    _publicDatasetDir = dir;
    return dir;
  }

  Future<void> _refreshSavedCounts() async {
    final counts = {
      for (final sign in ISLTrainedSigns.collectionSigns) sign.label: 0,
    };

    try {
      final files = await _datasetFiles();

      for (final file in files) {
        final label = await _readSampleLabel(file);
        if (label != null && counts.containsKey(label)) {
          counts[label] = counts[label]! + 1;
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() => _status = 'Could not refresh saved counts: $e');
      }
      return;
    }

    if (!mounted) return;
    setState(() {
      _savedCountsByLabel
        ..clear()
        ..addAll(counts);
    });
  }

  Future<List<File>> _datasetFiles() async {
    final filesByName = <String, File>{};

    Future<void> addFilesFrom(Directory? dir) async {
      if (dir == null || !await dir.exists()) return;

      final files = await dir
          .list()
          .where((entity) => entity is File && entity.path.endsWith('.json'))
          .cast<File>()
          .toList();

      for (final file in files) {
        filesByName[file.uri.pathSegments.last] = file;
      }
    }

    await addFilesFrom(await _datasetDirectory());
    await addFilesFrom(await _publicDatasetDirectory());
    return filesByName.values.toList(growable: false);
  }

  Future<String?> _readSampleLabel(File file) async {
    try {
      final decoded = jsonDecode(await file.readAsString());
      if (decoded is Map<String, dynamic>) {
        final label = decoded['label'];
        if (label is String && label.isNotEmpty) return label;
      }
    } catch (_) {
      return _labelFromFileName(file);
    }
    return _labelFromFileName(file);
  }

  String? _labelFromFileName(File file) {
    final name = file.uri.pathSegments.last;
    for (final sign in ISLTrainedSigns.collectionSigns) {
      if (name.startsWith('${sign.label}-')) return sign.label;
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        fit: StackFit.expand,
        children: [
          ISLCameraView(onSign: (_) {}, onFeatureFrame: _handleFeatureFrame),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                children: [
                  Row(
                    children: [
                      IconButton.filledTonal(
                        onPressed: () => context.pop(),
                        icon: const Icon(Icons.arrow_back_rounded),
                      ),
                      const SizedBox(width: 8),
                      const Expanded(
                        child: Text(
                          'ISL Dataset Collector',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 17,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const Spacer(),
                  _buildPanel(),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPanel() {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.72),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.white24),
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            DecoratedBox(
              decoration: BoxDecoration(
                color: AppColors.accent.withValues(alpha: 0.18),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: AppColors.accent),
              ),
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Currently collecting',
                      style: TextStyle(
                        color: Colors.white70,
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '$_selectedLabel -> $_selectedSymptom',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 22,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 8),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(999),
                      child: LinearProgressIndicator(
                        value: (_selectedSavedCount / _targetSamplesPerSign)
                            .clamp(0.0, 1.0)
                            .toDouble(),
                        minHeight: 8,
                        backgroundColor: Colors.white24,
                        valueColor: const AlwaysStoppedAnimation<Color>(
                          AppColors.accent,
                        ),
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'Saved $_selectedSavedCount/$_targetSamplesPerSign '
                      'samples for this sign | Total: $_totalSavedCount',
                      style: const TextStyle(
                        color: Colors.white70,
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              initialValue: _selectedLabel,
              dropdownColor: const Color(0xFF1C1F24),
              decoration: const InputDecoration(
                labelText: 'Sign label',
                labelStyle: TextStyle(color: Colors.white70),
                enabledBorder: OutlineInputBorder(
                  borderSide: BorderSide(color: Colors.white24),
                ),
                focusedBorder: OutlineInputBorder(
                  borderSide: BorderSide(color: AppColors.accent),
                ),
              ),
              style: const TextStyle(color: Colors.white),
              items: [
                for (final sign in ISLTrainedSigns.collectionSigns)
                  DropdownMenuItem(
                    value: sign.label,
                    child: Text('${sign.label} -> ${sign.symptom}'),
                  ),
              ],
              onChanged: _isRecording
                  ? null
                  : (value) {
                      if (value != null) {
                        setState(() {
                          _selectedLabel = value;
                          _lastSavedPath = null;
                          _status = null;
                        });
                      }
                    },
            ),
            const SizedBox(height: 10),
            Text(
              _isRecording
                  ? 'Recording... valid frames: ${_frames.length}/$_requiredValidFrames '
                        '| time left: ${_secondsLeft}s'
                  : 'Live valid window: $_lastValidFrameCount/${ISLFeatureSchema.windowSize}',
              style: const TextStyle(color: Colors.white70),
            ),
            if (_status != null) ...[
              const SizedBox(height: 8),
              Text(
                _status!,
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
            if (_lastSavedPath != null) ...[
              const SizedBox(height: 8),
              SelectableText(
                _lastSavedPath!,
                style: const TextStyle(color: Colors.white60, fontSize: 11),
              ),
            ],
            const SizedBox(height: 12),
            FilledButton.icon(
              onPressed: _isRecording ? null : _startRecording,
              icon: const Icon(Icons.fiber_manual_record_rounded),
              label: Text(_isRecording ? 'Recording' : 'Record 3s Sample'),
            ),
          ],
        ),
      ),
    );
  }
}
