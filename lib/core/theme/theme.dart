import 'package:flex_color_scheme/flex_color_scheme.dart';
import 'package:flutter/material.dart';

import 'color_schemes.dart';
import 'typography.dart';

class AppTheme {
  static const _subThemes = FlexSubThemesData(
    defaultRadius: 14,
    appBarBackgroundSchemeColor: SchemeColor.primaryContainer,
    appBarForegroundSchemeColor: SchemeColor.onPrimaryContainer,
    appBarCenterTitle: true,
    appBarScrolledUnderElevation: 0,
    elevatedButtonSchemeColor: SchemeColor.primary,
    elevatedButtonSecondarySchemeColor: SchemeColor.onPrimary,
    outlinedButtonSchemeColor: SchemeColor.primary,
    outlinedButtonOutlineSchemeColor: SchemeColor.primary,
    outlinedButtonBorderWidth: 1.4,
    cardRadius: 14,
    cardElevation: 2,
    inputDecoratorBorderType: FlexInputBorderType.outline,
    inputDecoratorSchemeColor: SchemeColor.primary,
    inputDecoratorUnfocusedHasBorder: true,
    inputDecoratorRadius: 14,
    navigationBarHeight: 72,
    navigationBarIndicatorSchemeColor: SchemeColor.primaryContainer,
    navigationBarSelectedIconSchemeColor: SchemeColor.onPrimaryContainer,
    navigationBarUnselectedIconSchemeColor: SchemeColor.onSurfaceVariant,
    navigationBarSelectedLabelSchemeColor: SchemeColor.onPrimaryContainer,
    navigationBarUnselectedLabelSchemeColor: SchemeColor.onSurfaceVariant,
    navigationBarMutedUnselectedIcon: true,
    navigationBarOpacity: 0.95,
  );

  static ThemeData get lightTheme => FlexThemeData.light(
        colorScheme: lightColorScheme,
        useMaterial3: true,
        textTheme: lightTextTheme(),
        fontFamily: primaryFontFamily,
        subThemesData: _subThemes,
        visualDensity: VisualDensity.adaptivePlatformDensity,
      );

  static ThemeData get darkTheme => FlexThemeData.dark(
        colorScheme: darkColorScheme,
        useMaterial3: true,
        textTheme: darkTextTheme(),
        fontFamily: primaryFontFamily,
        subThemesData: _subThemes,
        visualDensity: VisualDensity.adaptivePlatformDensity,
      );
}
