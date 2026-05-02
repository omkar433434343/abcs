import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../core/i18n/app_localizations.dart';

class ThoShell extends StatelessWidget {
  final StatefulNavigationShell navigationShell;

  const ThoShell({
    super.key,
    required this.navigationShell,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: navigationShell,
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: navigationShell.currentIndex,
        onTap: (index) => navigationShell.goBranch(index),
        items: [
          BottomNavigationBarItem(icon: const Icon(Icons.dashboard_rounded), label: context.tr('Overview')),
          BottomNavigationBarItem(icon: const Icon(Icons.fact_check_rounded), label: context.tr('Review')),
          BottomNavigationBarItem(icon: const Icon(Icons.people_rounded), label: context.tr('ASHA')),
          BottomNavigationBarItem(icon: const Icon(Icons.map_rounded), label: context.tr('Map')),
        ],
      ),
    );
  }
}
