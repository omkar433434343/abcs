import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../core/theme/app_theme.dart';

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
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.home_rounded), label: 'Home'),
          BottomNavigationBarItem(icon: Icon(Icons.people_rounded), label: 'Patients'),
          BottomNavigationBarItem(icon: Icon(Icons.assignment_add), label: 'Triage'),
          BottomNavigationBarItem(icon: Icon(Icons.history_rounded), label: 'Records'),
        ],
      ),
    );
  }
}
