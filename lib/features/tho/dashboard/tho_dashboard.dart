import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:go_router/go_router.dart';
import 'package:shimmer/shimmer.dart';
import 'package:fl_chart/fl_chart.dart';
import '../../../core/api/api_client.dart';
import '../../../core/api/endpoints.dart';
import '../../../core/auth/auth_provider.dart';
import '../../../core/models/models.dart';
import '../../../core/theme/app_theme.dart';
import '../../../shared/widgets/offline_banner.dart';

final _thoRecordsProvider = FutureProvider<List<TriageRecordModel>>((ref) async {
  try {
    final res = await ApiClient().dio.get(ApiEndpoints.triageRecords);
    return (res.data as List).map((e) => TriageRecordModel.fromJson(e)).toList();
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
                                Text(user?.fullName ?? 'THO Officer',
                                    style: const TextStyle(
                                        color: AppColors.textPrimary,
                                        fontWeight: FontWeight.w700,
                                        fontSize: 16)),
                                Text(
                                  '${user?.district ?? 'All Districts'} District',
                                  style: const TextStyle(
                                      color: AppColors.textSecondary, fontSize: 12),
                                ),
                              ],
                            ),
                          ),
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
                      return Column(
                        children: [
                          Row(
                            children: [
                              _StatChip(label: 'Total', value: '${data.length}',
                                  color: AppColors.primary),
                              const SizedBox(width: 10),
                              _StatChip(label: 'Red', value: '$red',
                                  color: AppColors.severityRed),
                              const SizedBox(width: 10),
                              _StatChip(label: 'Yellow', value: '$yellow',
                                  color: AppColors.severityYellow),
                              const SizedBox(width: 10),
                              _StatChip(label: 'Green', value: '$green',
                                  color: AppColors.severityGreen),
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
                                      _Legend('Red', AppColors.severityRed),
                                      const SizedBox(height: 8),
                                      _Legend('Yellow', AppColors.severityYellow),
                                      const SizedBox(height: 8),
                                      _Legend('Green', AppColors.severityGreen),
                                      const SizedBox(height: 16),
                                      Text('Reviewed: $reviewed/${data.length}',
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

              // ── Quick Actions ────────────────────────────────────────
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 24, 20, 8),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Quick Access',
                          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w700,
                            color: AppColors.textPrimary,
                          )),
                      const SizedBox(height: 14),
                      GridView.count(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        crossAxisCount: 2,
                        mainAxisSpacing: 12,
                        crossAxisSpacing: 12,
                        childAspectRatio: 1.6,
                        children: [
                          _ThoActionCard(
                            title: 'Review Queue',
                            subtitle: 'Pending triage records',
                            icon: Icons.fact_check_rounded,
                            gradient: AppTheme.thoGradient,
                            onTap: () => context.push('/tho/triage-review'),
                          ),
                          _ThoActionCard(
                            title: 'ASHA Network',
                            subtitle: 'Worker directory',
                            icon: Icons.people_rounded,
                            gradient: AppTheme.ashaGradient,
                            onTap: () => context.push('/tho/asha-network'),
                          ),
                          _ThoActionCard(
                            title: 'Outbreak Map',
                            subtitle: 'Disease tracking',
                            icon: Icons.map_rounded,
                            gradient: const LinearGradient(
                                colors: [Color(0xFFEF5350), Color(0xFFD32F2F)]),
                            onTap: () => context.push('/tho/outbreaks'),
                          ),
                          _ThoActionCard(
                            title: 'My Profile',
                            subtitle: 'Account settings',
                            icon: Icons.manage_accounts_rounded,
                            gradient: const LinearGradient(
                                colors: [Color(0xFF546E7A), Color(0xFF37474F)]),
                            onTap: () => context.push('/tho/profile'),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),

              // ── Recent Red Alerts ────────────────────────────────────
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
                  child: Text('🚨 Red Alerts',
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
                    return const SliverToBoxAdapter(
                      child: Padding(
                        padding: EdgeInsets.all(20),
                        child: Text('No red alerts 🎉',
                            style: TextStyle(color: AppColors.textSecondary)),
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
      bottomNavigationBar: _ThoBotNav(current: 0),
    );
  }
}

class _StatChip extends StatelessWidget {
  final String label, value;
  final Color color;
  const _StatChip({required this.label, required this.value, required this.color});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          color: color.withOpacity(0.12),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: color.withOpacity(0.3)),
        ),
        child: Column(
          children: [
            Text(value,
                style: TextStyle(
                    color: color, fontSize: 20, fontWeight: FontWeight.w800)),
            Text(label,
                style: const TextStyle(color: AppColors.textMuted, fontSize: 10)),
          ],
        ),
      ),
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

class _ThoActionCard extends StatelessWidget {
  final String title, subtitle;
  final IconData icon;
  final LinearGradient gradient;
  final VoidCallback onTap;
  const _ThoActionCard({
    required this.title, required this.subtitle, required this.icon,
    required this.gradient, required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          gradient: gradient,
          borderRadius: BorderRadius.circular(14),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, color: Colors.white, size: 24),
            const Spacer(),
            Text(title,
                style: const TextStyle(
                    color: Colors.white, fontWeight: FontWeight.w700, fontSize: 13)),
            Text(subtitle,
                style: TextStyle(color: Colors.white.withOpacity(0.7), fontSize: 10)),
          ],
        ),
      ),
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

class _ThoBotNav extends StatelessWidget {
  final int current;
  const _ThoBotNav({required this.current});

  @override
  Widget build(BuildContext context) {
    return BottomNavigationBar(
      currentIndex: current,
      onTap: (i) {
        switch (i) {
          case 0: context.go('/tho'); break;
          case 1: context.push('/tho/triage-review'); break;
          case 2: context.push('/tho/asha-network'); break;
          case 3: context.push('/tho/outbreaks'); break;
        }
      },
      items: const [
        BottomNavigationBarItem(icon: Icon(Icons.dashboard_rounded), label: 'Overview'),
        BottomNavigationBarItem(icon: Icon(Icons.fact_check_rounded), label: 'Review'),
        BottomNavigationBarItem(icon: Icon(Icons.people_rounded), label: 'ASHA'),
        BottomNavigationBarItem(icon: Icon(Icons.map_rounded), label: 'Map'),
      ],
    );
  }
}
