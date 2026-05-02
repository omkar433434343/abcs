import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:go_router/go_router.dart';
import 'package:shimmer/shimmer.dart';
import 'package:fl_chart/fl_chart.dart';
import '../../../core/api/api_client.dart';
import '../../../core/api/endpoints.dart';
import '../../../core/auth/auth_provider.dart';
import '../../../core/i18n/app_localizations.dart';
import '../../../core/models/models.dart';
import '../../../core/theme/app_theme.dart';
import '../../../shared/widgets/offline_banner.dart';
import '../../../shared/widgets/language_selector.dart';

final _thoRecordsProvider = FutureProvider<List<TriageRecordModel>>((ref) async {
  try {
    final data = await ApiClient().getCachedList(
      ApiEndpoints.triageRecords,
      cacheKey: 'triage_records',
    );
    return data.map((e) => TriageRecordModel.fromJson(e)).toList();
  } catch (_) { return []; }
});

final _thoWorkersProvider = FutureProvider<List<UserModel>>((ref) async {
  try {
    final data = await ApiClient().getCachedList(
      ApiEndpoints.ashaWorkers,
      cacheKey: 'asha_workers',
    );
    return data.map((e) => UserModel.fromJson(e)).toList();
  } catch (_) { return []; }
});

final _thoPatientsProvider = FutureProvider<List<PatientModel>>((ref) async {
  try {
    final data = await ApiClient().getCachedList(
      ApiEndpoints.patients,
      cacheKey: 'patients',
    );
    return data.map((e) => PatientModel.fromJson(e)).toList();
  } catch (_) { return []; }
});

class ThoDashboard extends ConsumerWidget {
  const ThoDashboard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final auth = ref.watch(authProvider);
    final records = ref.watch(_thoRecordsProvider);
    final user = auth.user;

    return Scaffold(
      body: Container(
        decoration: BoxDecoration(gradient: AppTheme.backgroundGradient),
        child: SafeArea(
          child: RefreshIndicator(
            color: AppColors.primary,
            onRefresh: () async {
              ref.invalidate(_thoRecordsProvider);
              ref.invalidate(_thoWorkersProvider);
              ref.invalidate(_thoPatientsProvider);
            },
            child: CustomScrollView(
              slivers: [
              // ── Header ──────────────────────────────────────────────
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const OfflineBanner(),
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              gradient: AppTheme.thoGradient,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: const Icon(Icons.local_hospital_rounded,
                                color: Colors.white, size: 24),
                          ),
                          const SizedBox(width: 14),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(user?.fullName ?? context.tr('THO Officer'),
                                    style: const TextStyle(
                                        color: AppColors.textPrimary,
                                        fontWeight: FontWeight.w700,
                                        fontSize: 16)),
                                Text(
                                  '${user?.district ?? context.tr('All Districts')} ${context.tr('District')}',
                                  style: const TextStyle(
                                      color: AppColors.textSecondary, fontSize: 12),
                                ),
                              ],
                            ),
                          ),
                          const LanguageSelector(),
                          GestureDetector(
                            onTap: () => context.push('/tho/profile'),
                            child: const CircleAvatar(
                              radius: 20,
                              backgroundColor: Color(0xFF3949AB),
                              child: Icon(Icons.person_rounded,
                                  color: Colors.white, size: 22),
                            ),
                          ),
                        ],
                      ).animate().fade(duration: 500.ms),
                    ],
                  ),
                ),
              ),

              // ── Analytics Cards ──────────────────────────────────────
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 24, 20, 0),
                  child: records.when(
                    data: (data) {
                      final red = data.where((r) => r.severity == 'red').length;
                      final yellow = data.where((r) => r.severity == 'yellow').length;
                      final green = data.where((r) => r.severity == 'green').length;
                      final reviewed = data.where((r) => r.reviewed).length;
                      
                      final workers = ref.watch(_thoWorkersProvider);
                      final patients = ref.watch(_thoPatientsProvider);

                      return Column(
                        children: [
                          Row(
                            children: [
                              Expanded(
                                child: _ThoMetricCard(
                                  label: context.tr('Records'),
                                  value: '${data.length}',
                                  icon: Icons.assignment_rounded,
                                  color: AppColors.primary,
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: _ThoMetricCard(
                                  label: context.tr('Red Alerts'),
                                  value: '$red',
                                  icon: Icons.emergency_rounded,
                                  color: AppColors.severityRed,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          Row(
                            children: [
                              Expanded(
                                child: workers.when(
                                  data: (w) => _ThoMetricCard(
                                    label: context.tr('ASHA Workers'),
                                    value: '${w.length}',
                                    icon: Icons.people_rounded,
                                    color: AppColors.ashaStart,
                                  ),
                                  loading: () => const _LoadingMetric(),
                                  error: (_, __) => const _ErrorMetric(),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: patients.when(
                                  data: (p) => _ThoMetricCard(
                                    label: context.tr('Total Patients'),
                                    value: '${p.length}',
                                    icon: Icons.person_search_rounded,
                                    color: AppColors.info,
                                  ),
                                  loading: () => const _LoadingMetric(),
                                  error: (_, __) => const _ErrorMetric(),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 16),
                          // Pie chart
                          if (data.isNotEmpty)
                            Container(
                              height: 180,
                              padding: const EdgeInsets.all(16),
                              decoration: BoxDecoration(
                                color: AppColors.card,
                                borderRadius: BorderRadius.circular(16),
                                border: Border.all(color: AppColors.cardBorder),
                              ),
                              child: Row(
                                children: [
                                  Expanded(
                                    child: PieChart(PieChartData(
                                      sectionsSpace: 2,
                                      centerSpaceRadius: 30,
                                      sections: [
                                        if (red > 0)
                                          PieChartSectionData(
                                            value: red.toDouble(),
                                            color: AppColors.severityRed,
                                            title: '$red',
                                            radius: 50,
                                            titleStyle: const TextStyle(
                                                color: Colors.white,
                                                fontWeight: FontWeight.bold,
                                                fontSize: 12),
                                          ),
                                        if (yellow > 0)
                                          PieChartSectionData(
                                            value: yellow.toDouble(),
                                            color: AppColors.severityYellow,
                                            title: '$yellow',
                                            radius: 50,
                                            titleStyle: const TextStyle(
                                                color: Colors.white,
                                                fontWeight: FontWeight.bold,
                                                fontSize: 12),
                                          ),
                                        if (green > 0)
                                          PieChartSectionData(
                                            value: green.toDouble(),
                                            color: AppColors.severityGreen,
                                            title: '$green',
                                            radius: 50,
                                            titleStyle: const TextStyle(
                                                color: Colors.white,
                                                fontWeight: FontWeight.bold,
                                                fontSize: 12),
                                          ),
                                      ],
                                    )),
                                  ),
                                  const SizedBox(width: 16),
                                  Column(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      _Legend(context.tr('Red'), AppColors.severityRed),
                                      const SizedBox(height: 8),
                                      _Legend(context.tr('Yellow'), AppColors.severityYellow),
                                      const SizedBox(height: 8),
                                      _Legend(context.tr('Green'), AppColors.severityGreen),
                                      const SizedBox(height: 16),
                                      Text('${context.tr('Reviewed')}: $reviewed/${data.length}',
                                          style: const TextStyle(
                                              color: AppColors.textSecondary,
                                              fontSize: 11)),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                        ],
                      );
                    },
                    loading: () => Shimmer.fromColors(
                      baseColor: AppColors.card,
                      highlightColor: AppColors.cardBorder,
                      child: Container(
                          height: 220,
                          decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(16))),
                    ),
                    error: (_, __) => const SizedBox(),
                  ),
                ),
              ),

              // Quick Actions section removed as requested

              // ── Recent Red Alerts ────────────────────────────────────
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
                  child: Text('🚨 ${context.tr('Red Alerts')}',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                        color: AppColors.textPrimary,
                      )),
                ),
              ),

              records.when(
                data: (data) {
                  final reds = data.where((r) => r.severity == 'red').take(5).toList();
                  if (reds.isEmpty) {
                    return SliverToBoxAdapter(
                      child: Padding(
                        padding: const EdgeInsets.all(20),
                        child: Text(context.tr('No red alerts 🎉'),
                            style: const TextStyle(color: AppColors.textSecondary)),
                      ),
                    );
                  }
                  return SliverList(
                    delegate: SliverChildBuilderDelegate(
                      (ctx, i) => _AlertTile(record: reds[i]),
                      childCount: reds.length,
                    ),
                  );
                },
                loading: () => const SliverToBoxAdapter(child: SizedBox()),
                error: (_, __) => const SliverToBoxAdapter(child: SizedBox()),
              ),

              const SliverToBoxAdapter(child: SizedBox(height: 80)),
            ],
          ),
        ),
      ),
    ),
    );
  }
}

class _ThoMetricCard extends StatelessWidget {
  final String label, value;
  final IconData icon;
  final Color color;
  const _ThoMetricCard({
    required this.label, required this.value, required this.icon, required this.color
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.cardBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: color, size: 22),
          const SizedBox(height: 12),
          Text(value,
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.w800, color: AppColors.textPrimary)),
          const SizedBox(height: 2),
          Text(label,
              style: const TextStyle(color: AppColors.textSecondary, fontSize: 11)),
        ],
      ),
    );
  }
}

class _LoadingMetric extends StatelessWidget {
  const _LoadingMetric();
  @override
  Widget build(BuildContext context) {
    return Shimmer.fromColors(
      baseColor: AppColors.card,
      highlightColor: AppColors.cardBorder,
      child: Container(
        height: 100,
        decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16)),
      ),
    );
  }
}

class _ErrorMetric extends StatelessWidget {
  const _ErrorMetric();
  @override
  Widget build(BuildContext context) {
    return Container(
      height: 100,
      decoration: BoxDecoration(
          color: AppColors.card, borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.error.withOpacity(0.2))),
      child: const Center(child: Icon(Icons.error_outline, color: AppColors.error, size: 20)),
    );
  }
}

class _Legend extends StatelessWidget {
  final String label;
  final Color color;
  const _Legend(this.label, this.color);

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(width: 10, height: 10, decoration: BoxDecoration(
            color: color, shape: BoxShape.circle)),
        const SizedBox(width: 8),
        Text(label, style: const TextStyle(color: AppColors.textSecondary, fontSize: 12)),
      ],
    );
  }
}

class _AlertTile extends StatelessWidget {
  final TriageRecordModel record;
  const _AlertTile({required this.record});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 5),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.severityRed.withOpacity(0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.severityRed.withOpacity(0.3)),
      ),
      child: Row(
        children: [
          const Icon(Icons.emergency_rounded, color: AppColors.severityRed, size: 20),
          const SizedBox(width: 12),
          Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(record.patientName,
                      style: const TextStyle(
                          color: AppColors.textPrimary, fontWeight: FontWeight.w600)),
                  Text(record.brief,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(color: AppColors.textSecondary, fontSize: 12)),
                ],
              ),
            ),
          if (record.sickleCell)
            const Icon(Icons.warning_rounded, color: AppColors.warning, size: 16),
        ],
      ),
    );
  }
}
