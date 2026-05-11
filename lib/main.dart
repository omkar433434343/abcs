import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'core/api/api_client.dart';
import 'core/router.dart';
import 'core/theme/app_theme.dart';
import 'core/offline/offline_queue.dart';
import 'core/i18n/app_localizations.dart';
import 'core/i18n/locale_provider.dart';
import 'shared/widgets/app_logo_mark.dart';

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
    final locale = ref.watch(localeProvider);

    // Listen to connectivity changes and trigger sync when back online
    ref.listen(connectivityProvider, (prev, next) {
      next.whenData((online) {
        if (online) SyncService.syncAll();
      });
    });

    return MaterialApp.router(
      title: 'Swasthya Setu',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light,
      locale: locale,
      supportedLocales: AppLocalizations.supportedLocales,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      routerConfig: router,
      builder: (context, child) {
        final content = child ?? const SizedBox.shrink();
        return Stack(
          children: [
            Positioned.fill(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: AppTheme.backgroundGradient,
                ),
              ),
            ),
            Positioned(
              top: -120,
              right: -80,
              child: IgnorePointer(
                child: Container(
                  width: 280,
                  height: 280,
                  decoration: const BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: RadialGradient(
                      colors: [Color(0x5522C55E), Color(0x0022C55E)],
                    ),
                  ),
                ),
              ),
            ),
            Positioned(
              bottom: -140,
              left: -90,
              child: IgnorePointer(
                child: Container(
                  width: 300,
                  height: 300,
                  decoration: const BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: RadialGradient(
                      colors: [Color(0x3322C55E), Color(0x0022C55E)],
                    ),
                  ),
                ),
              ),
            ),
            Positioned.fill(child: content),
            IgnorePointer(
              child: SafeArea(
                child: Align(
                  alignment: Alignment.topRight,
                  child: Padding(
                    padding: const EdgeInsets.only(top: 8, right: 10),
                    child: Opacity(
                      opacity: 0.16,
                      child: const AppLogoMark(size: 24),
                    ),
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}
