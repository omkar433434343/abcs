import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:shimmer/shimmer.dart';
import '../../../core/api/api_client.dart';
import '../../../core/api/endpoints.dart';
import '../../../core/models/models.dart';
import '../../../core/theme/app_theme.dart';
import '../../../shared/widgets/severity_badge.dart';
import '../../../shared/utils/date_utils.dart';

final _myRecordsProvider = FutureProvider<List<TriageRecordModel>>((ref) async {
  final res = await ApiClient().dio.get(ApiEndpoints.triageRecords);
  return (res.data as List).map((e) => TriageRecordModel.fromJson(e)).toList();
});

class MyRecordsScreen extends ConsumerWidget {
  const MyRecordsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final records = ref.watch(_myRecordsProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('My Records')),
      body: Container(
        decoration: BoxDecoration(gradient: AppTheme.backgroundGradient),
        child: records.when(
          data: (data) {
            if (data.isEmpty) {
              return const Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.assignment_outlined, size: 64, color: AppColors.textMuted),
                    SizedBox(height: 16),
                    Text('No records yet', style: TextStyle(color: AppColors.textSecondary)),
                  ],
                ),
              );
            }
            return ListView.builder(
              padding: const EdgeInsets.only(top: 12, bottom: 80),
              itemCount: data.length,
              itemBuilder: (ctx, i) => _RecordCard(record: data[i], index: i),
            );
          },
          loading: () => _ShimmerCards(),
          error: (_, __) => const Center(
            child: Text('Could not load records', style: TextStyle(color: AppColors.textSecondary)),
          ),
        ),
      ),
    );
  }
}

class _RecordCard extends StatelessWidget {
  final TriageRecordModel record;
  final int index;
  const _RecordCard({required this.record, required this.index});

  @override
  Widget build(BuildContext context) {
    return ExpansionTile(
      tilePadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
      childrenPadding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
      collapsedBackgroundColor: Colors.transparent,
      backgroundColor: Colors.transparent,
      leading: SeverityBadge(severity: record.severity),
      title: Text(record.patientName,
          style: const TextStyle(
              color: AppColors.textPrimary, fontWeight: FontWeight.w600)),
      subtitle: Text(
        AppDateUtils.formatRelative(record.createdAt),
        style: const TextStyle(color: AppColors.textSecondary, fontSize: 12),
      ),
      trailing: record.reviewed
          ? const Icon(Icons.verified_rounded, color: AppColors.success, size: 20)
          : const Icon(Icons.pending_rounded, color: AppColors.textMuted, size: 20),
      children: [
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: AppColors.card,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: AppColors.cardBorder),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (record.brief.isNotEmpty) ...[
                _Detail('Brief', record.brief),
                const SizedBox(height: 10),
              ],
              if (record.symptoms.isNotEmpty)
                _Detail('Symptoms', record.symptoms.join(', ')),
              if (record.district != null) ...[
                const SizedBox(height: 10),
                _Detail('Location', '${record.tehsil ?? ''} ${record.district ?? ''}'),
              ],
              if (record.sickleCell) ...[
                const SizedBox(height: 10),
                Row(
                  children: [
                    const Icon(Icons.warning_rounded, color: AppColors.warning, size: 16),
                    const SizedBox(width: 6),
                    const Text('Sickle Cell Risk',
                        style: TextStyle(color: AppColors.warning, fontSize: 12)),
                  ],
                ),
              ],
            ],
          ),
        ),
      ],
    )
        .animate()
        .fade(delay: Duration(milliseconds: index * 40), duration: 350.ms)
        .slideY(begin: 0.1);
  }
}

class _Detail extends StatelessWidget {
  final String label;
  final String value;
  const _Detail(this.label, this.value);

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label,
            style: const TextStyle(
                color: AppColors.textMuted, fontSize: 10, letterSpacing: 0.8)),
        const SizedBox(height: 3),
        Text(value, style: const TextStyle(color: AppColors.textSecondary, fontSize: 13)),
      ],
    );
  }
}

class _ShimmerCards extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Shimmer.fromColors(
      baseColor: AppColors.card,
      highlightColor: AppColors.cardBorder,
      child: ListView.builder(
        itemCount: 5,
        itemBuilder: (_, __) => Container(
          margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 6),
          height: 72,
          decoration: BoxDecoration(
              color: Colors.white, borderRadius: BorderRadius.circular(14)),
        ),
      ),
    );
  }
}
