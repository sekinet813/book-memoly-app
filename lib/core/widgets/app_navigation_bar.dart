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
              backgroundColor: colorScheme.surface.withValues(alpha: 0.4),
              surfaceTintColor: Colors.transparent,
              elevation: 0,
              indicatorColor: colorScheme.primary.withValues(alpha: 0.18),
              labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
              labelTextStyle: WidgetStatePropertyAll(
                TextStyle(
                  fontSize: 11,
                  letterSpacing: 0.1,
                  fontWeight: FontWeight.w600,
                  color: colorScheme.onSurfaceVariant,
                ),
              ),
              selectedIndex: current.index,
              destinations: [
                NavigationDestination(
                  icon: Icon(
                    AppIcons.home,
                    size: 24,
                    color: colorScheme.onSurfaceVariant,
                  ),
                  selectedIcon: Icon(
                    AppIcons.homeFilled,
                    size: 24,
                    color: colorScheme.primary,
                  ),
                  label: 'ホーム',
                ),
                NavigationDestination(
                  icon: Icon(
                    AppIcons.search,
                    size: 24,
                    color: colorScheme.onSurfaceVariant,
                  ),
                  selectedIcon: Icon(
                    AppIcons.search,
                    size: 24,
                    color: colorScheme.primary,
                  ),
                  label: '検索',
                ),
                NavigationDestination(
                  icon: Icon(
                    AppIcons.memo,
                    size: 24,
                    color: colorScheme.onSurfaceVariant,
                  ),
                  selectedIcon: Icon(
                    AppIcons.memo,
                    size: 24,
                    color: colorScheme.primary,
                  ),
                  label: 'メモ',
                ),
                NavigationDestination(
                  icon: Icon(
                    AppIcons.actions,
                    size: 24,
                    color: colorScheme.onSurfaceVariant,
                  ),
                  selectedIcon: Icon(
                    AppIcons.actions,
                    size: 24,
                    color: colorScheme.primary,
                  ),
                  label: 'アクション',
                ),
                NavigationDestination(
                  icon: Icon(
                    AppIcons.person,
                    size: 24,
                    color: colorScheme.onSurfaceVariant,
                  ),
                  selectedIcon: Icon(
                    AppIcons.person,
                    size: 24,
                    color: colorScheme.primary,
                  ),
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
