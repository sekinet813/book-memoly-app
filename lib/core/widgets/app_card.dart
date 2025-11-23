import 'dart:ui';

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
    final baseColor = backgroundColor ?? colorScheme.surface;

    final card = ClipRRect(
      borderRadius: radius,
      child: BackdropFilter(
        filter: ImageFilter.blur(
          sigmaX: AppSpacing.xLarge,
          sigmaY: AppSpacing.xLarge,
        ),
        child: DecoratedBox(
          decoration: BoxDecoration(
            borderRadius: radius,
            color: baseColor.withOpacity(0.18),
            gradient: LinearGradient(
              colors: [
                Colors.white.withOpacity(0.18),
                baseColor.withOpacity(0.12),
              ],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            border: Border.all(
              color: colorScheme.outlineVariant.withOpacity(0.4),
            ),
            boxShadow: [
              BoxShadow(
                color: colorScheme.shadow.withOpacity(0.04),
                blurRadius: AppSpacing.small,
                offset: const Offset(0, AppSpacing.medium),
              ),
            ],
          ),
          child: Padding(
            padding: padding,
            child: child,
          ),
        ),
      ),
    );

    if (onTap != null) {
      return Material(
        color: Colors.transparent,
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
