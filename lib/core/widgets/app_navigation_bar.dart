import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../shared/constants/app_icons.dart';

enum AppDestination { home, search, memos, actions, profile }

class AppNavigationBar extends StatelessWidget {
  const AppNavigationBar({
    super.key,
    required this.current,
  });

  final AppDestination current;

  @override
  Widget build(BuildContext context) {
    return NavigationBar(
      selectedIndex: current.index,
      destinations: const [
        NavigationDestination(
          icon: Icon(AppIcons.home),
          selectedIcon: Icon(AppIcons.homeFilled),
          label: 'ホーム',
        ),
        NavigationDestination(
          icon: Icon(AppIcons.search),
          selectedIcon: Icon(AppIcons.search),
          label: '検索',
        ),
        NavigationDestination(
          icon: Icon(AppIcons.memo),
          selectedIcon: Icon(AppIcons.memo),
          label: 'メモ',
        ),
        NavigationDestination(
          icon: Icon(AppIcons.actions),
          selectedIcon: Icon(AppIcons.actions),
          label: 'アクション',
        ),
        NavigationDestination(
          icon: Icon(AppIcons.person),
          selectedIcon: Icon(AppIcons.person),
          label: 'プロフィール',
        ),
      ],
      onDestinationSelected: (index) {
        final destination = AppDestination.values[index];
        switch (destination) {
          case AppDestination.home:
            context.go('/');
            break;
          case AppDestination.search:
            context.go('/search');
            break;
          case AppDestination.memos:
            context.go('/memos');
            break;
          case AppDestination.actions:
            context.go('/actions');
            break;
          case AppDestination.profile:
            context.go('/profile');
            break;
        }
      },
    );
  }
}
