import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:go_router/go_router.dart';
import 'dart:convert';
import '../../core/auth/auth_provider.dart';
import '../../core/i18n/app_localizations.dart';
import '../../core/theme/app_theme.dart';
import '../../shared/widgets/language_selector.dart';

class ProfileScreen extends ConsumerWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(authProvider).user;
    final isAsha = user?.role == 'asha';
    final gradient = isAsha ? AppTheme.ashaGradient : AppTheme.thoGradient;

    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Container(
          width: double.infinity,
          height: double.infinity,
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                Color(0xFF4ADE80),
                Color(0xFFA7F3D0),
                Color(0xFFFFFFFF),
              ],
            ),
          ),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(10, 10, 10, 0),
            child: Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(14),
                color: Colors.transparent,
              ),
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(8, 8, 8, 0),
                  child: Row(
                    children: [
                      IconButton(
                        onPressed: () => context.pop(),
                        icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.white),
                      ),
                      const Spacer(),
                      const LanguageSelector(),
                      IconButton(
                        onPressed: () {},
                        icon: const Icon(Icons.settings_rounded, color: Colors.white),
                      ),
                    ],
                  ),
                ),
                Hero(
                  tag: 'profile_avatar',
                  child: Container(
                    padding: const EdgeInsets.all(4),
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.white, width: 2),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.15),
                          blurRadius: 12,
                          offset: const Offset(0, 6),
                        )
                      ],
                    ),
                    child: CircleAvatar(
                      radius: 74,
                      backgroundColor: Colors.white,
                      backgroundImage: user?.avatarB64 != null ? MemoryImage(base64Decode(user!.avatarB64!)) : null,
                      child: user?.avatarB64 == null
                          ? Text(
                              (user?.fullName ?? user?.employeeId ?? '?').substring(0, 1).toUpperCase(),
                              style: TextStyle(
                                fontSize: 56,
                                fontWeight: FontWeight.w800,
                                color: gradient.colors.first,
                              ),
                            )
                          : null,
                    ),
                  ),
                ).animate().scale(duration: 450.ms),
                const SizedBox(height: 10),
                Text(
                  user?.fullName ?? 'No Name Set',
                  style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.w800),
                ),
                Text(
                  '${(user?.role ?? '').toUpperCase()} • ${user?.employeeId ?? '—'}',
                  style: TextStyle(color: Colors.white.withOpacity(0.9), fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 12),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 14),
                  child: Row(
                    children: [
                      Expanded(
                        child: _ActionPill(
                          label: 'Edit Profile',
                          onTap: () => ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('Profile details are managed by THO administration.')),
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: _ActionPill(
                          label: 'Share Profile',
                          onTap: () => ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('Share coming soon.')),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                Expanded(
                  child: Container(
                    width: double.infinity,
                    margin: const EdgeInsets.fromLTRB(8, 0, 8, 8),
                    padding: const EdgeInsets.fromLTRB(10, 10, 10, 4),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF8FFF9),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: const Color(0xFFB6EAC3)),
                    ),
                      child: ListView(
                      children: [
                        _MenuTile(icon: Icons.translate_rounded, iconColor: const Color(0xFF58A6FF), title: 'Language'),
                        _MenuTile(icon: Icons.place_rounded, iconColor: const Color(0xFF58A6FF), title: user?.location ?? 'Location'),
                        _MenuTile(icon: Icons.badge_rounded, iconColor: const Color(0xFF58A6FF), title: user?.district ?? 'District'),
                        const Divider(thickness: 1, color: Color(0xFF9EC5FF)),
                        _MenuTile(icon: Icons.history_rounded, iconColor: const Color(0xFF58A6FF), title: 'Clear History'),
                        _MenuTile(
                          icon: Icons.remove_circle_rounded,
                          iconColor: Colors.red,
                          title: context.tr('Logout'),
                          onTap: () async {
                            final confirm = await showDialog<bool>(
                              context: context,
                              builder: (ctx) => AlertDialog(
                                title: Text(context.tr('Logout')),
                                content: Text(context.tr('Are you sure you want to sign out?')),
                                actions: [
                                  TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text(context.tr('Cancel'))),
                                  TextButton(
                                    onPressed: () => Navigator.pop(ctx, true),
                                    child: Text(context.tr('Logout'), style: const TextStyle(color: AppColors.error)),
                                  ),
                                ],
                              ),
                            );
                            if (confirm == true) {
                              await ref.read(authProvider.notifier).logout();
                              if (context.mounted) context.go('/role');
                            }
                          },
                        ),
                      ],
                    ),
                  ),
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

class _ActionPill extends StatelessWidget {
  final String label;
  final VoidCallback onTap;
  const _ActionPill({required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.92),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Center(
          child: Text(
            label,
            style: const TextStyle(color: Color(0xFF4A8EDB), fontWeight: FontWeight.w700),
          ),
        ),
      ),
    );
  }
}

class _MenuTile extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final String title;
  final VoidCallback? onTap;
  const _MenuTile({required this.icon, required this.iconColor, required this.title, this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 10),
        child: Row(
          children: [
            Icon(icon, color: iconColor, size: 20),
            const SizedBox(width: 16),
            Expanded(
              child: Text(
                title,
                style: const TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.w700),
              ),
            ),
            const Icon(Icons.chevron_right_rounded, color: Color(0xFF5B9CF3)),
          ],
        ),
      ),
    );
  }
}
