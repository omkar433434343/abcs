import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import '../../../core/api/api_client.dart';
import '../../../core/api/endpoints.dart';
import '../../../core/models/models.dart';
import '../../../core/theme/app_theme.dart';

final _outbreaksProvider = FutureProvider<List<OutbreakModel>>((ref) async {
  final data = await ApiClient().getCachedList(
    ApiEndpoints.outbreaks,
    cacheKey: 'outbreaks',
  );
  return data.map((e) => OutbreakModel.fromJson(e)).toList();
});

class OutbreakMapScreen extends ConsumerWidget {
  const OutbreakMapScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final outbreaks = ref.watch(_outbreaksProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Disease Outbreak Map')),
      body: outbreaks.when(
        data: (data) {
          final markers = data
              .where((o) => o.latitude != null && o.longitude != null)
              .map((o) => Marker(
                    point: LatLng(o.latitude!, o.longitude!),
                    width: 40,
                    height: 40,
                    child: GestureDetector(
                      onTap: () => _showOutbreakInfo(context, o),
                      child: Container(
                        decoration: BoxDecoration(
                          color: _severityForCases(o.cases),
                          shape: BoxShape.circle,
                          boxShadow: [
                            BoxShadow(
                              color: _severityForCases(o.cases).withOpacity(0.4),
                              blurRadius: 8,
                            )
                          ],
                        ),
                        child: const Icon(Icons.warning_rounded,
                            color: Colors.white, size: 20),
                      ),
                    ),
                  ))
              .toList();

          return FlutterMap(
            options: MapOptions(
              initialCenter: const LatLng(20.5937, 78.9629), // India center
              initialZoom: 5.5,
            ),
            children: [
              TileLayer(
                urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                userAgentPackageName: 'com.swasthyasetu.app',
              ),
              if (markers.isNotEmpty) MarkerLayer(markers: markers),
            ],
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (_, __) => const Center(
          child: Text('Could not load outbreak data',
              style: TextStyle(color: AppColors.textSecondary)),
        ),
      ),
    );
  }

  Color _severityForCases(int? cases) {
    if (cases == null) return AppColors.severityYellow;
    if (cases > 100) return AppColors.severityRed;
    if (cases > 20) return AppColors.severityYellow;
    return AppColors.severityGreen;
  }

  void _showOutbreakInfo(BuildContext context, OutbreakModel o) {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.card,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: AppColors.severityRed.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(o.disease ?? 'Unknown Disease',
                      style: const TextStyle(
                          color: AppColors.severityRed, fontWeight: FontWeight.w700)),
                ),
                const Spacer(),
                if (o.status != null)
                  Text(o.status!,
                      style: const TextStyle(
                          color: AppColors.textSecondary, fontSize: 12)),
              ],
            ),
            const SizedBox(height: 16),
            _InfoRow('District', o.district ?? '—'),
            _InfoRow('State', o.state ?? '—'),
            _InfoRow('Cases', '${o.cases ?? 0}'),
            _InfoRow('Deaths', '${o.deaths ?? 0}'),
            if (o.week != null) _InfoRow('Week / Year', 'W${o.week} / ${o.year}'),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  final String label, value;
  const _InfoRow(this.label, this.value);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Text('$label: ',
              style: const TextStyle(
                  color: AppColors.textMuted, fontSize: 13)),
          Text(value,
              style: const TextStyle(
                  color: AppColors.textPrimary, fontWeight: FontWeight.w600, fontSize: 13)),
        ],
      ),
    );
  }
}
