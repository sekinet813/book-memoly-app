import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

import '../../features/action_plans/action_plans_feature.dart';
import '../../features/auth/login_page.dart';
import '../../features/auth/signup_page.dart';
import '../../features/books/books_feature.dart';
import '../../features/home/home_feature.dart';
import '../../features/goals/goals_feature.dart';
import '../../features/memos/memos_feature.dart';
import '../../features/reading_speed/reading_speed_feature.dart';
import '../../features/statistics/statistics_feature.dart';
import '../../features/search/search_feature.dart';
import '../../features/profile/profile_feature.dart';
import '../../features/settings/settings_feature.dart';
import '../../features/reading_history/reading_history_feature.dart';
import '../providers/auth_providers.dart';
import '../services/auth_service.dart';

/// アニメーションなしのページを作成
Page<dynamic> _buildNoTransitionPage({
  required Widget child,
  required GoRouterState state,
}) {
  return CustomTransitionPage<void>(
    key: state.pageKey,
    child: child,
    transitionDuration: Duration.zero,
    transitionsBuilder: (context, animation, secondaryAnimation, child) {
      return child;
    },
  );
}

final appRouterProvider = StateProvider<GoRouter>((ref) {
  // Read authService once, don't watch it to prevent router recreation
  final authService = ref.read(authServiceProvider);
  final guestAuth = ref.read(guestAuthServiceProvider);

  // Create a dummy ChangeNotifier if authService is null
  final refreshListenable = Listenable.merge([
    if (authService != null) authService,
    guestAuth,
  ]);

  // Create router once and store it
  final router = GoRouter(
    initialLocation: '/login',
    refreshListenable: refreshListenable,
    redirect: (context, state) {
      // Skip authentication in debug mode except on Android devices
      final isAndroidDevice = defaultTargetPlatform == TargetPlatform.android;
      if (kDebugMode && !isAndroidDevice) {
        // If on auth route in debug mode, redirect to home
        final isLoggingIn = state.matchedLocation == '/login';
        final isSigningUp = state.matchedLocation == '/signup';
        if (isLoggingIn || isSigningUp) {
          return '/';
        }
        return null;
      }

      final status = ref.read(authStatusProvider);
      final isLoggedIn = status == AuthStatus.authenticated;
      final isGuest = status == AuthStatus.guest;
      final isLoggingIn = state.matchedLocation == '/login';
      final isSigningUp = state.matchedLocation == '/signup';
      final isAuthRoute = isLoggingIn || isSigningUp;

      // Allow access to auth routes (login/signup) when not logged in
      if (status == AuthStatus.loading) {
        return null;
      }

      if (!isLoggedIn && !isGuest) {
        // Allow access to login and signup pages - don't redirect if already on auth route
        if (isAuthRoute) {
          return null;
        }
        // Only redirect to login if not already on login or signup
        return '/login';
      }

      // If logged in and on auth route, redirect to home
      // Guest users should be allowed to access login/signup to upgrade their account
      if (isLoggedIn && isAuthRoute) {
        return '/';
      }

      return null;
    },
    routes: [
      GoRoute(
        path: '/login',
        builder: (context, state) => const LoginPage(),
      ),
      GoRoute(
        path: '/signup',
        builder: (context, state) => const SignUpPage(),
      ),
      GoRoute(
        path: '/',
        pageBuilder: (context, state) => _buildNoTransitionPage(
          child: const HomePage(),
          state: state,
        ),
      ),
      GoRoute(
        path: '/bookshelf',
        pageBuilder: (context, state) => _buildNoTransitionPage(
          child: const BookshelfPage(),
          state: state,
        ),
      ),
      GoRoute(
        path: '/search',
        pageBuilder: (context, state) => _buildNoTransitionPage(
          child: const SearchPage(),
          state: state,
        ),
      ),
      GoRoute(
        path: '/memos',
        pageBuilder: (context, state) => _buildNoTransitionPage(
          child: const MemosPage(),
          state: state,
        ),
      ),
      GoRoute(
        path: '/actions',
        pageBuilder: (context, state) {
          final bookId =
              int.tryParse(state.uri.queryParameters['bookId'] ?? '');
          return _buildNoTransitionPage(
            child: ActionPlansPage(initialBookId: bookId),
            state: state,
          );
        },
      ),
      GoRoute(
        path: '/reading-speed',
        builder: (context, state) {
          final bookId =
              int.tryParse(state.uri.queryParameters['bookId'] ?? '');
          return ReadingSpeedPage(initialBookId: bookId);
        },
      ),
      GoRoute(
        path: '/statistics',
        pageBuilder: (context, state) => _buildNoTransitionPage(
          child: const StatisticsPage(),
          state: state,
        ),
      ),
      GoRoute(
        path: '/goals',
        pageBuilder: (context, state) => _buildNoTransitionPage(
          child: const GoalsPage(),
          state: state,
        ),
      ),
      GoRoute(
        path: '/timeline',
        pageBuilder: (context, state) => _buildNoTransitionPage(
          child: const ReadingTimelinePage(),
          state: state,
        ),
      ),
      GoRoute(
        path: '/profile',
        pageBuilder: (context, state) => _buildNoTransitionPage(
          child: const ProfilePage(),
          state: state,
        ),
      ),
      GoRoute(
        path: '/settings',
        pageBuilder: (context, state) => _buildNoTransitionPage(
          child: const SettingsPage(),
          state: state,
        ),
      ),
    ],
  );

  return router;
});
