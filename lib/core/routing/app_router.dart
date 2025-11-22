import 'package:go_router/go_router.dart';

import '../../features/home/home_feature.dart';
import '../../features/memos/memos_feature.dart';
import '../../features/search/search_feature.dart';

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
  ],
);

