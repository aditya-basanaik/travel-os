import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:travel_os/features/auth/presentation/login_screen.dart';
import 'package:travel_os/features/auth/presentation/register_screen.dart';
import 'package:travel_os/features/auth/presentation/forgot_password_screen.dart';
import 'package:travel_os/features/auth/presentation/reset_password_screen.dart';
import 'package:travel_os/features/home/presentation/home_screen.dart';
import 'package:travel_os/features/trips/presentation/trips_screen.dart';
import 'package:travel_os/features/trips/presentation/trip_detail_screen.dart';
import 'package:travel_os/features/trips/presentation/shared_trip_screen.dart';
import 'package:travel_os/features/ai_planner/presentation/ai_planner_screen.dart';
import 'package:travel_os/features/expenses/presentation/expenses_screen.dart';
import 'package:travel_os/features/profile/presentation/profile_screen.dart';
import 'package:travel_os/features/help/presentation/help_screen.dart';
import 'package:travel_os/shared/widgets/glass_bottom_nav.dart';
import 'package:travel_os/features/auth/data/auth_repository.dart';

final appRouterPrv = Provider<GoRouter>((ref) {
  final authState = ref.watch(authRepositoryPrv);

  return GoRouter(
    initialLocation: '/',
    refreshListenable: authState,
    redirect: (context, state) {
      final isLoggedIn = authState.isAuthenticated;
      final isPublicRoute = state.matchedLocation == '/login' ||
          state.matchedLocation == '/register' ||
          state.matchedLocation == '/forgot-password' ||
          state.matchedLocation == '/reset-password' ||
          state.matchedLocation.startsWith('/shared/');

      if (!isLoggedIn && !isPublicRoute) {
        return '/login';
      }
      if (isLoggedIn && isPublicRoute) {
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
      GoRoute(
        path: '/reset-password',
        builder: (context, state) => ResetPasswordScreen(
          token: state.uri.queryParameters['token'] ?? '',
        ),
      ),
      GoRoute(
        path: '/shared/:token',
        builder: (context, state) {
          final token = state.pathParameters['token'] ?? '';
          return SharedTripScreen(token: token);
        },
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
          GoRoute(
            path: '/help',
            builder: (context, state) => const HelpScreen(),
          ),
        ],
      ),
    ],
  );
});
