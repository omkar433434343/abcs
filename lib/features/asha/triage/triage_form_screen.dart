import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:geolocator/geolocator.dart';
import '../../../core/api/api_client.dart';
import '../../../core/api/endpoints.dart';
import '../../../core/auth/auth_provider.dart';
import '../../../core/i18n/app_localizations.dart';
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

  final _symptomsCtrl = TextEditingController();
  String _severity = 'yellow';
  bool _sickleCell = false;
  bool _loading = false;
  bool _gettingLocation = false;
  double? _lat, _lng;
  String _defaultTehsil = '';
  String _defaultDistrict = '';
  String? _aiSuggestion;
  String? _aiProviderInfo;
  bool _aiLoading = false;

  static const List<String> _medicalTerms = [
    'fever', 'cough', 'cold', 'headache', 'body ache', 'pain', 'chest pain',
    'breathlessness', 'vomiting', 'diarrhea', 'loose motion', 'nausea',
    'fatigue', 'dizziness', 'seizure', 'rash', 'swelling', 'sore throat',
    'high bp', 'low bp', 'blood sugar', 'dehydration', 'abdominal pain',
    'joint pain', 'bleeding', 'nose bleeding', 'burning urination',
    'urinary pain', 'wheezing', 'weakness', 'loss of appetite',
  ];

  @override
  void initState() {
    super.initState();
    final user = ref.read(authProvider).user;
    _defaultDistrict = user?.district ?? '';
    _defaultTehsil = user?.location ?? '';
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
        SnackBar(
          content: Text(context.tr('Form auto-filled from voice triage')),
          backgroundColor: AppColors.success,
        ),
      );
    }
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _briefCtrl.dispose();
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
    final lang = Localizations.localeOf(context).languageCode;
    
    // Core Medical Protocol Fallbacks (WHO/IMNCI-inspired)
    if (lower.contains('fever') || lower.contains('body hot') || lower.contains('tap') || lower.contains('बुखार') || lower.contains('ज्वर') || lower.contains('ಜ್ವರ')) {
      suggestions.add('Monitor temperature regularly using a thermometer.');
      suggestions.add('Keep the patient hydrated with plenty of fluids or ORS.');
    }
    if (lower.contains('cough') || lower.contains('breath') || lower.contains('chest') || lower.contains('खांसी') || lower.contains('सांस') || lower.contains('ಕೆಮ್ಮು') || lower.contains('ಉಸಿರ')) {
      suggestions.add('Monitor breathing rate; check for any chest in-drawing.');
      suggestions.add('Keep the patient in a comfortable, upright position.');
    }
    if (lower.contains('diarrhea') || lower.contains('vomit') || lower.contains('loose motion') || lower.contains('stomach') || lower.contains('दस्त') || lower.contains('उल्टी') || lower.contains('ಅತಿಸಾರ') || lower.contains('ಓಕರಿ')) {
      suggestions.add('Administer ORS immediately after every loose motion.');
      suggestions.add('Continue breastfeeding or regular feeding if applicable.');
    }
    if (lower.contains('pain') || lower.contains('headache') || lower.contains('body ache')) {
      suggestions.add('Ensure adequate rest in a quiet, cool room.');
    }
    
    // Red Flags (Always include for safety)
    suggestions.add('RED FLAGS: Seek immediate care if patient has seizures, persistent vomiting, or extreme lethargy.');
    
    if (suggestions.length <= 1) {
      if (lang == 'hi') {
        return 'ऑफलाइन सलाह: मरीज को आराम दें, पर्याप्त पानी/ORS दें और निगरानी रखें। 24 घंटे से अधिक लक्षण बने रहें या बढ़ें तो तुरंत नजदीकी PHC जाएं।';
      }
      if (lang == 'kn') {
        return 'ಆಫ್‌ಲೈನ್ ಸಲಹೆ: ರೋಗಿಗೆ ವಿಶ್ರಾಂತಿ ನೀಡಿ, ಸಾಕಷ್ಟು ದ್ರವ/ORS ನೀಡಿ ಮತ್ತು ನಿಗಾವಹಿಸಿ. 24 ಗಂಟೆಗಳಿಗೂ ಹೆಚ್ಚು ಲಕ್ಷಣಗಳು ಮುಂದುವರಿದರೆ ಅಥವಾ ಹೆಚ್ಚಾದರೆ ತಕ್ಷಣ ಸಮೀಪದ PHC ಗೆ ಹೋಗಿ.';
      }
      return 'Offline Advice: Ensure the patient rests, stays hydrated, and is monitored closely. If symptoms persist for more than 24 hours or worsen, visit the nearest PHC immediately.';
    }
    
    return suggestions.map((s) => '- $s').join('\n');
  }

  List<String> _parseSymptoms(String text) => text
      .split(',')
      .map((e) => e.trim().toLowerCase())
      .where((e) => e.isNotEmpty)
      .toList();

  int _distance(String a, String b) {
    final m = a.length;
    final n = b.length;
    final dp = List.generate(m + 1, (_) => List<int>.filled(n + 1, 0));
    for (var i = 0; i <= m; i++) dp[i][0] = i;
    for (var j = 0; j <= n; j++) dp[0][j] = j;
    for (var i = 1; i <= m; i++) {
      for (var j = 1; j <= n; j++) {
        final cost = a[i - 1] == b[j - 1] ? 0 : 1;
        dp[i][j] = [
          dp[i - 1][j] + 1,
          dp[i][j - 1] + 1,
          dp[i - 1][j - 1] + cost,
        ].reduce((x, y) => x < y ? x : y);
      }
    }
    return dp[m][n];
  }

  String? _closestMedicalTerm(String term) {
    if (_medicalTerms.contains(term)) return null;
    String? best;
    var bestScore = 999;
    for (final candidate in _medicalTerms) {
      final d = _distance(term, candidate);
      if (d < bestScore) {
        bestScore = d;
        best = candidate;
      }
    }
    return bestScore <= 3 ? best : null;
  }

  Future<List<String>?> _reviewSymptomsWithAiPrompt(List<String> symptoms) async {
    final suggestions = <int, String>{};
    for (var i = 0; i < symptoms.length; i++) {
      final s = symptoms[i];
      final suggested = _closestMedicalTerm(s);
      if (suggested != null && suggested != s) {
        suggestions[i] = suggested;
      }
    }

    if (suggestions.isEmpty) return symptoms;

    final action = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('AI Symptom Check'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: suggestions.entries
              .map((e) => Text('"${symptoms[e.key]}" -> "${e.value}"'))
              .toList(),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, 'keep'), child: const Text('Keep as is')),
          TextButton(onPressed: () => Navigator.pop(ctx, 'replace'), child: const Text('Use suggestions')),
          TextButton(onPressed: () => Navigator.pop(ctx, 'cancel'), child: const Text('Cancel')),
        ],
      ),
    );

    if (action == 'cancel' || action == null) return null;
    if (action == 'keep') return symptoms;

    final updated = [...symptoms];
    for (final e in suggestions.entries) {
      updated[e.key] = e.value;
    }
    return updated;
  }

  Future<List<String>?> _prepareReviewedSymptoms() async {
    final initial = _parseSymptoms(_symptomsCtrl.text);
    final reviewed = await _reviewSymptomsWithAiPrompt(initial);
    if (reviewed == null) return null;
    _symptomsCtrl.text = reviewed.join(', ');
    if (reviewed.isEmpty) {
      if (!mounted) return null;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(context.tr('Please enter at least one symptom'))),
      );
      return null;
    }
    return reviewed;
  }

  Future<void> _fetchAiSuggestionForSymptoms(List<String> sympList) async {
    setState(() => _aiLoading = true);
    try {
      final langCode = Localizations.localeOf(context).languageCode;
      final responseLanguage = langCode == 'hi'
          ? 'Hindi'
          : langCode == 'kn'
              ? 'Kannada'
              : 'English';
      final connectivityResult = await Connectivity().checkConnectivity();
      if (connectivityResult.isEmpty || connectivityResult.contains(ConnectivityResult.none)) {
        setState(() {
          _aiSuggestion = _getOfflineAdvice(_symptomsCtrl.text);
          _aiProviderInfo = 'Local Protocol (Offline Mode)';
        });
        return;
      }

      final res = await ApiClient().dio.post(
        ApiEndpoints.aiSuggestion,
        data: {
          'symptoms': [
            ...sympList,
            'Respond strictly in $responseLanguage language.',
          ],
          'severity': _severity,
          'patient_gender': 'unknown',
          'patient_age': 0,
          'language_preference': responseLanguage,
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
    } catch (_) {
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

  Future<void> _getAiSuggestion() async {
    final sympList = await _prepareReviewedSymptoms();
    if (sympList == null) return;
    await _fetchAiSuggestionForSymptoms(sympList);
  }


  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    final sympList = await _prepareReviewedSymptoms();
    if (sympList == null) return;

    setState(() => _loading = true);
    await _fetchAiSuggestionForSymptoms(sympList);
    final payload = {
      'patient_name': _nameCtrl.text.trim(),
      'symptoms': sympList,
      'severity': _severity,
      'sickle_cell_risk': _sickleCell,
      'brief': _briefCtrl.text.trim(),
      'ai_suggestion': _aiSuggestion,
      'tehsil': _defaultTehsil,
      'district': _defaultDistrict,
      'latitude': _lat,
      'longitude': _lng,
    };

    try {
      await ApiClient().dio.post(ApiEndpoints.triageRecords, data: payload);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(context.tr('✅ Record saved')), backgroundColor: AppColors.success),
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
            SnackBar(
              content: Text(context.tr('📶 Saved offline — will sync when connected')),
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
        title: Text(context.tr('New Triage')),
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
                  _SectionHeader(title: context.tr('Patient Info')),
                  OutlinedButton.icon(
                    onPressed: _startVoiceFill,
                    icon: const Icon(Icons.mic_rounded, size: 18),
                    label: Text(context.tr('Voice Fill')),
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
                decoration: InputDecoration(
                  labelText: context.tr('Patient Name *'),
                  prefixIcon: const Icon(Icons.person_outline_rounded, color: AppColors.textSecondary),
                ),
                validator: (v) => (v == null || v.trim().isEmpty) ? context.tr('Required') : null,
              ),
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppColors.card,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppColors.cardBorder),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.place_outlined, color: AppColors.textSecondary, size: 18),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        '${context.tr('Tehsil')}: ${_defaultTehsil.isEmpty ? '-' : _defaultTehsil}  •  ${context.tr('District')}: ${_defaultDistrict.isEmpty ? '-' : _defaultDistrict}',
                        style: const TextStyle(color: AppColors.textSecondary, fontSize: 12),
                      ),
                    ),
                  ],
                ),
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
                      : Text(context.tr('No location captured'),
                          style: const TextStyle(color: AppColors.textMuted, fontSize: 12)),
                  const Spacer(),
                  TextButton.icon(
                    onPressed: _gettingLocation ? null : _getLocation,
                    icon: _gettingLocation
                        ? const SizedBox(
                            width: 14, height: 14,
                            child: CircularProgressIndicator(strokeWidth: 2))
                        : const Icon(Icons.my_location_rounded, size: 16),
                    label: Text(context.tr('Get GPS')),
                  ),
                ],
              ),

              const SizedBox(height: 20),

              // Severity
              _SectionHeader(title: context.tr('Severity')),
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
                 title: Text(context.tr('Sickle Cell Risk'),
                     style: const TextStyle(color: AppColors.textPrimary)),
                 subtitle: Text(context.tr('Odisha high-risk district'),
                     style: const TextStyle(color: AppColors.textSecondary, fontSize: 12)),
                value: _sickleCell,
                activeColor: AppColors.warning,
                onChanged: (v) => setState(() => _sickleCell = v),
              ),

              const SizedBox(height: 16),

              // Symptoms
              _SectionHeader(title: context.tr('Symptoms')),
              const SizedBox(height: 12),
              TextFormField(
                controller: _symptomsCtrl,
                maxLines: 2,
                decoration: InputDecoration(
                  labelText: context.tr('Enter symptoms (comma separated)'),
                  alignLabelWithHint: true,
                  hintText: context.tr('e.g. Fever, Cough, Headache'),
                ),
                validator: (v) => (v == null || v.trim().isEmpty) ? context.tr('Required') : null,
              ),

              const SizedBox(height: 20),

              // Brief
              _SectionHeader(title: context.tr('Clinical Notes')),
              const SizedBox(height: 10),
              TextFormField(
                controller: _briefCtrl,
                maxLines: 4,
                decoration: InputDecoration(
                  labelText: context.tr('Brief description (optional)'),
                  alignLabelWithHint: true,
                ),
              ),

              const SizedBox(height: 16),

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
                            color: AppColors.textSecondary, fontSize: 16, height: 1.55, fontWeight: FontWeight.w500),
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
                    : Text(context.tr('Get AI Suggestion and Add to Database')),
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
