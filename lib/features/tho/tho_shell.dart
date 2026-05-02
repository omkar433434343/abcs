import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

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
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.dashboard_rounded), label: 'Overview'),
          BottomNavigationBarItem(icon: Icon(Icons.fact_check_rounded), label: 'Review'),
          BottomNavigationBarItem(icon: Icon(Icons.people_rounded), label: 'ASHA'),
          BottomNavigationBarItem(icon: Icon(Icons.map_rounded), label: 'Map'),
        ],
      ),
    );
  }
}
