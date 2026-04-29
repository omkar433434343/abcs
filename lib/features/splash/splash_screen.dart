import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:go_router/go_router.dart';
import '../../core/api/api_client.dart';
import '../../core/theme/app_theme.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  @override
  void initState() {
    super.initState();
    _navigate();
  }

  Future<void> _navigate() async {
    await Future.delayed(const Duration(milliseconds: 2000));
    if (!mounted) return;
    final hasToken = await ApiClient.hasToken();
    if (!mounted) return;
    if (hasToken) {
      final role = await ApiClient.getRole();
      context.go(role == 'tho' ? '/tho' : '/asha');
    } else {
      context.go('/role');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: BoxDecoration(gradient: AppTheme.backgroundGradient),
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // Logo circle
              Container(
                width: 100,
                height: 100,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: AppTheme.ashaGradient,
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.primary.withOpacity(0.4),
                      blurRadius: 40,
                      spreadRadius: 8,
                    ),
                  ],
                ),
                child: const Icon(Icons.favorite_rounded, color: Colors.white, size: 52),
              )
                  .animate()
                  .scale(duration: 600.ms, curve: Curves.elasticOut)
                  .fade(duration: 400.ms),

              const SizedBox(height: 28),

              Text(
                'Swasthya Setu',
                style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                  fontWeight: FontWeight.w800,
                  color: AppColors.textPrimary,
                  letterSpacing: -0.5,
                ),
              ).animate().fade(delay: 300.ms, duration: 500.ms).slideY(begin: 0.2),

              const SizedBox(height: 8),

              Text(
                'Rural Health Companion',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: AppColors.textSecondary,
                ),
              ).animate().fade(delay: 500.ms, duration: 500.ms),

              const SizedBox(height: 60),

              SizedBox(
                width: 40,
                height: 40,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: AppColors.primary.withOpacity(0.6),
                ),
              ).animate().fade(delay: 800.ms),
            ],
          ),
        ),
      ),
    );
  }
}
