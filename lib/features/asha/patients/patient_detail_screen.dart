import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../core/api/api_client.dart';
import '../../../core/api/endpoints.dart';
import '../../../core/i18n/app_localizations.dart';
import '../../../core/models/models.dart';
import '../../../core/offline/patient_progress_store.dart';
import '../../../core/theme/app_theme.dart';

class PatientDetailScreen extends StatefulWidget {
  final PatientModel patient;
  const PatientDetailScreen({super.key, required this.patient});

  @override
  State<PatientDetailScreen> createState() => _PatientDetailScreenState();
}

class _PatientDetailScreenState extends State<PatientDetailScreen> {
  late final Future<List<TriageRecordModel>> _triageFuture;
  late final Future<List<PatientProgressUpdateModel>> _progressFuture;
  String _progressEndpoint = ApiEndpoints.patientProgressCandidates.first;
  _SortMode _sortMode = _SortMode.newest;

  @override
  void initState() {
    super.initState();
    _triageFuture = _loadPatientTriage();
    _progressFuture = _loadPatientProgress();
  }

  Future<List<TriageRecordModel>> _loadPatientTriage() async {
    final data = await ApiClient().getCachedList(
      ApiEndpoints.triageRecords,
      cacheKey: 'triage_records',
    );
    final all = data.map((e) => TriageRecordModel.fromJson(e)).toList();
    final p = widget.patient;
    return all.where((r) => r.patientId != null && r.patientId == p.id).toList();
  }

  Future<List<PatientProgressUpdateModel>> _loadPatientProgress() async {
    final local = await PatientProgressStore.getAll();
    final localFiltered = local.where((p) => p.patientId == widget.patient.id).toList();

    for (final endpoint in [_progressEndpoint, ...ApiEndpoints.patientProgressCandidates.where((e) => e != _progressEndpoint)]) {
      try {
        final data = await ApiClient().getCachedList(
          endpoint,
          cacheKey: 'patient_progress_$endpoint',
        );
        _progressEndpoint = endpoint;
        final all = data.map((e) => PatientProgressUpdateModel.fromJson(e)).toList();
        final serverFiltered = all.where((p) => p.patientId == widget.patient.id).toList();
        return [...serverFiltered, ...localFiltered];
      } catch (_) {
        continue;
      }
    }
    return localFiltered;
  }

  List<TriageRecordModel> _sorted(List<TriageRecordModel> records) {
    final copy = [...records];
    DateTime parseDate(String? iso) => DateTime.tryParse(iso ?? '') ?? DateTime.fromMillisecondsSinceEpoch(0);
    switch (_sortMode) {
      case _SortMode.newest:
        copy.sort((a, b) => parseDate(b.createdAt).compareTo(parseDate(a.createdAt)));
        break;
      case _SortMode.oldest:
        copy.sort((a, b) => parseDate(a.createdAt).compareTo(parseDate(b.createdAt)));
        break;
      case _SortMode.severity:
        const rank = {'red': 0, 'yellow': 1, 'green': 2};
        copy.sort((a, b) {
          final r = (rank[a.severity] ?? 9).compareTo(rank[b.severity] ?? 9);
          if (r != 0) return r;
          return parseDate(b.createdAt).compareTo(parseDate(a.createdAt));
        });
        break;
    }
    return copy;
  }

  @override
  Widget build(BuildContext context) {
    final patient = widget.patient;
    return Scaffold(
      appBar: AppBar(title: Text(context.tr('Patient Details'))),
      body: Container(
        decoration: BoxDecoration(gradient: AppTheme.backgroundGradient),
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            _DetailTile(label: context.tr('Full Name *'), value: patient.name),
            _DetailTile(label: context.tr('Age'), value: patient.age?.toString() ?? '-'),
            _DetailTile(label: context.tr('Gender'), value: patient.gender ?? '-'),
            _DetailTile(label: context.tr('Village'), value: patient.village ?? '-'),
            _DetailTile(label: context.tr('Tehsil'), value: patient.tehsil ?? '-'),
            _DetailTile(label: context.tr('District'), value: patient.district ?? '-'),
            _DetailTile(label: context.tr('ABHA ID (optional)'), value: patient.abhaId ?? '-'),
            _DetailTile(
              label: context.tr('Pregnant'),
              value: patient.pregnant ? context.tr('Yes') : context.tr('No'),
            ),
            _DetailTile(label: context.tr('Created At'), value: patient.createdAt ?? '-'),
            const SizedBox(height: 14),
            Text(
              context.tr('Progress Timeline'),
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    color: AppColors.textPrimary,
                    fontWeight: FontWeight.w700,
                  ),
            ),
            const SizedBox(height: 8),
            FutureBuilder<List<PatientProgressUpdateModel>>(
              future: _progressFuture,
              builder: (context, snapshot) {
                final updates = snapshot.data ?? const <PatientProgressUpdateModel>[];
                if (updates.isEmpty) {
                  return _DetailTile(label: context.tr('Progress Timeline'), value: context.tr('No progress updates yet'));
                }
                return Column(
                  children: updates.map((u) => _ProgressDetailCard(update: u)).toList(),
                );
              },
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Text(context.tr('Sort By'), style: const TextStyle(color: AppColors.textSecondary)),
                const SizedBox(width: 10),
                DropdownButton<_SortMode>(
                  value: _sortMode,
                  dropdownColor: AppColors.card,
                  style: const TextStyle(color: AppColors.textPrimary),
                  onChanged: (v) {
                    if (v == null) return;
                    setState(() => _sortMode = v);
                  },
                  items: [
                    DropdownMenuItem(value: _SortMode.newest, child: Text(context.tr('Newest first'))),
                    DropdownMenuItem(value: _SortMode.oldest, child: Text(context.tr('Oldest first'))),
                    DropdownMenuItem(value: _SortMode.severity, child: Text(context.tr('Severity'))),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 8),
            FutureBuilder<List<TriageRecordModel>>(
              future: _triageFuture,
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Padding(
                    padding: EdgeInsets.all(12),
                    child: Center(child: CircularProgressIndicator()),
                  );
                }
                if (snapshot.hasError) {
                  return _DetailTile(label: context.tr('Clinical History'), value: context.tr('Could not load records'));
                }
                final records = _sorted(snapshot.data ?? const <TriageRecordModel>[]);
                if (records.isEmpty) {
                  return _DetailTile(label: context.tr('Clinical History'), value: context.tr('No records yet'));
                }
                return Column(
                  children: records.map((r) => _TriageDetailCard(record: r)).toList(),
                );
              },
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: () async {
                final changed = await context.push('/asha/patients/progress/new', extra: patient);
                if (changed is Map && changed['endpoint'] is String) {
                  _progressEndpoint = changed['endpoint'] as String;
                }
                if (changed != null && mounted) {
                  setState(() {
                    _progressFuture = _loadPatientProgress();
                  });
                }
              },
              icon: const Icon(Icons.add_chart_rounded),
              label: Text(context.tr('Add Progress Update')),
            ),
            const SizedBox(height: 12),
            ElevatedButton.icon(
              onPressed: () => context.push('/asha/patients/chat', extra: patient),
              icon: const Icon(Icons.chat_rounded),
              label: Text(context.tr('Chat with AI for this patient')),
            ),
          ],
        ),
      ),
    );
  }
}

enum _SortMode { newest, oldest, severity }

class _ProgressDetailCard extends StatelessWidget {
  final PatientProgressUpdateModel update;
  const _ProgressDetailCard({required this.update});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.cardBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '${context.tr('Recovery Status')}: ${context.tr(update.status)}',
            style: const TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.w700),
          ),
          if (update.symptoms.isNotEmpty) ...[
            const SizedBox(height: 6),
            Text('${context.tr('Symptoms')}: ${update.symptoms.join(', ')}', style: const TextStyle(color: AppColors.textSecondary)),
          ],
          if ((update.notes ?? '').isNotEmpty) ...[
            const SizedBox(height: 6),
            Text('${context.tr('Progress Notes')}: ${update.notes}', style: const TextStyle(color: AppColors.textSecondary)),
          ],
          if ((update.createdAt ?? '').isNotEmpty)
            Text(
              '${context.tr('Created At')}: ${update.createdAt}',
              style: const TextStyle(color: AppColors.textMuted, fontSize: 12),
            ),
        ],
      ),
    );
  }
}

class _TriageDetailCard extends StatelessWidget {
  final TriageRecordModel record;
  const _TriageDetailCard({required this.record});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.cardBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '${context.tr('Severity')}: ${record.severity.toUpperCase()}',
            style: const TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 6),
          if (record.symptoms.isNotEmpty)
            Text(
              '${context.tr('Symptoms')}: ${record.symptoms.join(', ')}',
              style: const TextStyle(color: AppColors.textSecondary, height: 1.3),
            ),
          if (record.brief.isNotEmpty) ...[
            const SizedBox(height: 6),
            Text(
              '${context.tr('Brief')}: ${record.brief}',
              style: const TextStyle(color: AppColors.textSecondary, height: 1.3),
            ),
          ],
          const SizedBox(height: 6),
          Text(
            '${context.tr('Sickle Cell Risk')}: ${record.sickleCell ? context.tr('Yes') : context.tr('No')}',
            style: const TextStyle(color: AppColors.textSecondary),
          ),
          if ((record.tehsil ?? '').isNotEmpty || (record.district ?? '').isNotEmpty)
            Text(
              '${context.tr('Location')}: ${record.tehsil ?? ''} ${record.district ?? ''}'.trim(),
              style: const TextStyle(color: AppColors.textSecondary),
            ),
          if ((record.createdAt ?? '').isNotEmpty)
            Text(
              '${context.tr('Created At')}: ${record.createdAt}',
              style: const TextStyle(color: AppColors.textMuted, fontSize: 12),
            ),
        ],
      ),
    );
  }
}

class _DetailTile extends StatelessWidget {
  final String label;
  final String value;
  const _DetailTile({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.cardBorder),
      ),
      child: Row(
        children: [
          Expanded(
            flex: 2,
            child: Text(label, style: const TextStyle(color: AppColors.textMuted, fontSize: 12)),
          ),
          Expanded(
            flex: 3,
            child: Text(value, style: const TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.w600)),
          ),
        ],
      ),
    );
  }
}
