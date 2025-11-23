import 'package:flutter/material.dart';

import 'app_navigation_bar.dart';

class AppPage extends StatelessWidget {
  const AppPage({
    super.key,
    required this.title,
    required this.child,
    this.actions,
    this.padding = const EdgeInsets.all(24),
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
      body: SafeArea(child: pageBody),
    );
  }
}
