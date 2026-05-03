import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:shimmer/shimmer.dart';
import '../../../core/api/api_client.dart';
import '../../../core/api/endpoints.dart';
import '../../../core/i18n/app_localizations.dart';
import '../../../core/models/models.dart';
import '../../../core/theme/app_theme.dart';

final _thoPatientsProvider = FutureProvider<List<PatientModel>>((ref) async {
  final data = await ApiClient().getCachedList(
    ApiEndpoints.patients,
    cacheKey: 'patients',
  );
  return data.map((e) => PatientModel.fromJson(e)).toList();
});

final _thoTriageProvider = FutureProvider<List<TriageRecordModel>>((ref) async {
  final data = await ApiClient().getCachedList(
    ApiEndpoints.triageRecords,
    cacheKey: 'triage_records',
  );
  return data.map((e) => TriageRecordModel.fromJson(e)).toList();
});

class ThoPatientListScreen extends ConsumerStatefulWidget {
  const ThoPatientListScreen({super.key});

  @override
  ConsumerState<ThoPatientListScreen> createState() => _ThoPatientListScreenState();
}

enum _PatientSortMode { newest, severity }

class _ThoPatientListScreenState extends ConsumerState<ThoPatientListScreen> {
  _PatientSortMode _sortMode = _PatientSortMode.newest;

  @override
  Widget build(BuildContext context) {
    final patients = ref.watch(_thoPatientsProvider);
    final triages = ref.watch(_thoTriageProvider);
    return Scaffold(
      appBar: AppBar(title: Text(context.tr('Patients'))),
      body: Container(
        decoration: BoxDecoration(gradient: AppTheme.backgroundGradient),
        child: patients.when(
          data: (data) {
            if (data.isEmpty) {
              return Center(
                child: Text(
                  context.tr('No patients registered yet'),
                  style: const TextStyle(color: AppColors.textSecondary),
                ),
              );
            }
            final triageData = triages.value ?? const <TriageRecordModel>[];
            final latestByPatient = <String, TriageRecordModel>{};
            for (final t in triageData) {
              final pid = t.patientId;
              if (pid == null || pid.isEmpty) continue;
              final old = latestByPatient[pid];
              if (old == null) {
                latestByPatient[pid] = t;
                continue;
              }
              final tTime = DateTime.tryParse(t.createdAt ?? '') ?? DateTime.fromMillisecondsSinceEpoch(0);
              final oTime = DateTime.tryParse(old.createdAt ?? '') ?? DateTime.fromMillisecondsSinceEpoch(0);
              if (tTime.isAfter(oTime)) latestByPatient[pid] = t;
            }

            final items = [...data];
            if (_sortMode == _PatientSortMode.newest) {
              items.sort((a, b) {
                final at = DateTime.tryParse((latestByPatient[a.id]?.createdAt) ?? (a.createdAt ?? '')) ?? DateTime.fromMillisecondsSinceEpoch(0);
                final bt = DateTime.tryParse((latestByPatient[b.id]?.createdAt) ?? (b.createdAt ?? '')) ?? DateTime.fromMillisecondsSinceEpoch(0);
                return bt.compareTo(at);
              });
            } else {
              const rank = {'red': 0, 'yellow': 1, 'green': 2};
              items.sort((a, b) {
                final ar = rank[(latestByPatient[a.id]?.severity ?? 'green')] ?? 9;
                final br = rank[(latestByPatient[b.id]?.severity ?? 'green')] ?? 9;
                return ar.compareTo(br);
              });
            }

            return Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 10, 16, 0),
                  child: Row(
                    children: [
                      Text(context.tr('Sort By'), style: const TextStyle(color: AppColors.textSecondary)),
                      const SizedBox(width: 10),
                      DropdownButton<_PatientSortMode>(
                        value: _sortMode,
                        onChanged: (v) {
                          if (v == null) return;
                          setState(() => _sortMode = v);
                        },
                        items: [
                          DropdownMenuItem(value: _PatientSortMode.newest, child: Text(context.tr('Newest first'))),
                          DropdownMenuItem(value: _PatientSortMode.severity, child: Text(context.tr('Severity'))),
                        ],
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: ListView.builder(
              padding: const EdgeInsets.only(top: 12, bottom: 80),
              itemCount: items.length,
              itemBuilder: (_, i) {
                final p = items[i];
                return _PatientQueueCard(patient: p, latestTriage: latestByPatient[p.id]);
              },
            ),
                ),
              ],
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
                decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(14)),
              ),
            ),
          ),
          error: (_, __) => Center(
            child: Text(context.tr('Could not load patients'), style: const TextStyle(color: AppColors.textSecondary)),
          ),
        ),
      ),
    );
  }
}

class _PatientQueueCard extends StatelessWidget {
  final PatientModel patient;
  final TriageRecordModel? latestTriage;
  const _PatientQueueCard({required this.patient, this.latestTriage});

  @override
  Widget build(BuildContext context) {
    final hasTriage = latestTriage != null;
    final sev = latestTriage?.severity ?? 'green';
    final sevColor = AppTheme.severityColor(sev);
    return GestureDetector(
      onTap: () => context.push('/tho/patients/detail', extra: patient),
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
        decoration: BoxDecoration(
          color: hasTriage ? sevColor.withOpacity(0.1) : AppColors.card,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: hasTriage ? sevColor.withOpacity(0.45) : AppColors.cardBorder),
        ),
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  CircleAvatar(
                    backgroundColor: hasTriage ? sevColor.withOpacity(0.16) : AppColors.primary.withOpacity(0.12),
                    child: Text(
                      patient.name.isNotEmpty ? patient.name[0].toUpperCase() : '?',
                      style: TextStyle(color: hasTriage ? sevColor : AppColors.primary, fontWeight: FontWeight.w700),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          patient.name,
                          style: const TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.w600),
                        ),
                        Text(
                          ['ID: ${patient.id}', if (patient.age != null) '${patient.age}y', patient.gender]
                              .whereType<String>()
                              .where((e) => e.trim().isNotEmpty)
                              .join(' • '),
                          style: const TextStyle(color: AppColors.textMuted, fontSize: 11),
                        ),
                      ],
                    ),
                  ),
                  const Icon(Icons.chevron_right_rounded, color: AppColors.textMuted),
                ],
              ),
            ),
            const Divider(height: 1, color: AppColors.cardBorder),
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    [patient.village, patient.tehsil, patient.district]
                        .whereType<String>()
                        .where((e) => e.trim().isNotEmpty)
                        .join(' • '),
                    style: const TextStyle(color: AppColors.textSecondary, fontSize: 13, height: 1.4),
                  ),
                  if ((patient.abhaId ?? '').isNotEmpty) ...[
                    const SizedBox(height: 8),
                    Text(
                      'ABHA: ${patient.abhaId}',
                      style: const TextStyle(color: AppColors.textMuted, fontSize: 12),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
