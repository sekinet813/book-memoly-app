import 'package:flutter/material.dart';

class AppPage extends StatelessWidget {
  const AppPage({
    super.key,
    required this.title,
    required this.child,
    this.actions,
    this.padding = const EdgeInsets.all(24),
    this.floatingActionButton,
    this.bottomNavigationBar,
    this.scrollable = false,
    this.bottom,
  });

  final String title;
  final Widget child;
  final List<Widget>? actions;
  final EdgeInsetsGeometry padding;
  final Widget? floatingActionButton;
  final Widget? bottomNavigationBar;
  final bool scrollable;
  final PreferredSizeWidget? bottom;

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

    return Scaffold(
      appBar: AppBar(
        title: Text(title),
        centerTitle: true,
        actions: actions,
        bottom: bottom,
      ),
      floatingActionButton: floatingActionButton,
      bottomNavigationBar: bottomNavigationBar,
      body: SafeArea(child: pageBody),
    );
  }
}
