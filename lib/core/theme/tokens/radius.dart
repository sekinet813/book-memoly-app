import 'package:flutter/material.dart';

class AppRadius {
  const AppRadius._();

  static const double small = 8;
  static const double medium = 12;
  static const double large = 16;

  static const BorderRadius smallRadius = BorderRadius.all(Radius.circular(small));
  static const BorderRadius mediumRadius = BorderRadius.all(Radius.circular(medium));
  static const BorderRadius largeRadius = BorderRadius.all(Radius.circular(large));
}
