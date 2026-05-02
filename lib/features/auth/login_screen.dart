import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:go_router/go_router.dart';
import '../../core/auth/auth_provider.dart';
import '../../core/i18n/app_localizations.dart';
import '../../core/theme/app_theme.dart';
import '../../shared/widgets/language_selector.dart';

class LoginScreen extends ConsumerStatefulWidget {
  final String role;
  const LoginScreen({super.key, required this.role});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _idCtrl = TextEditingController();
  final _pwCtrl = TextEditingController();
  bool _obscure = true;

  bool get isAsha => widget.role == 'asha';

  @override
  void dispose() {
    _idCtrl.dispose();
    _pwCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    final ok = await ref
        .read(authProvider.notifier)
        .login(_idCtrl.text.trim(), _pwCtrl.text.trim(), widget.role);
    if (ok && mounted) {
      context.go(isAsha ? '/asha' : '/tho');
    }
  }

  @override
  Widget build(BuildContext context) {
    final auth = ref.watch(authProvider);
    final gradient = isAsha ? AppTheme.ashaGradient : AppTheme.thoGradient;
    final label = isAsha ? 'ASHA Worker' : 'THO Officer';

    return Scaffold(
      body: Container(
        decoration: BoxDecoration(gradient: AppTheme.backgroundGradient),
        child: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: 20),
                  const Align(
                    alignment: Alignment.centerRight,
                    child: LanguageSelector(),
                  ),

                  // Back button
                  GestureDetector(
                    onTap: () => context.go('/role'),
                    child: Row(
                      children: [
                        const Icon(Icons.arrow_back_ios_new_rounded,
                            size: 18, color: AppColors.textSecondary),
                        const SizedBox(width: 6),
                        Text(context.tr('Back'),
                            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                              color: AppColors.textSecondary,
                            )),
                      ],
                    ),
                  ),

                  const SizedBox(height: 40),

                  // Header gradient badge
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    decoration: BoxDecoration(
                      gradient: gradient,
                      borderRadius: BorderRadius.circular(30),
                    ),
                    child: Text(
                      label,
                      style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
                    ),
                  ).animate().fade(duration: 400.ms).slideX(begin: -0.2),

                  const SizedBox(height: 16),

                  Text(
                    context.tr('Sign In'),
                    style: Theme.of(context).textTheme.displaySmall?.copyWith(
                      fontWeight: FontWeight.w800,
                      color: AppColors.textPrimary,
                    ),
                  ).animate().fade(delay: 100.ms, duration: 400.ms),

                  const SizedBox(height: 8),

                  Text(
                    context.tr('Enter your Employee ID and password'),
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: AppColors.textSecondary,
                    ),
                  ).animate().fade(delay: 200.ms, duration: 400.ms),

                  const SizedBox(height: 40),

                  // Employee ID field
                  TextFormField(
                    controller: _idCtrl,
                    decoration: InputDecoration(
                      labelText: context.tr('Employee ID'),
                      prefixIcon: const Icon(Icons.badge_outlined, color: AppColors.textSecondary),
                    ),
                    textInputAction: TextInputAction.next,
                    validator: (v) =>
                        (v == null || v.trim().isEmpty) ? context.tr('Employee ID is required') : null,
                  ).animate().fade(delay: 300.ms, duration: 400.ms).slideY(begin: 0.2),

                  const SizedBox(height: 16),

                  // Password field
                  TextFormField(
                    controller: _pwCtrl,
                    obscureText: _obscure,
                    decoration: InputDecoration(
                      labelText: context.tr('Password'),
                      prefixIcon: const Icon(Icons.lock_outline_rounded,
                          color: AppColors.textSecondary),
                      suffixIcon: IconButton(
                        icon: Icon(
                          _obscure ? Icons.visibility_off_outlined : Icons.visibility_outlined,
                          color: AppColors.textSecondary,
                        ),
                        onPressed: () => setState(() => _obscure = !_obscure),
                      ),
                    ),
                    textInputAction: TextInputAction.done,
                    onFieldSubmitted: (_) => _submit(),
                    validator: (v) =>
                        (v == null || v.isEmpty) ? context.tr('Password is required') : null,
                  ).animate().fade(delay: 400.ms, duration: 400.ms).slideY(begin: 0.2),

                  // Error message
                  if (auth.error != null) ...[
                    const SizedBox(height: 16),
                    Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: AppColors.error.withOpacity(0.12),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: AppColors.error.withOpacity(0.3)),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.error_outline_rounded,
                              color: AppColors.error, size: 18),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              auth.error!,
                              style: TextStyle(color: AppColors.error, fontSize: 13),
                            ),
                          ),
                        ],
                      ),
                    ).animate().shake(),
                  ],

                  const SizedBox(height: 32),

                  // Sign In button
                  auth.isLoading
                      ? Center(
                          child: CircularProgressIndicator(color: gradient.colors.first),
                        )
                      : Container(
                          decoration: BoxDecoration(
                            gradient: gradient,
                            borderRadius: BorderRadius.circular(12),
                            boxShadow: [
                              BoxShadow(
                                color: gradient.colors.first.withOpacity(0.4),
                                blurRadius: 20,
                                offset: const Offset(0, 6),
                              ),
                            ],
                          ),
                          child: ElevatedButton(
                            onPressed: _submit,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.transparent,
                              shadowColor: Colors.transparent,
                              minimumSize: const Size(double.infinity, 52),
                            ),
                            child: Text(
                              context.tr('Sign In'),
                              style: TextStyle(
                                  fontSize: 16, fontWeight: FontWeight.w700, color: Colors.white),
                            ),
                          ),
                        ),

                  const SizedBox(height: 40),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
