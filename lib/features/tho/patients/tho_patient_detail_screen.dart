import 'package:flutter/material.dart';
import '../../../core/api/api_client.dart';
import '../../../core/api/endpoints.dart';
import '../../../core/i18n/app_localizations.dart';
import '../../../core/models/models.dart';
import '../../../core/theme/app_theme.dart';
import '../../../shared/utils/date_utils.dart';

class ThoPatientDetailScreen extends StatefulWidget {
  final PatientModel patient;
  const ThoPatientDetailScreen({super.key, required this.patient});

  @override
  State<ThoPatientDetailScreen> createState() => _ThoPatientDetailScreenState();
}

class _ThoPatientDetailScreenState extends State<ThoPatientDetailScreen> {
  late final Future<List<TriageRecordModel>> _triageFuture;

  @override
  void initState() {
    super.initState();
    _triageFuture = _loadPatientTriage();
  }

  Future<List<TriageRecordModel>> _loadPatientTriage() async {
    final data = await ApiClient().getCachedList(ApiEndpoints.triageRecords, cacheKey: 'triage_records');
    final all = data.map((e) => TriageRecordModel.fromJson(e)).toList();
    var records = all.where((r) => r.patientId == widget.patient.id).toList();
    if (records.isEmpty) {
      final name = widget.patient.name.trim().toLowerCase();
      records = all.where((r) => r.patientName.trim().toLowerCase() == name).toList();
    }
    records.sort((a, b) => (DateTime.tryParse(b.createdAt ?? '') ?? DateTime(1970))
        .compareTo(DateTime.tryParse(a.createdAt ?? '') ?? DateTime(1970)));
    return records;
  }

  @override
  Widget build(BuildContext context) {
    final p = widget.patient;
    return Scaffold(
      appBar: AppBar(title: Text(context.tr('Patient Details'))),
      body: Container(
        decoration: BoxDecoration(gradient: AppTheme.backgroundGradient),
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            _line(context.tr('Full Name *'), p.name),
            _line(context.tr('Age'), p.age?.toString() ?? '-'),
            _line(context.tr('Gender'), p.gender ?? '-'),
            _line(context.tr('Village'), p.village ?? '-'),
            _line(context.tr('Tehsil'), p.tehsil ?? '-'),
            _line(context.tr('District'), p.district ?? '-'),
            _line(context.tr('ABHA ID (optional)'), p.abhaId ?? '-'),
            _line(context.tr('Created At'), _formatCreatedAt(p.createdAt)),
            const SizedBox(height: 12),
            Text(context.tr('Clinical History'), style: const TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.w700)),
            const SizedBox(height: 8),
            FutureBuilder<List<TriageRecordModel>>(
              future: _triageFuture,
              builder: (context, snap) {
                if (snap.connectionState == ConnectionState.waiting) {
                  return const Center(child: Padding(padding: EdgeInsets.all(12), child: CircularProgressIndicator()));
                }
                final records = snap.data ?? const <TriageRecordModel>[];
                if (records.isEmpty) {
                  return _line(context.tr('Clinical History'), context.tr('No records yet'));
                }
                return Column(children: records.map((r) => _card(context, r)).toList());
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _line(String label, String value) => Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: AppColors.card,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.cardBorder),
        ),
        child: Row(children: [
          Expanded(flex: 2, child: Text(label, style: const TextStyle(color: AppColors.textMuted, fontSize: 12))),
          Expanded(flex: 3, child: Text(value, style: const TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.w600))),
        ]),
      );

  Widget _card(BuildContext context, TriageRecordModel r) => Container(
        width: double.infinity,
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: AppTheme.severityColor(r.severity).withOpacity(0.12),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppTheme.severityColor(r.severity).withOpacity(0.45)),
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('${context.tr('Severity')}: ${r.severity.toUpperCase()}', style: TextStyle(color: AppTheme.severityColor(r.severity), fontWeight: FontWeight.w800)),
          if (r.symptoms.isNotEmpty) Text('${context.tr('Symptoms')}: ${r.symptoms.join(', ')}', style: const TextStyle(color: AppColors.textSecondary)),
          if (r.brief.isNotEmpty) Text('${context.tr('Brief')}: ${r.brief}', style: const TextStyle(color: AppColors.textSecondary)),
          if ((r.createdAt ?? '').isNotEmpty)
            Text(
              '${context.tr('Created At')}: ${_formatCreatedAt(r.createdAt)}',
              style: const TextStyle(color: AppColors.textMuted, fontSize: 12),
            ),
        ]),
      );

  String _formatCreatedAt(String? iso) {
    if (iso == null || iso.trim().isEmpty) return '-';
    try {
      final dt = DateTime.parse(iso).toLocal();
      final dd = dt.day.toString().padLeft(2, '0');
      final mm = dt.month.toString().padLeft(2, '0');
      final yy = dt.year.toString();
      final hh = dt.hour.toString().padLeft(2, '0');
      final min = dt.minute.toString().padLeft(2, '0');
      return '$dd/$mm/$yy $hh:$min';
    } catch (_) {
      return AppDateUtils.formatDate(iso);
    }
  }
}
