import 'package:flex_color_scheme/flex_color_scheme.dart';
import 'package:flutter/material.dart';

const FlexSchemeColor lightScheme = FlexSchemeColor(
  primary: Color(0xFF3E8F7B),
  primaryContainer: Color(0xFFA4E1D2),
  secondary: Color(0xFF2F6F64),
  secondaryContainer: Color(0xFFC4EFE4),
  tertiary: Color(0xFFE6A468),
  tertiaryContainer: Color(0xFFFFE1C8),
  appBarColor: Color(0xFF3E8F7B),
  error: Color(0xFFB3261E),
);

const FlexSchemeColor darkScheme = FlexSchemeColor(
  primary: Color(0xFF7DD0BA),
  primaryContainer: Color(0xFF1C4D43),
  secondary: Color(0xFF6FB6A4),
  secondaryContainer: Color(0xFF244F46),
  tertiary: Color(0xFFF2B57F),
  tertiaryContainer: Color(0xFF5C3A1F),
  appBarColor: Color(0xFF1C4D43),
  error: Color(0xFFF2B8B5),
);

final ColorScheme lightColorScheme = FlexColorScheme.light(
  colors: lightScheme,
  surfaceMode: FlexSurfaceMode.levelSurfacesLowScaffold,
  blendLevel: 9,
).toScheme.copyWith(brightness: Brightness.light);

final ColorScheme darkColorScheme = FlexColorScheme.dark(
  colors: darkScheme,
  surfaceMode: FlexSurfaceMode.levelSurfacesLowScaffold,
  blendLevel: 15,
).toScheme.copyWith(brightness: Brightness.dark);
