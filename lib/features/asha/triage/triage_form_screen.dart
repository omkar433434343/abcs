import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:geolocator/geolocator.dart';
import '../../../core/api/api_client.dart';
import '../../../core/api/endpoints.dart';
import '../../../core/auth/auth_provider.dart';
import '../../../core/models/models.dart';
import '../../../core/offline/offline_queue.dart';
import '../../../core/theme/app_theme.dart';
import 'package:uuid/uuid.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:dio/dio.dart';



class TriageFormScreen extends ConsumerStatefulWidget {
  final bool autoVoice;
  const TriageFormScreen({super.key, this.autoVoice = false});

  @override
  ConsumerState<TriageFormScreen> createState() => _TriageFormScreenState();
}

class _TriageFormScreenState extends ConsumerState<TriageFormScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameCtrl = TextEditingController();
  final _briefCtrl = TextEditingController();
  final _tehsilCtrl = TextEditingController();
  final _districtCtrl = TextEditingController();

  final _symptomsCtrl = TextEditingController();
  String _severity = 'yellow';
  bool _sickleCell = false;
  bool _loading = false;
  bool _gettingLocation = false;
  double? _lat, _lng;
  String? _aiSuggestion;
  String? _aiProviderInfo;
  bool _aiLoading = false;

  @override
  void initState() {
    super.initState();
    final user = ref.read(authProvider).user;
    if (user?.district != null) _districtCtrl.text = user!.district!;
    if (widget.autoVoice) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _startVoiceFill();
      });
    }
  }

  Future<void> _startVoiceFill() async {
    final result = await context.push<VoiceTriageResult>('/asha/triage/voice');
    if (result != null && mounted) {
      setState(() {
        if (result.patientName.isNotEmpty) {
          _nameCtrl.text = result.patientName;
        }
        _severity = result.severity;
        _sickleCell = result.sickleCell;
        if (result.brief.isNotEmpty) {
          _briefCtrl.text = result.brief;
        }
        _symptomsCtrl.text = result.symptoms.join(', ');
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Form auto-filled from voice triage'),
          backgroundColor: AppColors.success,
        ),
      );
    }
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _briefCtrl.dispose();
    _tehsilCtrl.dispose();
    _districtCtrl.dispose();
    _symptomsCtrl.dispose();
    super.dispose();
  }

  Future<void> _getLocation() async {
    setState(() => _gettingLocation = true);
    try {
      final perm = await Geolocator.requestPermission();
      if (perm == LocationPermission.denied) return;
      final pos = await Geolocator.getCurrentPosition(
          desiredAccuracy: LocationAccuracy.medium);
      setState(() {
        _lat = pos.latitude;
        _lng = pos.longitude;
      });
    } finally {
      setState(() => _gettingLocation = false);
    }
  }

  String _getOfflineAdvice(String symptoms) {
    final lower = symptoms.toLowerCase();
    final suggestions = <String>[];
    
    // Core Medical Protocol Fallbacks (WHO/IMNCI-inspired)
    if (lower.contains('fever') || lower.contains('body hot') || lower.contains('tap')) {
      suggestions.add('Monitor temperature regularly using a thermometer.');
      suggestions.add('Keep the patient hydrated with plenty of fluids or ORS.');
    }
    if (lower.contains('cough') || lower.contains('breath') || lower.contains('chest')) {
      suggestions.add('Monitor breathing rate; check for any chest in-drawing.');
      suggestions.add('Keep the patient in a comfortable, upright position.');
    }
    if (lower.contains('diarrhea') || lower.contains('vomit') || lower.contains('loose motion') || lower.contains('stomach')) {
      suggestions.add('Administer ORS immediately after every loose motion.');
      suggestions.add('Continue breastfeeding or regular feeding if applicable.');
    }
    if (lower.contains('pain') || lower.contains('headache') || lower.contains('body ache')) {
      suggestions.add('Ensure adequate rest in a quiet, cool room.');
    }
    
    // Red Flags (Always include for safety)
    suggestions.add('RED FLAGS: Seek immediate care if patient has seizures, persistent vomiting, or extreme lethargy.');
    
    if (suggestions.length <= 1) {
      return 'Offline Advice: Ensure the patient rests, stays hydrated, and is monitored closely. If symptoms persist for more than 24 hours or worsen, visit the nearest PHC immediately.';
    }
    
    return suggestions.map((s) => '- $s').join('\n');
  }

  Future<void> _getAiSuggestion() async {
    final sympList = _symptomsCtrl.text.split(',').map((e) => e.trim()).where((e) => e.isNotEmpty).toList();
    if (sympList.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter at least one symptom')),
      );
      return;
    }

    setState(() => _aiLoading = true);
    
    try {
      // Check for internet connectivity (robust check)
      final connectivityResult = await Connectivity().checkConnectivity();
      if (connectivityResult.isEmpty || connectivityResult.contains(ConnectivityResult.none)) {
        setState(() {
          _aiSuggestion = _getOfflineAdvice(_symptomsCtrl.text);
          _aiProviderInfo = 'Local Protocol (Offline Mode)';
        });
        return;
      }

      // Use a shorter timeout for AI suggestions so offline fallback kicks in faster if connection is poor
      final res = await ApiClient().dio.post(
        ApiEndpoints.aiSuggestion,
        data: {
          'symptoms': sympList,
          'severity': _severity,
          'patient_gender': 'unknown',
          'patient_age': 0,
        },
        options: Options(
          sendTimeout: const Duration(seconds: 5),
          receiveTimeout: const Duration(seconds: 8),
        ),
      );
      
      if (mounted) {
        setState(() {
          _aiSuggestion = res.data['suggestion'];
          _aiProviderInfo = res.data['provider'];
        });
      }
    } on DioException catch (e) {
      debugPrint('AI Suggestion Connection Issue: ${e.type}');
      if (mounted) {
        setState(() {
          _aiSuggestion = _getOfflineAdvice(_symptomsCtrl.text);
          _aiProviderInfo = 'Local Protocol (Offline Fallback)';
        });
      }
    } catch (e) {
      debugPrint('AI Suggestion Error: $e');
      if (mounted) {
        setState(() {
          _aiSuggestion = _getOfflineAdvice(_symptomsCtrl.text);
          _aiProviderInfo = 'Local Protocol (Offline Fallback)';
        });
      }
    } finally {
      if (mounted) {
        setState(() => _aiLoading = false);
      }
    }
  }


  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    final sympList = _symptomsCtrl.text.split(',').map((e) => e.trim()).where((e) => e.isNotEmpty).toList();
    if (sympList.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter at least one symptom')),
      );
      return;
    }

    setState(() => _loading = true);
    final payload = {
      'patient_name': _nameCtrl.text.trim(),
      'symptoms': sympList,
      'severity': _severity,
      'sickle_cell_risk': _sickleCell,
      'brief': _briefCtrl.text.trim(),
      'ai_suggestion': _aiSuggestion,
      'tehsil': _tehsilCtrl.text.trim(),
      'district': _districtCtrl.text.trim(),
      'latitude': _lat,
      'longitude': _lng,
    };

    try {
      await ApiClient().dio.post(ApiEndpoints.triageRecords, data: payload);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('✅ Record saved'), backgroundColor: AppColors.success),
        );
        context.pop();
      }
    } on DioException catch (e) {
      if (e.type == DioExceptionType.connectionError ||
          e.type == DioExceptionType.receiveTimeout) {
        // Save offline
        await OfflineQueue.enqueue(QueueItem(
          id: const Uuid().v4(),
          type: 'triage',
          data: payload,
          createdAt: DateTime.now(),
        ));
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('📶 Saved offline — will sync when connected'),
              backgroundColor: AppColors.warning,
            ),
          );
          context.pop();
        }
      } else {
        final data = e.response?.data;
        final errorMsg = data is Map ? data['detail'] : e.message;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $errorMsg')),
        );
      }
    } finally {
      setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('New Triage'),
        actions: [
          TextButton.icon(
            onPressed: _loading ? null : _submit,
            icon: _loading
                ? const SizedBox(
                    width: 16, height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                : const Icon(Icons.save_rounded, color: Colors.white),
            label: const Text('Save', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
      body: Container(
        decoration: BoxDecoration(gradient: AppTheme.backgroundGradient),
        child: Form(
          key: _formKey,
          child: ListView(
            padding: const EdgeInsets.all(20),
            children: [
              // Header with Voice Triage button
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const _SectionHeader(title: 'Patient Info'),
                  OutlinedButton.icon(
                    onPressed: _startVoiceFill,
                    icon: const Icon(Icons.mic_rounded, size: 18),
                    label: const Text('Voice Fill'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppColors.primary,
                      side: const BorderSide(color: AppColors.primary),
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 0),
                      visualDensity: VisualDensity.compact,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              TextFormField(
                controller: _nameCtrl,
                decoration: const InputDecoration(
                  labelText: 'Patient Name *',
                  prefixIcon: Icon(Icons.person_outline_rounded, color: AppColors.textSecondary),
                ),
                validator: (v) => (v == null || v.trim().isEmpty) ? 'Required' : null,
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: TextFormField(
                      controller: _tehsilCtrl,
                      decoration: const InputDecoration(labelText: 'Tehsil'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: TextFormField(
                      controller: _districtCtrl,
                      decoration: const InputDecoration(labelText: 'District'),
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 8),

              // GPS
              Row(
                children: [
                  _lat != null
                      ? Text(
                          '📍 ${_lat!.toStringAsFixed(4)}, ${_lng!.toStringAsFixed(4)}',
                          style: const TextStyle(color: AppColors.textSecondary, fontSize: 12),
                        )
                      : const Text('No location captured',
                          style: TextStyle(color: AppColors.textMuted, fontSize: 12)),
                  const Spacer(),
                  TextButton.icon(
                    onPressed: _gettingLocation ? null : _getLocation,
                    icon: _gettingLocation
                        ? const SizedBox(
                            width: 14, height: 14,
                            child: CircularProgressIndicator(strokeWidth: 2))
                        : const Icon(Icons.my_location_rounded, size: 16),
                    label: const Text('Get GPS'),
                  ),
                ],
              ),

              const SizedBox(height: 20),

              // Severity
              _SectionHeader(title: 'Severity'),
              const SizedBox(height: 12),
              Row(
                children: ['green', 'yellow', 'red'].map((s) {
                  final selected = _severity == s;
                  final color = AppTheme.severityColor(s);
                  return Expanded(
                    child: GestureDetector(
                      onTap: () => setState(() => _severity = s),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        margin: const EdgeInsets.symmetric(horizontal: 4),
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        decoration: BoxDecoration(
                          color: selected ? color.withOpacity(0.2) : AppColors.card,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: selected ? color : AppColors.cardBorder,
                            width: selected ? 2 : 1,
                          ),
                        ),
                        child: Column(
                          children: [
                            Icon(
                              s == 'green'
                                  ? Icons.check_circle_rounded
                                  : s == 'yellow'
                                      ? Icons.warning_rounded
                                      : Icons.emergency_rounded,
                              color: color,
                            ),
                            const SizedBox(height: 4),
                            Text(
                              s.toUpperCase(),
                              style: TextStyle(
                                color: selected ? color : AppColors.textSecondary,
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  );
                }).toList(),
              ),

              const SizedBox(height: 8),

              // Sickle cell
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Sickle Cell Risk',
                    style: TextStyle(color: AppColors.textPrimary)),
                subtitle: const Text('Odisha high-risk district',
                    style: TextStyle(color: AppColors.textSecondary, fontSize: 12)),
                value: _sickleCell,
                activeColor: AppColors.warning,
                onChanged: (v) => setState(() => _sickleCell = v),
              ),

              const SizedBox(height: 16),

              // Symptoms
              _SectionHeader(title: 'Symptoms'),
              const SizedBox(height: 12),
              TextFormField(
                controller: _symptomsCtrl,
                maxLines: 2,
                decoration: const InputDecoration(
                  labelText: 'Enter symptoms (comma separated)',
                  alignLabelWithHint: true,
                  hintText: 'e.g. Fever, Cough, Headache',
                ),
                validator: (v) => (v == null || v.trim().isEmpty) ? 'Required' : null,
              ),

              const SizedBox(height: 20),

              // Brief
              _SectionHeader(title: 'Clinical Notes'),
              const SizedBox(height: 10),
              TextFormField(
                controller: _briefCtrl,
                maxLines: 4,
                decoration: const InputDecoration(
                  labelText: 'Brief description (optional)',
                  alignLabelWithHint: true,
                ),
              ),

              const SizedBox(height: 16),

              // AI suggestion
              OutlinedButton.icon(
                onPressed: _aiLoading ? null : _getAiSuggestion,
                icon: _aiLoading
                    ? const SizedBox(
                        width: 16, height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2))
                    : const Icon(Icons.auto_awesome_rounded),
                label: const Text('Get AI Suggestions'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppColors.accent,
                  side: const BorderSide(color: AppColors.accent),
                  minimumSize: const Size(double.infinity, 48),
                ),
              ),

              if (_aiSuggestion != null) ...[
                const SizedBox(height: 12),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: AppColors.accent.withOpacity(0.08),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: AppColors.accent.withOpacity(0.3)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _aiSuggestion!.replaceAll('**', ''),
                        style: const TextStyle(
                            color: AppColors.textSecondary, fontSize: 13, height: 1.5),
                      ),
                    ],
                  ),
                ),
              ],

              const SizedBox(height: 32),

              // Submit
              ElevatedButton(
                onPressed: _loading ? null : _submit,
                child: _loading
                    ? const CircularProgressIndicator(color: Colors.white)
                    : const Text('Save Triage Record'),
              ),
              const SizedBox(height: 40),
            ],
          ),
        ),
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  final String title;
  const _SectionHeader({required this.title});

  @override
  Widget build(BuildContext context) {
    return Text(
      title,
      style: Theme.of(context).textTheme.titleSmall?.copyWith(
        color: AppColors.textSecondary,
        fontWeight: FontWeight.w700,
        letterSpacing: 0.8,
      ),
    );
  }
}
