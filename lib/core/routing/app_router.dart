import 'package:flutter/widgets.dart';
import 'package:go_router/go_router.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

import '../../features/action_plans/action_plans_feature.dart';
import '../../features/auth/login_page.dart';
import '../../features/home/home_feature.dart';
import '../../features/memos/memos_feature.dart';
import '../../features/reading_speed/reading_speed_feature.dart';
import '../../features/search/search_feature.dart';
import '../providers/auth_providers.dart';

final appRouterProvider = Provider<GoRouter>((ref) {
  final authService = ref.watch(authServiceProvider);

  return GoRouter(
    initialLocation: '/login',
    refreshListenable: authService,
    redirect: (context, state) {
      final status = authService.state.status;
      final isLoggedIn = status == AuthStatus.authenticated;
      final isLoggingIn = state.matchedLocation == '/login';

      if (status == AuthStatus.loading) {
        return null;
      }

      if (!isLoggedIn) {
        return isLoggingIn ? null : '/login';
      }

      if (isLoggingIn) {
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
