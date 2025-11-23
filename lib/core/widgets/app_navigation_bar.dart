import 'dart:ui';

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
    final colorScheme = Theme.of(context).colorScheme;

    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(24),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
            child: NavigationBar(
              height: 72,
              backgroundColor: colorScheme.surface.withOpacity(0.4),
              surfaceTintColor: Colors.transparent,
              elevation: 0,
              indicatorColor: colorScheme.primary.withOpacity(0.18),
              labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
              labelTextStyle: MaterialStatePropertyAll(
                TextStyle(
                  fontSize: 11,
                  letterSpacing: 0.1,
                  fontWeight: FontWeight.w600,
                  color: colorScheme.onSurfaceVariant,
                ),
              ),
              iconTheme: MaterialStateProperty.resolveWith(
                (states) => IconThemeData(
                  size: 24,
                  color: states.contains(MaterialState.selected)
                      ? colorScheme.primary
                      : colorScheme.onSurfaceVariant,
                ),
              ),
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
            ),
          ),
        ),
      ),
    );
  }
}
