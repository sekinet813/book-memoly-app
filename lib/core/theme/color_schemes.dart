import 'package:flex_color_scheme/flex_color_scheme.dart';
import 'package:flutter/material.dart';

const FlexSchemeColor _lightScheme = FlexSchemeColor(
  primary: Color(0xFF2E7D32),
  primaryContainer: Color(0xFFA5D6A7),
  secondary: Color(0xFF33691E),
  secondaryContainer: Color(0xFFCEEAB0),
  tertiary: Color(0xFF00897B),
  tertiaryContainer: Color(0xFFA7FFEB),
  appBarColor: Color(0xFF2E7D32),
  error: Color(0xFFBA1A1A),
);

const FlexSchemeColor _darkScheme = FlexSchemeColor(
  primary: Color(0xFF81C784),
  primaryContainer: Color(0xFF1B5E20),
  secondary: Color(0xFF9CCC65),
  secondaryContainer: Color(0xFF2E7D32),
  tertiary: Color(0xFF4DB6AC),
  tertiaryContainer: Color(0xFF0D3B1A),
  appBarColor: Color(0xFF1B5E20),
  error: Color(0xFFF2B8B5),
);

final ColorScheme lightColorScheme = FlexColorScheme.light(
  colors: _lightScheme,
  surfaceMode: FlexSurfaceMode.levelSurfacesLowScaffold,
  blendLevel: 9,
).toScheme.copyWith(brightness: Brightness.light);

final ColorScheme darkColorScheme = FlexColorScheme.dark(
  colors: _darkScheme,
  surfaceMode: FlexSurfaceMode.levelSurfacesLowScaffold,
  blendLevel: 15,
).toScheme.copyWith(brightness: Brightness.dark);
