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

final appRouterProvider = Provider<GoRouter>((ref) {
  final authService = ref.watch(authServiceProvider);

  return GoRouter(
    initialLocation: '/login',
    refreshListenable: authService,
    redirect: (context, state) {
      final status = authService.state.status;
      final isLoggedIn = status == AuthStatus.authenticated;
      final isLoggingIn = state.matchedLocation == '/login';
      final isSigningUp = state.matchedLocation == '/signup';
      final isAuthRoute = isLoggingIn || isSigningUp;

      if (status == AuthStatus.loading) {
        return null;
      }

      if (!isLoggedIn) {
        return isAuthRoute ? null : '/login';
      }

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
});
