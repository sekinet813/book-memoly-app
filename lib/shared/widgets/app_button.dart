import 'package:flutter/material.dart';

class AppButton extends StatelessWidget {
  const AppButton.primary({
    super.key,
    required this.label,
    this.icon,
    this.onPressed,
    this.expand = false,
  }) : variant = _ButtonVariant.primary;

  const AppButton.secondary({
    super.key,
    required this.label,
    this.icon,
    this.onPressed,
    this.expand = false,
  }) : variant = _ButtonVariant.secondary;

  final String label;
  final IconData? icon;
  final VoidCallback? onPressed;
  final bool expand;
  final _ButtonVariant variant;

  @override
  Widget build(BuildContext context) {
    final child = switch (variant) {
      _ButtonVariant.primary => _buildFilledButton(),
      _ButtonVariant.secondary => _buildOutlinedButton(),
    };

    if (expand) {
      return SizedBox(width: double.infinity, child: child);
    }

    return child;
  }

  Widget _buildFilledButton() {
    if (icon != null) {
      return ElevatedButton.icon(
        onPressed: onPressed,
        icon: Icon(icon),
        label: Text(label),
      );
    }

    return ElevatedButton(
      onPressed: onPressed,
      child: Text(label),
    );
  }

  Widget _buildOutlinedButton() {
    if (icon != null) {
      return OutlinedButton.icon(
        onPressed: onPressed,
        icon: Icon(icon),
        label: Text(label),
      );
    }

    return OutlinedButton(
      onPressed: onPressed,
      child: Text(label),
    );
  }
}

enum _ButtonVariant { primary, secondary }
