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

    Widget buildNavIcon(
      IconData icon, {
      required bool selected,
      bool isCenter = false,
    }) {
      final defaultColor =
          selected ? colorScheme.primary : colorScheme.onSurfaceVariant;
      final iconSize = isCenter ? 44.0 : 28.0;

      if (!isCenter) {
        return Icon(
          icon,
          size: iconSize,
          color: defaultColor,
        );
      }

      final baseDecoration = BoxDecoration(
        shape: BoxShape.circle,
        color: colorScheme.primary,
      );

      Widget centralIcon;
      if (selected) {
        centralIcon = AnimatedContainer(
          duration: const Duration(milliseconds: 220),
          curve: Curves.easeOut,
          padding: const EdgeInsets.fromLTRB(16, 22, 16, 12),
          decoration: baseDecoration.copyWith(
            boxShadow: const [],
          ),
          child: Icon(
            icon,
            size: iconSize,
            color: colorScheme.onPrimary,
          ),
        );
      } else {
        centralIcon = AnimatedContainer(
          duration: const Duration(milliseconds: 220),
          curve: Curves.easeOut,
          padding: const EdgeInsets.fromLTRB(14, 20, 14, 10),
          decoration: baseDecoration.copyWith(
            color: colorScheme.primary.withValues(alpha: 0.9),
            boxShadow: [
              BoxShadow(
                color: colorScheme.primary.withValues(alpha: 0.25),
                blurRadius: 12,
                offset: const Offset(0, 4),
                spreadRadius: 2,
              ),
            ],
          ),
          child: Icon(
            icon,
            size: iconSize,
            color: colorScheme.onPrimary,
          ),
        );
      }

      return Transform.translate(
        offset: const Offset(0, -18),
        child: centralIcon,
      );
    }

    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        child: Align(
          heightFactor: 1,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 420),
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: colorScheme.surface,
                borderRadius: BorderRadius.circular(28),
                border: Border.all(
                  color: colorScheme.outlineVariant.withValues(alpha: 0.35),
                ),
                boxShadow: [
                  BoxShadow(
                    color: colorScheme.shadow.withValues(alpha: 0.08),
                    blurRadius: 20,
                    offset: const Offset(0, 8),
                  ),
                ],
              ),
              child: SizedBox(
                height: 80,
                child: NavigationBar(
                  height: 70,
                  backgroundColor: Colors.transparent,
                  surfaceTintColor: Colors.transparent,
                  elevation: 0,
                  indicatorColor: colorScheme.primary.withValues(alpha: 0.18),
                  labelBehavior: NavigationDestinationLabelBehavior.alwaysHide,
                  selectedIndex: current.index,
                  destinations: [
                    NavigationDestination(
                      icon: buildNavIcon(
                        AppIcons.home,
                        selected: false,
                      ),
                      selectedIcon: buildNavIcon(
                        AppIcons.homeFilled,
                        selected: true,
                      ),
                      label: '',
                    ),
                    NavigationDestination(
                      icon: buildNavIcon(
                        AppIcons.search,
                        selected: false,
                      ),
                      selectedIcon: buildNavIcon(
                        AppIcons.search,
                        selected: true,
                      ),
                      label: '',
                    ),
                    NavigationDestination(
                      icon: buildNavIcon(
                        AppIcons.memo,
                        selected: false,
                        isCenter: true,
                      ),
                      selectedIcon: buildNavIcon(
                        AppIcons.memo,
                        selected: true,
                        isCenter: true,
                      ),
                      label: '',
                    ),
                    NavigationDestination(
                      icon: buildNavIcon(
                        AppIcons.actions,
                        selected: false,
                      ),
                      selectedIcon: buildNavIcon(
                        AppIcons.actions,
                        selected: true,
                      ),
                      label: '',
                    ),
                    NavigationDestination(
                      icon: buildNavIcon(
                        AppIcons.person,
                        selected: false,
                      ),
                      selectedIcon: buildNavIcon(
                        AppIcons.person,
                        selected: true,
                      ),
                      label: '',
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
        ),
      ),
    );
  }
}
