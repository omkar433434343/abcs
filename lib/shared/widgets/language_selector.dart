import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/i18n/app_localizations.dart';
import '../../core/i18n/locale_provider.dart';

class LanguageSelector extends ConsumerWidget {
  const LanguageSelector({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final locale = ref.watch(localeProvider);
    return PopupMenuButton<String>(
      tooltip: context.tr('Language'),
      icon: const Icon(Icons.language_rounded),
      onSelected: (code) => ref.read(localeProvider.notifier).setLocale(code),
      itemBuilder: (_) => [
        PopupMenuItem(
          value: 'en',
          child: Text('${locale.languageCode == 'en' ? '• ' : ''}${context.tr('English')}'),
        ),
        PopupMenuItem(
          value: 'hi',
          child: Text('${locale.languageCode == 'hi' ? '• ' : ''}${context.tr('Hindi')}'),
        ),
        PopupMenuItem(
          value: 'kn',
          child: Text('${locale.languageCode == 'kn' ? '• ' : ''}${context.tr('Kannada')}'),
        ),
      ],
    );
  }
}
