import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:go_router/go_router.dart';
import 'package:shimmer/shimmer.dart';
import '../../../core/auth/auth_provider.dart';
import '../../../core/api/api_client.dart';
import '../../../core/api/endpoints.dart';
import '../../../core/models/models.dart';
import '../../../core/i18n/app_localizations.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/offline/offline_queue.dart';
import '../../../shared/widgets/severity_badge.dart';
import '../../../shared/widgets/offline_banner.dart';
import '../../../shared/widgets/language_selector.dart';

final _ashaRecordsProvider = FutureProvider<List<TriageRecordModel>>((ref) async {
  try {
    final data = await ApiClient().getCachedList(
      ApiEndpoints.triageRecords,
      cacheKey: 'triage_records',
    );
    return data.map((e) => TriageRecordModel.fromJson(e)).toList();
  } catch (_) {
    return [];
  }
});

final _ashaPatientsProvider = FutureProvider<List<PatientModel>>((ref) async {
  try {
    final data = await ApiClient().getCachedList(
      ApiEndpoints.patients,
      cacheKey: 'patients',
    );
    return data.map((e) => PatientModel.fromJson(e)).toList();
  } catch (_) {
    return [];
  }
});

class AshaDashboard extends ConsumerStatefulWidget {
  const AshaDashboard({super.key});

  @override
  ConsumerState<AshaDashboard> createState() => _AshaDashboardState();
}

class _AshaDashboardState extends ConsumerState<AshaDashboard> {
  @override
  void initState() {
    super.initState();
    // Auto-sync offline data and refresh providers on load
    _refreshData();
  }

  Future<void> _refreshData() async {
    await SyncService.syncAll();
    ref.invalidate(_ashaRecordsProvider);
    ref.invalidate(_ashaPatientsProvider);
    ref.invalidate(offlineQueueCountProvider);
  }

  @override
  Widget build(BuildContext context) {
    final auth = ref.watch(authProvider);
    final records = ref.watch(_ashaRecordsProvider);
    final patients = ref.watch(_ashaPatientsProvider);
    final queueCount = ref.watch(offlineQueueCountProvider);
    final user = auth.user;

    return Scaffold(
      body: Container(
        decoration: BoxDecoration(gradient: AppTheme.backgroundGradient),
        child: SafeArea(
          child: RefreshIndicator(
            onRefresh: _refreshData,
            color: AppColors.primary,
            child: CustomScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              slivers: [
                // ── Header ─────────────────────────────────────────────
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const OfflineBanner(),
                        Row(
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    context.tr('Namaste 🙏'),
                                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                      color: AppColors.textSecondary,
                                    ),
                                  ),
                                  Text(
                                    user?.fullName ?? user?.employeeId ?? context.tr('ASHA Worker'),
                                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                                      fontWeight: FontWeight.w700,
                                      color: AppColors.textPrimary,
                                    ),
                                  ),
                                  if (user?.location != null)
                                    Text(
                                      '📍 ${user!.location}',
                                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                        color: AppColors.textSecondary,
                                      ),
                                    ),
                                ],
                              ),
                            ),
                            const LanguageSelector(),
                            GestureDetector(
                              onTap: () => context.push('/asha/profile'),
                              child: CircleAvatar(
                                radius: 24,
                                backgroundColor: AppColors.primary.withOpacity(0.2),
                                child: const Icon(Icons.person_rounded, color: AppColors.primary),
                              ),
                            ),
                          ],
                        ).animate().fade(duration: 500.ms),
  
                        const SizedBox(height: 24),
  
                        // Offline queue alert
                        queueCount.when(
                          data: (count) => count > 0
                              ? _OfflineQueueBadge(count: count)
                              : const SizedBox(),
                          loading: () => const SizedBox(),
                          error: (_, __) => const SizedBox(),
                        ),
                      ],
                    ),
                  ),
                ),
  
                // ── Stats Row ──────────────────────────────────────────
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                    child: Row(
                      children: [
                        Expanded(
                          child: _StatCard(
                            label: context.tr('Patients'),
                            icon: Icons.people_rounded,
                            asyncValue: patients,
                            valueBuilder: (data) => '${data.length}',
                            color: AppColors.primary,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _StatCard(
                            label: context.tr('Red Alerts'),
                            icon: Icons.warning_rounded,
                            asyncValue: records,
                            valueBuilder: (data) =>
                                '${data.where((r) => r.severity == 'red').length}',
                            color: AppColors.severityRed,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _StatCard(
                            label: context.tr('Triages'),
                            icon: Icons.assignment_rounded,
                            asyncValue: records,
                            valueBuilder: (data) => '${data.length}',
                            color: AppColors.accent,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
  
                // ── Recent Triage ──────────────────────────────────────
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(20, 24, 20, 8),
                    child: Text(
                      context.tr('Recent Triage'),
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                        color: AppColors.textPrimary,
                      ),
                    ),
                  ),
                ),
  
                records.when(
                  data: (data) {
                    if (data.isEmpty) {
                      return SliverToBoxAdapter(
                        child: _EmptyState(
                          icon: Icons.assignment_outlined,
                          message: context.tr('No triage records yet.\nTap Triage tab to start.'),
                        ),
                      );
                    }
                    return SliverList(
                      delegate: SliverChildBuilderDelegate(
                        (ctx, i) => _TriageListTile(record: data[i], index: i),
                        childCount: data.take(5).length,
                      ),
                    );
                  },
                  loading: () => SliverToBoxAdapter(child: _ShimmerList()),
                  error: (_, __) => SliverToBoxAdapter(
                    child: _EmptyState(
                      icon: Icons.cloud_off_rounded,
                      message: context.tr('Could not load records.\nYou may be offline.'),
                    ),
                  ),
                ),
  
                const SliverToBoxAdapter(child: SizedBox(height: 100)),
              ],
            ),
          ),
        ),
      ),

      // Bottom nav is now handled by AshaShell
    );
  }
}


// ── Sub-widgets ──────────────────────────────────────────────────────────────

class _OfflineQueueBadge extends StatelessWidget {
  final int count;
  const _OfflineQueueBadge({required this.count});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: AppColors.warning.withOpacity(0.12),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColors.warning.withOpacity(0.3)),
      ),
      child: Row(
        children: [
          const Icon(Icons.cloud_upload_outlined, color: AppColors.warning, size: 18),
          const SizedBox(width: 10),
          Text(
            context.tr('Pending sync items').replaceAll('{count}', '$count'),
            style: const TextStyle(color: AppColors.warning, fontSize: 13),
          ),
        ],
      ),
    );
  }
}

class _StatCard extends StatelessWidget {
  final String label;
  final IconData icon;
  final AsyncValue asyncValue;
  final String Function(dynamic) valueBuilder;
  final Color color;

  const _StatCard({
    required this.label,
    required this.icon,
    required this.asyncValue,
    required this.valueBuilder,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.cardBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: color, size: 22),
          const SizedBox(height: 8),
          asyncValue.when(
            data: (d) => Text(
              valueBuilder(d),
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.w800,
                color: AppColors.textPrimary,
              ),
            ),
            loading: () => Shimmer.fromColors(
              baseColor: AppColors.card,
              highlightColor: AppColors.cardBorder,
              child: Container(width: 30, height: 24, color: Colors.white),
            ),
            error: (_, __) => const Text('—', style: TextStyle(color: AppColors.textMuted)),
          ),
          const SizedBox(height: 2),
          Text(label,
              style: const TextStyle(color: AppColors.textSecondary, fontSize: 11)),
        ],
      ),
    );
  }
}

class _QuickAction extends StatelessWidget {
  final String label;
  final IconData icon;
  final LinearGradient gradient;
  final VoidCallback onTap;
  final int delay;

  const _QuickAction({
    required this.label,
    required this.icon,
    required this.gradient,
    required this.onTap,
    required this.delay,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 16),
        decoration: BoxDecoration(
          gradient: gradient,
          borderRadius: BorderRadius.circular(14),
        ),
        child: Column(
          children: [
            Icon(icon, color: Colors.white, size: 26),
            const SizedBox(height: 8),
            Text(
              label,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 10,
                fontWeight: FontWeight.w600,
                height: 1.3,
              ),
            ),
          ],
        ),
      ),
    ).animate().fade(delay: Duration(milliseconds: delay), duration: 400.ms).scale(begin: const Offset(0.9, 0.9));
  }
}

class _TriageListTile extends StatelessWidget {
  final TriageRecordModel record;
  final int index;
  const _TriageListTile({required this.record, required this.index});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 5),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.cardBorder),
      ),
      child: Row(
        children: [
          SeverityBadge(severity: record.severity),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  record.patientName,
                  style: const TextStyle(
                      color: AppColors.textPrimary, fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 3),
                Text(
                  record.brief,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(color: AppColors.textSecondary, fontSize: 12),
                ),
              ],
            ),
          ),
          if (record.reviewed)
            const Icon(Icons.check_circle_rounded, color: AppColors.success, size: 18),
        ],
      ),
    ).animate().fade(delay: Duration(milliseconds: index * 60), duration: 400.ms).slideX(begin: 0.1);
  }
}

class _ShimmerList extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Shimmer.fromColors(
      baseColor: AppColors.card,
      highlightColor: AppColors.cardBorder,
      child: Column(
        children: List.generate(
          3,
          (_) => Container(
            margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 5),
            height: 70,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(14),
            ),
          ),
        ),
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  final IconData icon;
  final String message;
  const _EmptyState({required this.icon, required this.message});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(40),
      child: Column(
        children: [
          Icon(icon, size: 48, color: AppColors.textMuted),
          const SizedBox(height: 16),
          Text(
            message,
            textAlign: TextAlign.center,
            style: const TextStyle(color: AppColors.textSecondary, height: 1.5),
          ),
        ],
      ),
    );
  }
}

// _AshaBotNav removed - handled by AshaShell
