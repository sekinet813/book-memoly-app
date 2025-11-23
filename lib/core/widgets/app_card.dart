import 'package:flutter/material.dart';

class AppCard extends StatelessWidget {
  const AppCard({
    super.key,
    required this.child,
    this.onTap,
    this.padding = const EdgeInsets.all(16),
    this.backgroundColor,
  });

  final Widget child;
  final EdgeInsetsGeometry padding;
  final VoidCallback? onTap;
  final Color? backgroundColor;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final shape = RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(18),
      side: BorderSide(color: colorScheme.outlineVariant.withOpacity(0.6)),
    );

    final card = Card(
      elevation: 1,
      color: backgroundColor ?? colorScheme.surface,
      shadowColor: colorScheme.shadow.withOpacity(0.08),
      surfaceTintColor: colorScheme.surfaceTint.withOpacity(0.08),
      shape: shape,
      clipBehavior: Clip.antiAlias,
      child: Padding(
        padding: padding,
        child: child,
      ),
    );

    if (onTap != null) {
      return InkWell(
        onTap: onTap,
        borderRadius: shape.borderRadius,
        child: card,
      );
    }

    return card;
  }
}
