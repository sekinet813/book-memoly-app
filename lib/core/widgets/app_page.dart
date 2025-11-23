import 'package:flutter/material.dart';

import '../theme/tokens/spacing.dart';
import 'app_navigation_bar.dart';

class AppPage extends StatelessWidget {
  const AppPage({
    super.key,
    required this.title,
    required this.child,
    this.actions,
    this.padding = const EdgeInsets.all(AppSpacing.xLarge),
    this.floatingActionButton,
    this.bottomNavigationBar,
    this.currentDestination,
    this.scrollable = false,
    this.bottom,
    this.backgroundColor,
  });

  final String title;
  final Widget child;
  final List<Widget>? actions;
  final EdgeInsetsGeometry padding;
  final Widget? floatingActionButton;
  final Widget? bottomNavigationBar;
  final AppDestination? currentDestination;
  final bool scrollable;
  final PreferredSizeWidget? bottom;
  final Color? backgroundColor;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    final gradientStart = theme.brightness == Brightness.dark
        ? const Color(0xFF123F2D)
        : const Color(0xFFE8F5EE);
    final gradientEnd = backgroundColor ??
        (theme.brightness == Brightness.dark
            ? const Color(0xFF0C1E16)
            : Colors.white);

    final pageBody = Padding(
      padding: padding,
      child: scrollable
          ? SingleChildScrollView(
              child: child,
            )
          : child,
    );

    final navigationBar = currentDestination != null
        ? AppNavigationBar(current: currentDestination!)
        : bottomNavigationBar;

    return Scaffold(
      appBar: AppBar(
        title: Text(title),
        centerTitle: true,
        actions: actions,
        bottom: bottom,
      ),
      floatingActionButton: floatingActionButton,
      bottomNavigationBar: navigationBar,
      backgroundColor: backgroundColor,
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              gradientStart,
              gradientEnd,
            ],
            stops: const [0.0, 0.65],
          ),
        ),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(
              0,
              AppSpacing.medium,
              0,
              AppSpacing.large,
            ),
            child: pageBody,
          ),
        ),
      ),
    );
  }
}
