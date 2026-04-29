import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:record/record.dart';
import 'package:path_provider/path_provider.dart';
import 'package:dio/dio.dart';
import 'package:go_router/go_router.dart';
import 'dart:io';
import '../../../core/api/api_client.dart';
import '../../../core/api/endpoints.dart';
import '../../../core/models/models.dart';
import '../../../core/theme/app_theme.dart';
import '../../../shared/widgets/severity_badge.dart';

enum _VoiceState { idle, recording, processing, result, error }

class VoiceTriageScreen extends ConsumerStatefulWidget {
  const VoiceTriageScreen({super.key});

  @override
  ConsumerState<VoiceTriageScreen> createState() => _VoiceTriageScreenState();
}

class _VoiceTriageScreenState extends ConsumerState<VoiceTriageScreen>
    with SingleTickerProviderStateMixin {
  _VoiceState _state = _VoiceState.idle;
  VoiceTriageResult? _result;
  String? _errorMsg;
  String? _audioPath;

  late final AudioRecorder _recorder;
  late final AnimationController _pulseCtrl;

  @override
  void initState() {
    super.initState();
    _recorder = AudioRecorder();
    _pulseCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _recorder.dispose();
    _pulseCtrl.dispose();
    super.dispose();
  }

  Future<void> _startRecording() async {
    // record v6: use built-in permission check
    final hasPermission = await _recorder.hasPermission();
    if (!hasPermission) {
      setState(() {
        _state = _VoiceState.error;
        _errorMsg = 'Microphone permission denied. Please enable it in Settings.';
      });
      return;
    }

    final dir = await getTemporaryDirectory();
    _audioPath =
        '${dir.path}/voice_triage_${DateTime.now().millisecondsSinceEpoch}.m4a';

    await _recorder.start(
      const RecordConfig(encoder: AudioEncoder.aacLc, bitRate: 128000, sampleRate: 44100),
      path: _audioPath!,
    );

    setState(() => _state = _VoiceState.recording);
  }

  Future<void> _stopAndProcess() async {
    await _recorder.stop();
    setState(() => _state = _VoiceState.processing);

    try {
      final file = File(_audioPath!);
      if (!await file.exists()) throw Exception('Audio file not found');

      final formData = FormData.fromMap({
        'audio': await MultipartFile.fromFile(
          _audioPath!,
          filename: 'voice_triage.m4a',
          contentType: DioMediaType('audio', 'm4a'),
        ),
      });

      final response = await ApiClient().dio.post(
        ApiEndpoints.voiceTriage,
        data: formData,
        options: Options(contentType: 'multipart/form-data'),
      );

      setState(() {
        _result = VoiceTriageResult.fromJson(response.data);
        _state = _VoiceState.result;
      });

      // Cleanup temp file
      await file.delete();
    } catch (e) {
      setState(() {
        _state = _VoiceState.error;
        _errorMsg = 'Could not process audio. Please check your connection.';
      });
    }
  }

  void _returnResult() {
    if (_result != null) {
      context.pop(_result);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Voice Triage'),
        leading: BackButton(onPressed: () => context.pop()),
      ),
      body: Container(
        decoration: BoxDecoration(gradient: AppTheme.backgroundGradient),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Column(
              children: [
                const SizedBox(height: 40),
                _buildContent(),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildContent() {
    switch (_state) {
      case _VoiceState.idle:
        return _IdleView(onStart: _startRecording);
      case _VoiceState.recording:
        return _RecordingView(pulseCtrl: _pulseCtrl, onStop: _stopAndProcess);
      case _VoiceState.processing:
        return const _ProcessingView();
      case _VoiceState.result:
        return Expanded(
          child: _ResultView(
            result: _result!,
            onConfirm: _returnResult,
            onRetry: () => setState(() => _state = _VoiceState.idle),
          ),
        );
      case _VoiceState.error:
        return _ErrorView(
          message: _errorMsg ?? 'Something went wrong',
          onRetry: () => setState(() => _state = _VoiceState.idle),
        );
    }
  }
}

// ── Sub-views ────────────────────────────────────────────────────────────────

class _IdleView extends StatelessWidget {
  final VoidCallback onStart;
  const _IdleView({required this.onStart});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        const Icon(Icons.mic_none_rounded, size: 80, color: AppColors.textMuted),
        const SizedBox(height: 24),
        Text(
          'Tap to Start Recording',
          style: Theme.of(context).textTheme.headlineSmall?.copyWith(
            fontWeight: FontWeight.w700,
            color: AppColors.textPrimary,
          ),
        ),
        const SizedBox(height: 12),
        Text(
          'Speak symptoms clearly in Hindi, Odia, or Marathi.\nAI will transcribe and run IMNCI triage.',
          textAlign: TextAlign.center,
          style: const TextStyle(color: AppColors.textSecondary, height: 1.5),
        ),
        const SizedBox(height: 40),
        GestureDetector(
          onTap: onStart,
          child: Container(
            width: 100,
            height: 100,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: const LinearGradient(
                colors: [Color(0xFFFF7043), Color(0xFFFF5722)],
              ),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFFFF5722).withOpacity(0.4),
                  blurRadius: 30,
                  spreadRadius: 4,
                ),
              ],
            ),
            child: const Icon(Icons.mic_rounded, color: Colors.white, size: 48),
          ),
        ).animate().scale(duration: 400.ms, curve: Curves.elasticOut),
      ],
    );
  }
}

class _RecordingView extends StatelessWidget {
  final AnimationController pulseCtrl;
  final VoidCallback onStop;
  const _RecordingView({required this.pulseCtrl, required this.onStop});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        AnimatedBuilder(
          animation: pulseCtrl,
          builder: (_, __) => Container(
            width: 120,
            height: 120,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: AppColors.severityRed.withOpacity(0.1 + pulseCtrl.value * 0.15),
              border: Border.all(
                color: AppColors.severityRed.withOpacity(0.4 + pulseCtrl.value * 0.3),
                width: 2,
              ),
            ),
            child: const Icon(Icons.mic_rounded, color: AppColors.severityRed, size: 56),
          ),
        ),
        const SizedBox(height: 28),
        Text(
          'Recording...',
          style: Theme.of(context).textTheme.headlineSmall?.copyWith(
            color: AppColors.severityRed,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 8),
        const Text(
          'Speak clearly. Tap Stop when done.',
          style: TextStyle(color: AppColors.textSecondary),
        ),
        const SizedBox(height: 40),
        ElevatedButton.icon(
          onPressed: onStop,
          icon: const Icon(Icons.stop_rounded),
          label: const Text('Stop & Analyze'),
          style: ElevatedButton.styleFrom(backgroundColor: AppColors.severityRed),
        ),
      ],
    );
  }
}

class _ProcessingView extends StatelessWidget {
  const _ProcessingView();

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        const CircularProgressIndicator(color: AppColors.primary),
        const SizedBox(height: 24),
        Text(
          'Analyzing...',
          style: Theme.of(context).textTheme.titleLarge?.copyWith(
            fontWeight: FontWeight.w700,
            color: AppColors.textPrimary,
          ),
        ),
        const SizedBox(height: 8),
        const Text(
          'Transcribing audio and running\nWHO IMNCI triage classification',
          textAlign: TextAlign.center,
          style: TextStyle(color: AppColors.textSecondary, height: 1.5),
        ),
      ],
    );
  }
}

class _ResultView extends StatelessWidget {
  final VoiceTriageResult result;
  final VoidCallback onConfirm;
  final VoidCallback onRetry;
  const _ResultView({required this.result, required this.onConfirm, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    final color = AppTheme.severityColor(result.severity);
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Severity card
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: color.withOpacity(0.4)),
            ),
            child: Column(
              children: [
                SeverityBadge(severity: result.severity, large: true),
                const SizedBox(height: 10),
                if (result.sickleCell)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: AppColors.warning.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: const Text('⚠️ Sickle Cell Risk',
                        style: TextStyle(color: AppColors.warning, fontSize: 12)),
                  ),
              ],
            ),
          ).animate().scale(duration: 500.ms, curve: Curves.elasticOut),

          const SizedBox(height: 20),

          _Section(
            title: 'Brief',
            child: Text(result.brief,
                style: const TextStyle(color: AppColors.textSecondary, height: 1.5)),
          ),

          const SizedBox(height: 16),

          _Section(
            title: 'Symptoms Detected',
            child: Wrap(
              spacing: 8,
              runSpacing: 8,
              children: result.symptoms
                  .map((s) => Chip(
                        label: Text(s,
                            style: const TextStyle(color: AppColors.textPrimary, fontSize: 12)),
                        backgroundColor: AppColors.card,
                        side: const BorderSide(color: AppColors.cardBorder),
                      ))
                  .toList(),
            ),
          ),

          const SizedBox(height: 16),

          _Section(
            title: 'Transcript',
            child: Text(
              result.transcript.isEmpty ? '(No transcript)' : result.transcript,
              style: const TextStyle(
                  color: AppColors.textSecondary, fontSize: 12, height: 1.5),
            ),
          ),

          const SizedBox(height: 28),

          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: onRetry,
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.textSecondary,
                    side: const BorderSide(color: AppColors.cardBorder),
                    minimumSize: const Size(0, 48),
                  ),
                  child: const Text('Re-record'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                flex: 2,
                child: ElevatedButton.icon(
                  onPressed: onConfirm,
                  icon: const Icon(Icons.check_rounded),
                  label: const Text('Use Details'),
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
        ],
      ),
    );
  }
}

class _Section extends StatelessWidget {
  final String title;
  final Widget child;
  const _Section({required this.title, required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.cardBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title,
              style: const TextStyle(
                  color: AppColors.textSecondary,
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 0.8)),
          const SizedBox(height: 10),
          child,
        ],
      ),
    );
  }
}

class _ErrorView extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;
  const _ErrorView({required this.message, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        const Icon(Icons.error_outline_rounded, size: 64, color: AppColors.error),
        const SizedBox(height: 20),
        Text(message,
            textAlign: TextAlign.center,
            style: const TextStyle(color: AppColors.textSecondary, height: 1.5)),
        const SizedBox(height: 30),
        ElevatedButton(onPressed: onRetry, child: const Text('Try Again')),
      ],
    );
  }
}
