import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/app_theme.dart';
import '../../../isl/trained_signs.dart';
import '../../../widgets/isl_camera_view.dart';

class IslTriageScreen extends StatefulWidget {
  const IslTriageScreen({super.key});

  @override
  State<IslTriageScreen> createState() => _IslTriageScreenState();
}

class _IslTriageScreenState extends State<IslTriageScreen> {
  final List<String> _symptoms = [];
  String _lastRawSign = '';
  String _lastDebugMessage = 'Waiting for emitted trained sign';

  void _handleSign(String sign) {
    final symptom = ISLTrainedSigns.symptomFor(sign);
    if (symptom == null) {
      debugPrint('[ISL Triage] sign=$sign mappedSymptom=null accepted=false');
      setState(() {
        _lastRawSign = sign;
        _lastDebugMessage = 'Sign reached triage but is not trained: $sign';
      });
      return;
    }

    debugPrint('[ISL Triage] sign=$sign mappedSymptom=$symptom accepted=true');
    setState(() {
      _lastRawSign = sign;
      _lastDebugMessage = 'Mapped $sign -> $symptom';
      if (!_symptoms.contains(symptom)) {
        _symptoms.add(symptom);
      }
    });
  }

  void _finish() {
    context.pop(_symptoms);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        fit: StackFit.expand,
        children: [
          ISLCameraView(onSign: _handleSign),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Row(
                children: [
                  IconButton.filledTonal(
                    onPressed: () => context.pop(),
                    icon: const Icon(Icons.arrow_back_rounded),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      _lastRawSign.isEmpty
                          ? 'Show medical ISL signs'
                          : 'Detected $_lastRawSign',
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w700,
                        fontSize: 16,
                      ),
                    ),
                  ),
                  FilledButton.icon(
                    onPressed: _symptoms.isEmpty ? null : _finish,
                    icon: const Icon(Icons.check_rounded),
                    label: const Text('Use'),
                  ),
                ],
              ),
            ),
          ),
          Positioned(
            left: 12,
            right: 12,
            bottom: 20,
            child: SafeArea(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.62),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: Colors.white24),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: _symptoms.isEmpty
                      ? const Text(
                          'Detected symptoms will appear here.',
                          textAlign: TextAlign.center,
                          style: TextStyle(color: Colors.white70),
                        )
                      : Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: [
                            for (final symptom in _symptoms)
                              InputChip(
                                label: Text(symptom),
                                backgroundColor:
                                    AppColors.accent.withValues(alpha: 0.92),
                                labelStyle: const TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w700,
                                ),
                                deleteIconColor: Colors.white,
                                onDeleted: () {
                                  setState(() => _symptoms.remove(symptom));
                                },
                              ),
                          ],
                        ),
                ),
              ),
            ),
          ),
          Positioned(
            left: 12,
            right: 12,
            bottom: 118,
            child: SafeArea(
              child: IgnorePointer(
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.58),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.white24),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 8,
                    ),
                    child: Text(
                      'Debug: $_lastDebugMessage | Symptoms: ${_symptoms.length}',
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        color: Colors.white70,
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
