import 'package:flutter/material.dart';

import '../theme/tokens/radius.dart';
import '../theme/tokens/spacing.dart';

class AppCard extends StatelessWidget {
  const AppCard({
    super.key,
    required this.child,
    this.onTap,
    this.padding = const EdgeInsets.all(AppSpacing.large),
    this.backgroundColor,
  });

  final Widget child;
  final EdgeInsetsGeometry padding;
  final VoidCallback? onTap;
  final Color? backgroundColor;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    const radius = AppRadius.largeRadius;
    final baseColor = backgroundColor ??
        Color.lerp(
              colorScheme.surface,
              colorScheme.surfaceVariant,
              0.18,
            ) ??
        colorScheme.surface;

    final card = DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: radius,
        color: baseColor,
        border: Border.all(
          color: colorScheme.outlineVariant.withOpacity(0.35),
        ),
        boxShadow: [
          BoxShadow(
            color: colorScheme.shadow.withOpacity(0.06),
            blurRadius: AppSpacing.large,
            offset: const Offset(0, AppSpacing.small),
          ),
        ],
      ),
      child: Padding(
        padding: padding,
        child: child,
      ),
    );

    if (onTap != null) {
      return Material(
        color: Colors.transparent,
        borderRadius: radius,
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          borderRadius: radius,
          splashColor: colorScheme.primary.withOpacity(0.08),
          highlightColor: colorScheme.primary.withOpacity(0.04),
          child: card,
        ),
      );
    }

    return card;
  }
}
