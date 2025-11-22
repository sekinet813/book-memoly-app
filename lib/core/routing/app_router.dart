import 'package:go_router/go_router.dart';

import '../../features/home/home_feature.dart';
import '../../features/memos/memos_feature.dart';
import '../../features/search/search_feature.dart';
import '../../features/action_plans/action_plans_feature.dart';
import '../../features/reading_speed/reading_speed_feature.dart';

final appRouter = GoRouter(
  initialLocation: '/',
  routes: [
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

