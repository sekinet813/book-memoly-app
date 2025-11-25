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
  primary: Color(0xFF7FD3BE),
  primaryContainer: Color(0xFF214338),
  secondary: Color(0xFF6EC2AD),
  secondaryContainer: Color(0xFF1A4B3F),
  tertiary: Color(0xFFF0B07A),
  tertiaryContainer: Color(0xFF4B3623),
  appBarColor: Color(0xFF214338),
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
  blendLevel: 12,
).toScheme.copyWith(
  brightness: Brightness.dark,
  surface: const Color(0xFF101C17),
  surfaceDim: const Color(0xFF0E1814),
  surfaceBright: const Color(0xFF1B2722),
  surfaceContainerLowest: const Color(0xFF0C1511),
  surfaceContainerLow: const Color(0xFF111B16),
  surfaceContainer: const Color(0xFF15201B),
  surfaceContainerHigh: const Color(0xFF1A2621),
  surfaceContainerHighest: const Color(0xFF1F2C27),
  onPrimary: const Color(0xFF072018),
  onPrimaryContainer: const Color(0xFFD2F5EA),
  onSecondary: const Color(0xFF072018),
  onSecondaryContainer: const Color(0xFFD1F3E9),
  onSurface: const Color(0xFFE4ECE8),
  onSurfaceVariant: const Color(0xFFB6C7BF),
  outlineVariant: const Color(0xFF3C4B45),
);
