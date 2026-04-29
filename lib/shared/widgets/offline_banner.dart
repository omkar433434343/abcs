import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/offline/offline_queue.dart';
import '../../core/theme/app_theme.dart';

class OfflineBanner extends ConsumerWidget {
  const OfflineBanner({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final connectivity = ref.watch(connectivityProvider);
    return connectivity.when(
      data: (online) => online
          ? const SizedBox()
          : Container(
              margin: const EdgeInsets.only(bottom: 12),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: AppColors.offline.withOpacity(0.12),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: AppColors.offline.withOpacity(0.3)),
              ),
              child: Row(
                children: const [
                  Icon(Icons.wifi_off_rounded, color: AppColors.offline, size: 16),
                  SizedBox(width: 10),
                  Text('You are offline — data will sync when connected',
                      style: TextStyle(color: AppColors.offline, fontSize: 12)),
                ],
              ),
            ),
      loading: () => const SizedBox(),
      error: (_, __) => const SizedBox(),
    );
  }
}
