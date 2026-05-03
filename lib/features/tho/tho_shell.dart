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
    final current = navigationShell.currentIndex;
    return Scaffold(
      body: navigationShell,
      bottomNavigationBar: Container(
        padding: const EdgeInsets.fromLTRB(8, 8, 8, 12),
        decoration: BoxDecoration(
          color: Colors.white,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.06),
              blurRadius: 16,
              offset: const Offset(0, -3),
            ),
          ],
        ),
        child: Row(
          children: [
            _NavItem(icon: Icons.dashboard_rounded, label: context.tr('Overview'), active: current == 0, onTap: () => navigationShell.goBranch(0)),
            _NavItem(icon: Icons.people_rounded, label: context.tr('Patients'), active: current == 1, onTap: () => navigationShell.goBranch(1)),
            _NavItem(icon: Icons.groups_rounded, label: context.tr('ASHA'), active: current == 2, onTap: () => navigationShell.goBranch(2)),
            _NavItem(icon: Icons.map_rounded, label: context.tr('Map'), active: current == 3, onTap: () => navigationShell.goBranch(3)),
          ],
        ),
      ),
    );
  }
}

class _NavItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool active;
  final VoidCallback onTap;
  const _NavItem({required this.icon, required this.label, required this.active, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 220),
          curve: Curves.easeOutBack,
          margin: EdgeInsets.symmetric(horizontal: 3, vertical: active ? 0 : 6),
          padding: EdgeInsets.symmetric(vertical: active ? 9 : 7),
          decoration: BoxDecoration(
            color: active ? const Color(0xFFEAF9EE) : Colors.transparent,
            borderRadius: BorderRadius.circular(14),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              AnimatedScale(
                duration: const Duration(milliseconds: 220),
                scale: active ? 1.2 : 1,
                child: Icon(icon, color: active ? const Color(0xFF21A95A) : const Color(0xFF8D97A5), size: 21),
              ),
              const SizedBox(height: 3),
              Text(
                label,
                style: TextStyle(
                  color: active ? const Color(0xFF1E7A46) : const Color(0xFF8D97A5),
                  fontSize: 10.5,
                  fontWeight: active ? FontWeight.w700 : FontWeight.w500,
                ),
              )
            ],
          ),
        ),
      ),
    );
  }
}
