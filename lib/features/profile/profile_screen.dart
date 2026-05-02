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
      appBar: AppBar(
        title: Text(context.tr('My Profile')),
        actions: const [LanguageSelector()],
      ),
      body: Container(
        decoration: BoxDecoration(gradient: AppTheme.backgroundGradient),
        child: ListView(
          padding: const EdgeInsets.all(24),
          children: [
            // Avatar (Display only)
            Center(
              child: Hero(
                tag: 'profile_avatar',
                child: CircleAvatar(
                  radius: 54,
                  backgroundColor: gradient.colors.first.withOpacity(0.2),
                  backgroundImage: user?.avatarB64 != null
                      ? MemoryImage(base64Decode(user!.avatarB64!))
                      : null,
                  child: user?.avatarB64 == null
                      ? Text(
                          (user?.fullName ?? user?.employeeId ?? '?')
                              .substring(0, 1)
                              .toUpperCase(),
                          style: TextStyle(
                              fontSize: 40,
                              fontWeight: FontWeight.w700,
                              color: gradient.colors.first),
                        )
                      : null,
                ),
              ),
            ).animate().scale(duration: 500.ms, curve: Curves.elasticOut),

            const SizedBox(height: 12),

            Center(
              child: Column(
                children: [
                  Text(
                    user?.fullName ?? 'No Name Set',
                    style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                          fontWeight: FontWeight.w800,
                          color: AppColors.textPrimary,
                        ),
                  ),
                  const SizedBox(height: 4),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                    decoration: BoxDecoration(
                      gradient: gradient,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      (user?.role ?? '').toUpperCase(),
                      style: const TextStyle(
                          color: Colors.white, fontWeight: FontWeight.w700, fontSize: 11),
                    ),
                  ),
                ],
              ),
            ).animate().fade(delay: 200.ms),

            const SizedBox(height: 40),

            // Profile Information Section
            _SectionLabel(label: 'Personal Information'),
            _InfoCard(children: [
              _ReadOnlyField(
                label: 'FULL NAME',
                value: user?.fullName ?? '—',
                icon: Icons.person_rounded,
              ),
              const Divider(height: 32),
              _ReadOnlyField(
                label: 'LOCATION / VILLAGE',
                value: user?.location ?? '—',
                icon: Icons.place_rounded,
              ),
            ]),

            const SizedBox(height: 24),

            _SectionLabel(label: 'Administrative Details'),
            _InfoCard(children: [
              _ReadOnlyField(
                label: 'EMPLOYEE ID',
                value: user?.employeeId ?? '—',
                icon: Icons.badge_rounded,
              ),
              const Divider(height: 32),
              _ReadOnlyField(
                label: 'DISTRICT',
                value: user?.district ?? '—',
                icon: Icons.map_rounded,
              ),
            ]),

            const SizedBox(height: 48),

            // Logout Button
            ElevatedButton(
              onPressed: () async {
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
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.error.withOpacity(0.1),
                foregroundColor: AppColors.error,
                side: const BorderSide(color: AppColors.error, width: 1.5),
                elevation: 0,
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.logout_rounded),
                  const SizedBox(width: 12),
                  Text(context.tr('Logout from Account')),
                ],
              ),
            ).animate().fade(delay: 400.ms),

            const SizedBox(height: 20),
            const Center(
              child: Text(
                'Profile details are managed by THO administration.',
                style: TextStyle(color: AppColors.textMuted, fontSize: 12),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SectionLabel extends StatelessWidget {
  final String label;
  const _SectionLabel({required this.label});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(left: 4, bottom: 8),
      child: Text(
        label.toUpperCase(),
        style: const TextStyle(
          color: AppColors.textMuted,
          fontSize: 11,
          fontWeight: FontWeight.w700,
          letterSpacing: 1.2,
        ),
      ),
    );
  }
}

class _InfoCard extends StatelessWidget {
  final List<Widget> children;
  const _InfoCard({required this.children});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.cardBorder),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.02),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: children),
    );
  }
}

class _ReadOnlyField extends StatelessWidget {
  final String label, value;
  final IconData icon;
  const _ReadOnlyField({required this.label, required this.value, required this.icon});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: AppColors.background,
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(icon, color: AppColors.primary, size: 20),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label,
                  style: const TextStyle(
                      color: AppColors.textMuted, fontSize: 10, fontWeight: FontWeight.w700, letterSpacing: 0.5)),
              const SizedBox(height: 4),
              Text(value,
                  style: const TextStyle(
                      color: AppColors.textPrimary, fontSize: 15, fontWeight: FontWeight.w600)),
            ],
          ),
        ),
      ],
    );
  }
}
