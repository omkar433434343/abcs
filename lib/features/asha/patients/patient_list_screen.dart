import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:go_router/go_router.dart';
import 'package:shimmer/shimmer.dart';
import '../../../core/api/api_client.dart';
import '../../../core/api/endpoints.dart';
import '../../../core/models/models.dart';
import '../../../core/offline/offline_queue.dart';
import '../../../core/auth/auth_provider.dart';
import '../../../core/i18n/app_localizations.dart';
import '../../../core/theme/app_theme.dart';
import 'package:uuid/uuid.dart';
import 'package:dio/dio.dart';

final _patientsProvider = FutureProvider<List<PatientModel>>((ref) async {
  final data = await ApiClient().getCachedList(
    ApiEndpoints.patients,
    cacheKey: 'patients',
  );
  return data.map((e) => PatientModel.fromJson(e)).toList();
});

class PatientListScreen extends ConsumerWidget {
  const PatientListScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final patients = ref.watch(_patientsProvider);
    return Scaffold(
      appBar: AppBar(title: Text(context.tr('Patients'))),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => context.push('/asha/patients/new'),
        icon: const Icon(Icons.person_add_rounded),
        label: Text(context.tr('Register')),
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
      ),
      body: Container(
        decoration: BoxDecoration(gradient: AppTheme.backgroundGradient),
        child: patients.when(
          data: (data) {
            if (data.isEmpty) {
              return Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.people_outline_rounded, size: 64, color: AppColors.textMuted),
                    const SizedBox(height: 16),
                    Text(context.tr('No patients registered yet'),
                        style: const TextStyle(color: AppColors.textSecondary)),
                  ],
                ),
              );
            }
            return ListView.builder(
              padding: const EdgeInsets.only(top: 12, bottom: 100),
              itemCount: data.length,
              itemBuilder: (ctx, i) {
                final p = data[i];
                return GestureDetector(
                  onTap: () => context.push('/asha/patients/detail', extra: p),
                  child: Container(
                    margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 5),
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: AppColors.card,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: AppColors.cardBorder),
                    ),
                    child: Row(
                      children: [
                        CircleAvatar(
                          backgroundColor: AppColors.primary.withOpacity(0.15),
                          child: Text(
                            p.name.isNotEmpty ? p.name[0].toUpperCase() : '?',
                            style: const TextStyle(
                                color: AppColors.primary, fontWeight: FontWeight.w700),
                          ),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(p.name,
                                  style: const TextStyle(
                                      color: AppColors.textPrimary,
                                      fontWeight: FontWeight.w600)),
                              const SizedBox(height: 3),
                              Text(
                                [
                                  if (p.age != null) '${p.age}y',
                                  p.gender,
                                  p.village,
                                  p.district,
                                ].whereType<String>().join(' • '),
                                style: const TextStyle(
                                    color: AppColors.textSecondary, fontSize: 12),
                              ),
                            ],
                          ),
                        ),
                        if (p.pregnant)
                          const Icon(Icons.child_care_rounded,
                              color: AppColors.accent, size: 18),
                      ],
                    ),
                  ),
                ).animate().fade(
                    delay: Duration(milliseconds: i * 40), duration: 350.ms);
              },
            );
          },
          loading: () => Shimmer.fromColors(
            baseColor: AppColors.card,
            highlightColor: AppColors.cardBorder,
            child: ListView.builder(
              itemCount: 5,
              itemBuilder: (_, __) => Container(
                margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                height: 72,
                decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(14)),
              ),
            ),
          ),
          error: (_, __) => Center(
            child: Text(context.tr('Could not load patients'),
                style: const TextStyle(color: AppColors.textSecondary)),
          ),
        ),
      ),
    );
  }
}

// ── Patient Registration Form ─────────────────────────────────────────────────

class PatientFormScreen extends ConsumerStatefulWidget {
  final PatientModel? editPatient;
  const PatientFormScreen({super.key, this.editPatient});

  @override
  ConsumerState<PatientFormScreen> createState() => _PatientFormScreenState();
}

class _PatientFormScreenState extends ConsumerState<PatientFormScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameCtrl = TextEditingController();
  final _ageCtrl = TextEditingController();
  final _villageCtrl = TextEditingController();
  final _tehsilCtrl = TextEditingController();
  final _districtCtrl = TextEditingController();
  final _abhaCtrl = TextEditingController();
  String _gender = 'Female';
  bool _pregnant = false;
  bool _loading = false;

  @override
  void initState() {
    super.initState();
    final user = ref.read(authProvider).user;
    if (user?.district != null) _districtCtrl.text = user!.district!;
    final p = widget.editPatient;
    if (p != null) {
      _nameCtrl.text = p.name;
      _ageCtrl.text = p.age?.toString() ?? '';
      _villageCtrl.text = p.village ?? '';
      _tehsilCtrl.text = p.tehsil ?? '';
      _districtCtrl.text = p.district ?? _districtCtrl.text;
      _abhaCtrl.text = p.abhaId ?? '';
      _gender = p.gender ?? _gender;
      _pregnant = p.pregnant;
    }
  }

  @override
  void dispose() {
    for (final c in [_nameCtrl, _ageCtrl, _villageCtrl, _tehsilCtrl, _districtCtrl, _abhaCtrl]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _loading = true);

    final payload = {
      'name': _nameCtrl.text.trim(),
      'age': int.tryParse(_ageCtrl.text.trim()),
      'gender': _gender,
      'village': _villageCtrl.text.trim(),
      'tehsil': _tehsilCtrl.text.trim(),
      'district': _districtCtrl.text.trim(),
      'pregnant': _pregnant,
      'abha_id': _abhaCtrl.text.trim().isEmpty ? null : _abhaCtrl.text.trim(),
    };

    try {
      if (widget.editPatient == null) {
        await ApiClient().dio.post(ApiEndpoints.patients, data: payload);
      } else {
        await ApiClient().dio.patch(
          ApiEndpoints.patientById(widget.editPatient!.id),
          data: payload,
        );
      }
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              widget.editPatient == null
                  ? context.tr('✅ Patient registered')
                  : context.tr('✅ Patient updated'),
            ),
            backgroundColor: AppColors.success,
          ),
        );
        context.pop();
      }
    } on DioException catch (e) {
      if (e.type == DioExceptionType.connectionError ||
          e.type == DioExceptionType.receiveTimeout) {
        if (widget.editPatient == null) {
          await OfflineQueue.enqueue(QueueItem(
            id: const Uuid().v4(),
            type: 'patient',
            data: payload,
            createdAt: DateTime.now(),
          ));
        } else {
          await OfflineQueue.enqueueRequest(
            method: 'PATCH',
            endpoint: ApiEndpoints.patientById(widget.editPatient!.id),
            data: payload,
          );
        }
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
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: ${e.response?.data?['detail'] ?? e.message}')),
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
         title: Text(
           widget.editPatient == null
               ? context.tr('Register Patient')
               : context.tr('Update Patient'),
         ),
       ),
      body: Container(
        decoration: BoxDecoration(gradient: AppTheme.backgroundGradient),
        child: Form(
          key: _formKey,
          child: ListView(
            padding: const EdgeInsets.all(20),
            children: [
              TextFormField(
                controller: _nameCtrl,
                decoration: InputDecoration(
                  labelText: context.tr('Full Name *'),
                  prefixIcon: Icon(Icons.person_outline_rounded,
                      color: AppColors.textSecondary),
                ),
                validator: (v) =>
                    (v == null || v.trim().isEmpty) ? context.tr('Required') : null,
              ),
              const SizedBox(height: 14),
              Row(
                children: [
                  Expanded(
                    child: TextFormField(
                      controller: _ageCtrl,
                      keyboardType: TextInputType.number,
                        decoration: InputDecoration(labelText: context.tr('Age')),
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: DropdownButtonFormField<String>(
                      value: _gender,
                      dropdownColor: AppColors.card,
                      style: const TextStyle(color: AppColors.textPrimary),
                      decoration: InputDecoration(labelText: context.tr('Gender')),
                      items: ['Male', 'Female', 'Other']
                          .map((g) => DropdownMenuItem(value: g, child: Text(context.tr(g))))
                          .toList(),
                      onChanged: (v) => setState(() => _gender = v!),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              TextFormField(
                controller: _villageCtrl,
                 decoration: InputDecoration(labelText: context.tr('Village')),
              ),
              const SizedBox(height: 14),
              Row(
                children: [
                  Expanded(
                    child: TextFormField(
                      controller: _tehsilCtrl,
                       decoration: InputDecoration(labelText: context.tr('Tehsil')),
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: TextFormField(
                      controller: _districtCtrl,
                       decoration: InputDecoration(labelText: context.tr('District')),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              TextFormField(
                controller: _abhaCtrl,
                 decoration: InputDecoration(labelText: context.tr('ABHA ID (optional)')),
              ),
              const SizedBox(height: 8),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                 title: Text(context.tr('Pregnant'),
                     style: const TextStyle(color: AppColors.textPrimary)),
                value: _pregnant,
                activeColor: AppColors.primary,
                onChanged: (v) => setState(() => _pregnant = v),
              ),
              const SizedBox(height: 24),
              ElevatedButton(
                onPressed: _loading ? null : _submit,
                child: _loading
                    ? const CircularProgressIndicator(color: Colors.white)
                     : Text(
                         widget.editPatient == null
                             ? context.tr('Register Patient')
                             : context.tr('Update Patient'),
                       ),
              ),
              const SizedBox(height: 40),
            ],
          ),
        ),
      ),
    );
  }
}
