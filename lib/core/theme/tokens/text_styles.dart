import 'package:flutter/material.dart';

class AppTextStyles {
  const AppTextStyles._();

  static TextStyle pageTitle(BuildContext context) =>
      Theme.of(context).textTheme.headlineMedium!;

  static TextStyle sectionTitle(BuildContext context) =>
      Theme.of(context).textTheme.titleMedium!.copyWith(fontWeight: FontWeight.w700);

  static TextStyle title(BuildContext context) =>
      Theme.of(context).textTheme.titleMedium!;

  static TextStyle bodyLarge(BuildContext context) =>
      Theme.of(context).textTheme.bodyLarge!;

  static TextStyle bodyMedium(BuildContext context) =>
      Theme.of(context).textTheme.bodyMedium!;

  static TextStyle bodySmall(BuildContext context) =>
      Theme.of(context).textTheme.bodySmall!;

  static TextStyle labelLarge(BuildContext context) =>
      Theme.of(context).textTheme.labelLarge!;
}
