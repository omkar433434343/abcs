import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'core/api/api_client.dart';
import 'core/router.dart';
import 'core/theme/app_theme.dart';
import 'core/offline/offline_queue.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  ApiClient().init();
  runApp(const ProviderScope(child: SwasthyaSetuApp()));
}

class SwasthyaSetuApp extends ConsumerWidget {
  const SwasthyaSetuApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final router = ref.watch(routerProvider);

    // Listen to connectivity changes and trigger sync when back online
    ref.listen(connectivityProvider, (prev, next) {
      next.whenData((online) {
        if (online) SyncService.syncAll();
      });
    });

    return MaterialApp.router(
      title: 'Swasthya Setu',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.dark,
      routerConfig: router,
    );
  }
}
