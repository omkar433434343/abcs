import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:dio/dio.dart';
import '../../../core/api/api_client.dart';
import '../../../core/api/endpoints.dart';
import '../../../core/models/models.dart';
import '../../../core/offline/offline_queue.dart';
import '../../../core/theme/app_theme.dart';
import '../../../shared/widgets/severity_badge.dart';
import '../../../shared/utils/date_utils.dart';

final _reviewQueueProvider = FutureProvider.autoDispose<List<TriageRecordModel>>((ref) async {
  final data = await ApiClient().getCachedList(
    ApiEndpoints.triageRecords,
    cacheKey: 'triage_records',
  );
  final all = data.map((e) => TriageRecordModel.fromJson(e)).toList();
  all.sort((a, b) {
    const order = {'red': 0, 'yellow': 1, 'green': 2};
    return (order[a.severity] ?? 1).compareTo(order[b.severity] ?? 1);
  });
  return all;
});

class TriageReviewScreen extends ConsumerWidget {
  const TriageReviewScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final records = ref.watch(_reviewQueueProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Triage Review Queue')),
      body: Container(
        decoration: BoxDecoration(gradient: AppTheme.backgroundGradient),
        child: records.when(
          data: (data) {
            if (data.isEmpty) {
              return const Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.check_circle_outline_rounded, size: 64, color: AppColors.success),
                    SizedBox(height: 16),
                    Text('All records reviewed!',
                        style: TextStyle(color: AppColors.textSecondary)),
                  ],
                ),
              );
            }
            return ListView.builder(
              padding: const EdgeInsets.only(top: 12, bottom: 80),
              itemCount: data.length,
              itemBuilder: (ctx, i) => _ReviewCard(
                record: data[i],
                index: i,
                onReviewed: () => ref.refresh(_reviewQueueProvider),
              ),
            );
          },
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (error, stackTrace) => const Center(
            child: Text('Could not load records',
                style: TextStyle(color: AppColors.textSecondary)),
          ),
        ),
      ),
    );
  }
}

class _ReviewCard extends ConsumerStatefulWidget {
  final TriageRecordModel record;
  final int index;
  final VoidCallback onReviewed;
  const _ReviewCard({required this.record, required this.index, required this.onReviewed});

  @override
  ConsumerState<_ReviewCard> createState() => _ReviewCardState();
}

class _ReviewCardState extends ConsumerState<_ReviewCard> {
  bool _marking = false;

  Future<void> _markReviewed() async {
    setState(() => _marking = true);
    try {
      await ApiClient().dio.patch(ApiEndpoints.markReviewed(widget.record.id));
      widget.onReviewed();
    } on DioException catch (e) {
      if (e.type == DioExceptionType.connectionError ||
          e.type == DioExceptionType.receiveTimeout ||
          e.type == DioExceptionType.sendTimeout ||
          e.type == DioExceptionType.connectionTimeout) {
        await OfflineQueue.enqueueRequest(
          method: 'PATCH',
          endpoint: ApiEndpoints.markReviewed(widget.record.id),
          data: const <String, dynamic>{},
        );
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Saved offline - review will sync when online'),
              backgroundColor: AppColors.warning,
            ),
          );
        }
        widget.onReviewed();
      } else if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Failed to mark reviewed')),
        );
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Failed to mark reviewed')),
        );
      }
    } finally {
      if (mounted) setState(() => _marking = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final record = widget.record;
    final color = AppTheme.severityColor(record.severity);

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                SeverityBadge(severity: record.severity),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(record.patientName,
                          style: const TextStyle(
                              color: AppColors.textPrimary,
                              fontWeight: FontWeight.w600)),
                      Text(
                        AppDateUtils.formatRelative(record.createdAt),
                        style: const TextStyle(color: AppColors.textMuted, fontSize: 11),
                      ),
                    ],
                  ),
                ),
                if (record.reviewed)
                  const Icon(Icons.verified_rounded, color: AppColors.success)
                else
                  TextButton(
                    onPressed: _marking ? null : _markReviewed,
                    child: _marking
                        ? const SizedBox(
                            width: 16, height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2))
                        : const Text('Mark Reviewed'),
                  ),
              ],
            ),
          ),
          const Divider(height: 1, color: AppColors.cardBorder),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (record.brief.isNotEmpty)
                  Text(record.brief,
                      style: const TextStyle(
                          color: AppColors.textSecondary, fontSize: 13, height: 1.4)),
                if (record.symptoms.isNotEmpty) ...[
                  const SizedBox(height: 10),
                  Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: record.symptoms
                        .map((s) => Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 10, vertical: 4),
                              decoration: BoxDecoration(
                                color: color.withOpacity(0.1),
                                borderRadius: BorderRadius.circular(20),
                              ),
                              child: Text(s,
                                  style: TextStyle(
                                      color: color, fontSize: 11)),
                            ))
                        .toList(),
                  ),
                ],
                if (record.sickleCell) ...[
                  const SizedBox(height: 10),
                  Row(
                    children: const [
                      Icon(Icons.warning_rounded, color: AppColors.warning, size: 14),
                      SizedBox(width: 6),
                      Text('Sickle Cell Risk',
                          style: TextStyle(color: AppColors.warning, fontSize: 12)),
                    ],
                  ),
                ],
                if (record.district != null) ...[
                  const SizedBox(height: 8),
                  Text('📍 ${record.tehsil ?? ''} ${record.district}',
                      style: const TextStyle(
                          color: AppColors.textMuted, fontSize: 11)),
                ],
              ],
            ),
          ),
        ],
      ),
    ).animate().fade(delay: Duration(milliseconds: widget.index * 50), duration: 400.ms);
  }
}
