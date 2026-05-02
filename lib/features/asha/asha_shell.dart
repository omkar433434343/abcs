import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../core/i18n/app_localizations.dart';

class AshaShell extends StatelessWidget {
  final StatefulNavigationShell navigationShell;

  const AshaShell({
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
          BottomNavigationBarItem(icon: const Icon(Icons.home_rounded), label: context.tr('Home')),
          BottomNavigationBarItem(icon: const Icon(Icons.people_rounded), label: context.tr('Patients')),
          BottomNavigationBarItem(icon: const Icon(Icons.assignment_add), label: context.tr('Triage')),
        ],
      ),
    );
  }
}
