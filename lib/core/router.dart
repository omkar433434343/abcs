import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../core/auth/auth_provider.dart';
import '../features/splash/splash_screen.dart';
import '../features/auth/role_select_screen.dart';
import '../features/auth/login_screen.dart';
import '../features/asha/dashboard/asha_dashboard.dart';
import '../features/asha/patients/patient_list_screen.dart';
import '../features/asha/patients/patient_form_screen.dart';
import '../features/asha/triage/triage_form_screen.dart';
import '../features/asha/triage/voice_triage_screen.dart';
import '../features/asha/triage/my_records_screen.dart';
import '../features/tho/dashboard/tho_dashboard.dart';
import '../features/tho/triage_review/triage_review_screen.dart';
import '../features/tho/asha_network/asha_network_screen.dart';
import '../features/tho/outbreaks/outbreak_map_screen.dart';
import '../features/profile/profile_screen.dart';
import '../features/asha/asha_shell.dart';
import '../features/tho/tho_shell.dart';

final routerProvider = Provider<GoRouter>((ref) {
  final auth = ref.watch(authProvider);

  return GoRouter(
    initialLocation: '/splash',
    redirect: (context, state) {
      final loggedIn = auth.isLoggedIn;
      final onAuth = state.matchedLocation.startsWith('/login') ||
          state.matchedLocation == '/role' ||
          state.matchedLocation == '/splash';

      if (!loggedIn && !onAuth) return '/role';
      if (loggedIn && (state.matchedLocation == '/role' ||
          state.matchedLocation.startsWith('/login'))) {
        final role = auth.user?.role ?? 'asha';
        return role == 'tho' ? '/tho' : '/asha';
      }
      return null;
    },
    routes: [
      GoRoute(path: '/splash', builder: (_, __) => const SplashScreen()),
      GoRoute(path: '/role', builder: (_, __) => const RoleSelectScreen()),
      GoRoute(
        path: '/login/:role',
        builder: (_, state) => LoginScreen(role: state.pathParameters['role']!),
      ),

      // ASHA Shell Route
      StatefulShellRoute.indexedStack(
        builder: (context, state, navigationShell) => AshaShell(navigationShell: navigationShell),
        branches: [
          StatefulShellBranch(
            routes: [
              GoRoute(path: '/asha', builder: (_, __) => const AshaDashboard()),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(path: '/asha/patients', builder: (_, __) => const PatientListScreen()),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/asha/triage',
                builder: (_, state) => TriageFormScreen(
                  autoVoice: state.uri.queryParameters['autoVoice'] == 'true',
                ),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(path: '/asha/records', builder: (_, __) => const MyRecordsScreen()),
            ],
          ),
        ],
      ),

      // Other ASHA routes (pushed on top)
      GoRoute(path: '/asha/patients/new', builder: (_, __) => const PatientFormScreen()),
      GoRoute(
        path: '/asha/triage/voice',
        builder: (_, __) => const VoiceTriageScreen(),
      ),
      GoRoute(path: '/asha/profile', builder: (_, __) => const ProfileScreen()),

      // THO Shell Route
      StatefulShellRoute.indexedStack(
        builder: (context, state, navigationShell) => ThoShell(navigationShell: navigationShell),
        branches: [
          StatefulShellBranch(
            routes: [
              GoRoute(path: '/tho', builder: (_, __) => const ThoDashboard()),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/tho/triage-review',
                builder: (_, __) => const TriageReviewScreen(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/tho/asha-network',
                builder: (_, __) => const AshaNetworkScreen(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/tho/outbreaks',
                builder: (_, __) => const OutbreakMapScreen(),
              ),
            ],
          ),
        ],
      ),

      // Other THO routes
      GoRoute(path: '/tho/profile', builder: (_, __) => const ProfileScreen()),
    ],
  );
});
