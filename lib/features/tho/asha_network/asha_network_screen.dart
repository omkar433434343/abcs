import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:shimmer/shimmer.dart';
import '../../../core/api/api_client.dart';
import '../../../core/api/endpoints.dart';
import '../../../core/models/models.dart';
import '../../../core/theme/app_theme.dart';

final _ashaWorkersProvider = FutureProvider<List<UserModel>>((ref) async {
  final res = await ApiClient().dio.get(ApiEndpoints.ashaWorkers);
  return (res.data as List).map((e) => UserModel.fromJson(e)).toList();
});

class AshaNetworkScreen extends ConsumerWidget {
  const AshaNetworkScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final workers = ref.watch(_ashaWorkersProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('ASHA Network')),
      body: Container(
        decoration: BoxDecoration(gradient: AppTheme.backgroundGradient),
        child: workers.when(
          data: (data) {
            if (data.isEmpty) {
              return const Center(
                child: Text('No ASHA workers found',
                    style: TextStyle(color: AppColors.textSecondary)),
              );
            }
            return ListView.builder(
              padding: const EdgeInsets.only(top: 12, bottom: 80),
              itemCount: data.length,
              itemBuilder: (ctx, i) => _WorkerCard(worker: data[i], index: i),
            );
          },
          loading: () => Shimmer.fromColors(
            baseColor: AppColors.card,
            highlightColor: AppColors.cardBorder,
            child: ListView.builder(
              itemCount: 6,
              itemBuilder: (_, __) => Container(
                margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                height: 80,
                decoration: BoxDecoration(
                    color: Colors.white, borderRadius: BorderRadius.circular(14)),
              ),
            ),
          ),
          error: (_, __) => const Center(
            child: Text('Could not load workers',
                style: TextStyle(color: AppColors.textSecondary)),
          ),
        ),
      ),
    );
  }
}

class _WorkerCard extends StatelessWidget {
  final UserModel worker;
  final int index;
  const _WorkerCard({required this.worker, required this.index});

  @override
  Widget build(BuildContext context) {
    return Container(
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
            radius: 24,
            backgroundColor: AppColors.ashaStart.withOpacity(0.2),
            child: Text(
              (worker.fullName ?? worker.employeeId).isNotEmpty
                  ? (worker.fullName ?? worker.employeeId)[0].toUpperCase()
                  : '?',
              style: const TextStyle(
                  color: AppColors.ashaStart, fontWeight: FontWeight.w700, fontSize: 18),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(worker.fullName ?? worker.employeeId,
                    style: const TextStyle(
                        color: AppColors.textPrimary, fontWeight: FontWeight.w600)),
                const SizedBox(height: 3),
                Text(
                  [worker.location, worker.district]
                      .whereType<String>()
                      .join(' • '),
                  style: const TextStyle(color: AppColors.textSecondary, fontSize: 12),
                ),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: AppColors.primary.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(worker.employeeId,
                    style: const TextStyle(
                        color: AppColors.primary, fontSize: 10, fontWeight: FontWeight.w600)),
              ),
            ],
          ),
        ],
      ),
    ).animate().fade(delay: Duration(milliseconds: index * 40), duration: 350.ms).slideX(begin: 0.1);
  }
}
