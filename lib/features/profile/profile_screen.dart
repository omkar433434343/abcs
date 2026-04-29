import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:convert';
import 'dart:io';
import '../../core/auth/auth_provider.dart';
import '../../core/theme/app_theme.dart';

class ProfileScreen extends ConsumerStatefulWidget {
  const ProfileScreen({super.key});

  @override
  ConsumerState<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends ConsumerState<ProfileScreen> {
  final _nameCtrl = TextEditingController();
  final _locationCtrl = TextEditingController();
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    final user = ref.read(authProvider).user;
    _nameCtrl.text = user?.fullName ?? '';
    _locationCtrl.text = user?.location ?? '';
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _locationCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickAvatar() async {
    final picker = ImagePicker();
    final file = await picker.pickImage(source: ImageSource.gallery, imageQuality: 60);
    if (file == null) return;
    final bytes = await File(file.path).readAsBytes();
    final b64 = base64Encode(bytes);
    await ref.read(authProvider.notifier).updateProfile({'avatar_b64': b64});
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Avatar updated'), backgroundColor: AppColors.success),
      );
    }
  }

  Future<void> _save() async {
    setState(() => _saving = true);
    await ref.read(authProvider.notifier).updateProfile({
      'full_name': _nameCtrl.text.trim(),
      'location': _locationCtrl.text.trim(),
    });
    setState(() => _saving = false);
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('✅ Profile saved'), backgroundColor: AppColors.success),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(authProvider).user;
    final isAsha = user?.role == 'asha';
    final gradient = isAsha ? AppTheme.ashaGradient : AppTheme.thoGradient;

    return Scaffold(
      appBar: AppBar(
        title: const Text('My Profile'),
        actions: [
          TextButton(
            onPressed: () async {
              await ref.read(authProvider.notifier).logout();
              if (mounted) context.go('/role');
            },
            child: const Text('Logout', style: TextStyle(color: AppColors.error)),
          ),
        ],
      ),
      body: Container(
        decoration: BoxDecoration(gradient: AppTheme.backgroundGradient),
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            // Avatar
            Center(
              child: Stack(
                alignment: Alignment.bottomRight,
                children: [
                  GestureDetector(
                    onTap: _pickAvatar,
                    child: CircleAvatar(
                      radius: 50,
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
                                  fontSize: 36,
                                  fontWeight: FontWeight.w700,
                                  color: gradient.colors.first),
                            )
                          : null,
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      gradient: gradient,
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.camera_alt_rounded,
                        color: Colors.white, size: 16),
                  ),
                ],
              ),
            ).animate().scale(duration: 500.ms, curve: Curves.elasticOut),

            const SizedBox(height: 8),

            Center(
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                decoration: BoxDecoration(
                  gradient: gradient,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  (user?.role ?? '').toUpperCase(),
                  style: const TextStyle(
                      color: Colors.white, fontWeight: FontWeight.w700, fontSize: 12),
                ),
              ),
            ),

            const SizedBox(height: 30),

            // Info fields
            _InfoCard(children: [
              TextFormField(
                controller: _nameCtrl,
                decoration: const InputDecoration(
                  labelText: 'Full Name',
                  prefixIcon: Icon(Icons.person_outline_rounded, color: AppColors.textSecondary),
                ),
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _locationCtrl,
                decoration: const InputDecoration(
                  labelText: 'Location / Village',
                  prefixIcon: Icon(Icons.place_outlined, color: AppColors.textSecondary),
                ),
              ),
            ]),

            const SizedBox(height: 16),

            _InfoCard(children: [
              _ReadOnlyField('Employee ID', user?.employeeId ?? '—'),
              const SizedBox(height: 12),
              _ReadOnlyField('District', user?.district ?? '—'),
            ]),

            const SizedBox(height: 24),

            Container(
              decoration: BoxDecoration(
                gradient: gradient,
                borderRadius: BorderRadius.circular(12),
                boxShadow: [
                  BoxShadow(
                    color: gradient.colors.first.withOpacity(0.3),
                    blurRadius: 16,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: ElevatedButton(
                onPressed: _saving ? null : _save,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.transparent,
                  shadowColor: Colors.transparent,
                ),
                child: _saving
                    ? const CircularProgressIndicator(color: Colors.white)
                    : const Text('Save Changes',
                        style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700)),
              ),
            ),
          ],
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
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.cardBorder),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: children),
    );
  }
}

class _ReadOnlyField extends StatelessWidget {
  final String label, value;
  const _ReadOnlyField(this.label, this.value);

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label,
            style: const TextStyle(
                color: AppColors.textMuted, fontSize: 11, letterSpacing: 0.8)),
        const SizedBox(height: 4),
        Text(value,
            style: const TextStyle(color: AppColors.textSecondary, fontSize: 14)),
      ],
    );
  }
}
