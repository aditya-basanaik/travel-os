import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:travel_os/features/auth/presentation/login_screen.dart';
import 'package:travel_os/features/auth/presentation/register_screen.dart';
import 'package:travel_os/features/auth/presentation/forgot_password_screen.dart';
import 'package:travel_os/features/home/presentation/home_screen.dart';
import 'package:travel_os/features/trips/presentation/trips_screen.dart';
import 'package:travel_os/features/trips/presentation/trip_detail_screen.dart';
import 'package:travel_os/features/ai_planner/presentation/ai_planner_screen.dart';
import 'package:travel_os/features/expenses/presentation/expenses_screen.dart';
import 'package:travel_os/features/profile/presentation/profile_screen.dart';
import 'package:travel_os/shared/widgets/glass_bottom_nav.dart';
import 'package:travel_os/features/auth/data/auth_repository.dart';

final appRouterPrv = Provider<GoRouter>((ref) {
  final authState = ref.watch(authRepositoryPrv);

  return GoRouter(
    initialLocation: '/',
    refreshListenable: authState,
    redirect: (context, state) {
      final isLoggedIn = authState.isAuthenticated;
      final isLoggingIn = state.matchedLocation == '/login' ||
          state.matchedLocation == '/register' ||
          state.matchedLocation == '/forgot-password';

      if (!isLoggedIn && !isLoggingIn) {
        return '/login';
      }
      if (isLoggedIn && isLoggingIn) {
        return '/';
      }
      return null;
    },
    routes: [
      GoRoute(
        path: '/login',
        builder: (context, state) => const LoginScreen(),
      ),
      GoRoute(
        path: '/register',
        builder: (context, state) => const RegisterScreen(),
      ),
      GoRoute(
        path: '/forgot-password',
        builder: (context, state) => const ForgotPasswordScreen(),
      ),
      
      // Bottom Nav Shell Routes
      ShellRoute(
        builder: (context, state, child) {
          return MainNavigationShell(child: child);
        },
        routes: [
          GoRoute(
            path: '/',
            builder: (context, state) => const HomeScreen(),
          ),
          GoRoute(
            path: '/trips',
            builder: (context, state) => const TripsScreen(),
            routes: [
              GoRoute(
                path: ':id',
                builder: (context, state) {
                  final tripId = state.pathParameters['id'] ?? '';
                  return TripDetailScreen(tripId: tripId);
                },
              ),
            ],
          ),
          GoRoute(
            path: '/plan',
            builder: (context, state) => const AIPlannerScreen(),
          ),
          GoRoute(
            path: '/expenses',
            builder: (context, state) => const ExpensesScreen(),
          ),
          GoRoute(
            path: '/profile',
            builder: (context, state) => const ProfileScreen(),
          ),
        ],
      ),
    ],
  );
});
