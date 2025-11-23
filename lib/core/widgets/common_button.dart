import 'package:flutter/material.dart';

import '../../shared/constants/app_icons.dart';

class PrimaryButton extends StatelessWidget {
  const PrimaryButton({
    super.key,
    required this.label,
    this.icon,
    this.onPressed,
    this.expand = false,
  });

  final String label;
  final IconData? icon;
  final VoidCallback? onPressed;
  final bool expand;

  @override
  Widget build(BuildContext context) {
    final button = icon != null
        ? FilledButton.icon(
            onPressed: onPressed,
            icon: Icon(
              icon,
              size: AppIconSizes.medium,
              color: Theme.of(context).colorScheme.onPrimary,
            ),
            label: Text(label),
          )
        : FilledButton(
            onPressed: onPressed,
            child: Text(label),
          );

    if (expand) {
      return SizedBox(width: double.infinity, child: button);
    }

    return button;
  }
}

class SecondaryButton extends StatelessWidget {
  const SecondaryButton({
    super.key,
    required this.label,
    this.icon,
    this.onPressed,
    this.expand = false,
  });

  final String label;
  final IconData? icon;
  final VoidCallback? onPressed;
  final bool expand;

  @override
  Widget build(BuildContext context) {
    final button = icon != null
        ? OutlinedButton.icon(
            onPressed: onPressed,
            icon: Icon(
              icon,
              size: AppIconSizes.medium,
              color: Theme.of(context).colorScheme.primary,
            ),
            label: Text(label),
          )
        : OutlinedButton(
            onPressed: onPressed,
            child: Text(label),
          );

    if (expand) {
      return SizedBox(width: double.infinity, child: button);
    }

    return button;
  }
}
