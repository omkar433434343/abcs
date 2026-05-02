import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/api/api_client.dart';
import '../../../core/api/endpoints.dart';
import '../../../core/i18n/app_localizations.dart';
import '../../../core/models/models.dart';
import '../../../core/offline/offline_queue.dart';
import '../../../core/offline/patient_progress_store.dart';
import '../../../core/theme/app_theme.dart';

class PatientProgressFormScreen extends ConsumerStatefulWidget {
  final PatientModel patient;
  const PatientProgressFormScreen({super.key, required this.patient});

  @override
  ConsumerState<PatientProgressFormScreen> createState() => _PatientProgressFormScreenState();
}

class _PatientProgressFormScreenState extends ConsumerState<PatientProgressFormScreen> {
  final _formKey = GlobalKey<FormState>();
  final _symptomsCtrl = TextEditingController();
  final _notesCtrl = TextEditingController();
  String _status = 'improving';
  bool _loading = false;

  Future<String> _postProgress(Map<String, dynamic> payload) async {
    DioException? lastNotFound;
    for (final endpoint in ApiEndpoints.patientProgressCandidates) {
      try {
        await ApiClient().dio.post(endpoint, data: payload);
        return endpoint;
      } on DioException catch (e) {
        if (e.response?.statusCode == 404) {
          lastNotFound = e;
          continue;
        }
        rethrow;
      }
    }
    throw lastNotFound ?? DioException(requestOptions: RequestOptions(path: ApiEndpoints.patientProgress));
  }

  @override
  void dispose() {
    _symptomsCtrl.dispose();
    _notesCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _loading = true);

    final payload = {
      'patient_id': widget.patient.id,
      'status': _status,
      'symptoms': _symptomsCtrl.text
          .split(',')
          .map((e) => e.trim())
          .where((e) => e.isNotEmpty)
          .toList(),
      'notes': _notesCtrl.text.trim().isEmpty ? null : _notesCtrl.text.trim(),
    };

    try {
      final usedEndpoint = await _postProgress(payload);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(context.tr('✅ Progress update saved')), backgroundColor: AppColors.success),
      );
      Navigator.pop(context, {'saved': true, 'endpoint': usedEndpoint});
    } on DioException catch (e) {
      final local = PatientProgressUpdateModel(
        id: DateTime.now().microsecondsSinceEpoch.toString(),
        patientId: widget.patient.id,
        status: _status,
        symptoms: _symptomsCtrl.text
            .split(',')
            .map((x) => x.trim())
            .where((x) => x.isNotEmpty)
            .toList(),
        notes: _notesCtrl.text.trim().isEmpty ? null : _notesCtrl.text.trim(),
        createdAt: DateTime.now().toIso8601String(),
      );

      if (e.type == DioExceptionType.connectionError ||
          e.type == DioExceptionType.receiveTimeout ||
          e.type == DioExceptionType.sendTimeout ||
          e.type == DioExceptionType.connectionTimeout) {
        final queueEndpoint = ApiEndpoints.patientProgressCandidates.first;
        await OfflineQueue.enqueueRequest(
          method: 'POST',
          endpoint: queueEndpoint,
          data: payload,
        );
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(context.tr('📶 Saved offline — will sync when connected')), backgroundColor: AppColors.warning),
        );
        Navigator.pop(context, {'saved': true, 'endpoint': queueEndpoint});
      } else if (e.response?.statusCode == 404 && mounted) {
        await PatientProgressStore.add(local);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(context.tr('Saved locally (backend progress API not available)'))),
        );
        Navigator.pop(context, {'saved': true, 'endpoint': 'local'});
      } else if ((e.response?.statusCode ?? 0) >= 500 && mounted) {
        await PatientProgressStore.add(local);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(context.tr('Server error. Saved locally and can sync later.'))),
        );
        Navigator.pop(context, {'saved': true, 'endpoint': 'local'});
      } else if (mounted) {
        final responseData = e.response?.data;
        String errorText;
        if (responseData is Map && responseData['detail'] != null) {
          errorText = responseData['detail'].toString();
        } else {
          errorText = e.message ?? 'Request failed';
        }
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $errorText')),
        );
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(context.tr('Add Progress Update'))),
      body: Container(
        decoration: BoxDecoration(gradient: AppTheme.backgroundGradient),
        child: Form(
          key: _formKey,
          child: ListView(
            padding: const EdgeInsets.all(20),
            children: [
              Text(widget.patient.name, style: const TextStyle(color: AppColors.textPrimary, fontSize: 18, fontWeight: FontWeight.w700)),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                value: _status,
                decoration: InputDecoration(labelText: context.tr('Recovery Status')),
                items: ['improving', 'stable', 'worsening']
                    .map((s) => DropdownMenuItem(value: s, child: Text(context.tr(s))))
                    .toList(),
                onChanged: (v) => setState(() => _status = v ?? 'stable'),
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _symptomsCtrl,
                maxLines: 2,
                decoration: InputDecoration(
                  labelText: context.tr('Current Symptoms (comma separated)'),
                  hintText: context.tr('e.g. Fever, Cough, Headache'),
                ),
                validator: (v) => (v == null || v.trim().isEmpty) ? context.tr('Required') : null,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _notesCtrl,
                maxLines: 4,
                decoration: InputDecoration(labelText: context.tr('Progress Notes')),
              ),
              const SizedBox(height: 24),
              ElevatedButton(
                onPressed: _loading ? null : _submit,
                child: _loading
                    ? const CircularProgressIndicator(color: Colors.white)
                    : Text(context.tr('Save Progress Update')),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
