import 'package:flutter/foundation.dart';
import 'package:go_router/go_router.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

import '../../features/action_plans/action_plans_feature.dart';
import '../../features/auth/login_page.dart';
import '../../features/auth/signup_page.dart';
import '../../features/home/home_feature.dart';
import '../../features/memos/memos_feature.dart';
import '../../features/reading_speed/reading_speed_feature.dart';
import '../../features/search/search_feature.dart';
import '../providers/auth_providers.dart';
import '../services/auth_service.dart';

/// Dummy ChangeNotifier for when Supabase is not configured
class _DummyChangeNotifier extends ChangeNotifier {}

final appRouterProvider = StateProvider<GoRouter>((ref) {
  // Read authService once, don't watch it to prevent router recreation
  final authService = ref.read(authServiceProvider);
  
  // Create a dummy ChangeNotifier if authService is null
  final refreshListenable = authService ?? _DummyChangeNotifier();
  
  // Create router once and store it
  final router = GoRouter(
    initialLocation: '/login',
    refreshListenable: refreshListenable,
    redirect: (context, state) {
      // Skip authentication in debug mode
      if (kDebugMode) {
        // If on auth route in debug mode, redirect to home
        final isLoggingIn = state.matchedLocation == '/login';
        final isSigningUp = state.matchedLocation == '/signup';
        if (isLoggingIn || isSigningUp) {
          return '/';
        }
        return null;
      }

      // Read current authService state in redirect
      final currentAuthService = ref.read(authServiceProvider);
      
      // If Supabase is not configured, allow access to all routes
      if (currentAuthService == null) {
        return null;
      }

      final status = currentAuthService.state.status;
      final isLoggedIn = status == AuthStatus.authenticated;
      final isLoggingIn = state.matchedLocation == '/login';
      final isSigningUp = state.matchedLocation == '/signup';
      final isAuthRoute = isLoggingIn || isSigningUp;

      // Allow access to auth routes (login/signup) when not logged in
      if (status == AuthStatus.loading) {
        return null;
      }

      if (!isLoggedIn) {
        // Allow access to login and signup pages - don't redirect if already on auth route
        if (isAuthRoute) {
          return null;
        }
        // Only redirect to login if not already on login or signup
        return '/login';
      }

      // If logged in and on auth route, redirect to home
      if (isAuthRoute) {
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
        builder: (context, state) => const HomePage(),
      ),
      GoRoute(
        path: '/search',
        builder: (context, state) => const SearchPage(),
      ),
      GoRoute(
        path: '/memos',
        builder: (context, state) => const MemosPage(),
      ),
      GoRoute(
        path: '/actions',
        builder: (context, state) => const ActionPlansPage(),
      ),
      GoRoute(
        path: '/reading-speed',
        builder: (context, state) => const ReadingSpeedPage(),
      ),
    ],
  );

  return router;
});
