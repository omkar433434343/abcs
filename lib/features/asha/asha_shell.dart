import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'dart:ui';
import '../../core/i18n/app_localizations.dart';

class AshaShell extends StatelessWidget {
  final StatefulNavigationShell navigationShell;

  const AshaShell({
    super.key,
    required this.navigationShell,
  });

  @override
  Widget build(BuildContext context) {
    final current = navigationShell.currentIndex;
    return Scaffold(
      body: navigationShell,
      bottomNavigationBar: Padding(
        padding: const EdgeInsets.fromLTRB(10, 0, 10, 12),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(24),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
            child: Container(
              padding: const EdgeInsets.fromLTRB(10, 8, 10, 10),
              decoration: BoxDecoration(
                color: const Color(0xBFFFFFFF),
                border: Border.all(color: const Color(0x66FFFFFF)),
                boxShadow: const [
                  BoxShadow(
                    color: Color(0x3322C55E),
                    blurRadius: 24,
                    offset: Offset(0, 8),
                  ),
                ],
              ),
              child: Row(
                children: [
                  _NavItem(
                    icon: Icons.home_rounded,
                    label: context.tr('Home'),
                    active: current == 0,
                    onTap: () => navigationShell.goBranch(0),
                  ),
                  _NavItem(
                    icon: Icons.people_rounded,
                    label: context.tr('Patients'),
                    active: current == 1,
                    onTap: () => navigationShell.goBranch(1),
                  ),
                  _NavItem(
                    icon: Icons.assignment_add,
                    label: context.tr('Triage'),
                    active: current == 2,
                    onTap: () => navigationShell.goBranch(2),
                  ),
                ],
              ),
            ),
          ),
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
          curve: Curves.easeOutCubic,
          margin: EdgeInsets.symmetric(horizontal: 4, vertical: active ? 0 : 6),
          padding: EdgeInsets.symmetric(vertical: active ? 10 : 8),
          decoration: BoxDecoration(
            color: active ? const Color(0x66D1FADF) : Colors.transparent,
            borderRadius: BorderRadius.circular(14),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              AnimatedScale(
                duration: const Duration(milliseconds: 220),
                scale: active ? 1.22 : 1,
                child: Icon(icon, color: active ? const Color(0xFF21A95A) : const Color(0xFF8D97A5)),
              ),
              const SizedBox(height: 4),
              Text(
                label,
                style: TextStyle(
                  color: active ? const Color(0xFF1E7A46) : const Color(0xFF8D97A5),
                  fontSize: 11,
                  fontWeight: active ? FontWeight.w700 : FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
