import 'package:flex_color_scheme/flex_color_scheme.dart';
import 'package:flutter/material.dart';

import 'color_schemes.dart';
import 'typography.dart';
import 'tokens/elevation.dart';
import 'tokens/radius.dart';
import '../../shared/constants/app_icons.dart';

class AppTheme {
  static const _subThemes = FlexSubThemesData(
    defaultRadius: AppRadius.large,
    appBarBackgroundSchemeColor: SchemeColor.primaryContainer,
    appBarCenterTitle: true,
    appBarScrolledUnderElevation: AppElevation.level0,
    elevatedButtonSchemeColor: SchemeColor.primary,
    elevatedButtonSecondarySchemeColor: SchemeColor.onPrimary,
    outlinedButtonSchemeColor: SchemeColor.primary,
    outlinedButtonOutlineSchemeColor: SchemeColor.primary,
    outlinedButtonBorderWidth: 1.4,
    cardRadius: AppRadius.large,
    cardElevation: AppElevation.level2,
    inputDecoratorBorderType: FlexInputBorderType.outline,
    inputDecoratorSchemeColor: SchemeColor.primary,
    inputDecoratorUnfocusedHasBorder: true,
    inputDecoratorRadius: AppRadius.large,
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
        colors: lightScheme,
        surfaceMode: FlexSurfaceMode.levelSurfacesLowScaffold,
        blendLevel: 9,
        useMaterial3: true,
        textTheme: lightTextTheme(),
        fontFamily: primaryFontFamily,
        subThemesData: _subThemes,
        visualDensity: VisualDensity.adaptivePlatformDensity,
      ).copyWith(
        iconTheme: IconThemeData(
          size: AppIconSizes.medium,
          color: lightColorScheme.onSurfaceVariant,
        ),
        primaryIconTheme: IconThemeData(
          size: AppIconSizes.medium,
          color: lightColorScheme.onPrimary,
        ),
        scaffoldBackgroundColor:
            Color.lerp(lightColorScheme.surface, Colors.white, 0.6),
        appBarTheme: AppBarTheme(
          elevation: 0,
          backgroundColor:
              Color.lerp(lightColorScheme.surface, Colors.white, 0.75),
          foregroundColor: lightColorScheme.onSurface,
          centerTitle: true,
        ),
        cardTheme: CardThemeData(
          elevation: AppElevation.level1,
          color: Color.lerp(
            lightColorScheme.surface,
            lightColorScheme.surfaceVariant,
            0.12,
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppRadius.large),
          ),
        ),
        floatingActionButtonTheme: const FloatingActionButtonThemeData(
          elevation: AppElevation.level2,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.all(Radius.circular(AppRadius.large)),
          ),
        ),
      );

  static ThemeData get darkTheme => FlexThemeData.dark(
        colors: darkScheme,
        surfaceMode: FlexSurfaceMode.levelSurfacesLowScaffold,
        blendLevel: 15,
        useMaterial3: true,
        textTheme: darkTextTheme(),
        fontFamily: primaryFontFamily,
        subThemesData: _subThemes,
        visualDensity: VisualDensity.adaptivePlatformDensity,
      ).copyWith(
        iconTheme: IconThemeData(
          size: AppIconSizes.medium,
          color: darkColorScheme.onSurfaceVariant,
        ),
        primaryIconTheme: IconThemeData(
          size: AppIconSizes.medium,
          color: darkColorScheme.onPrimary,
        ),
        scaffoldBackgroundColor:
            Color.lerp(darkColorScheme.surface, Colors.black, 0.4),
        appBarTheme: AppBarTheme(
          elevation: 0,
          backgroundColor:
              Color.lerp(darkColorScheme.surface, Colors.black, 0.3),
          foregroundColor: darkColorScheme.onSurface,
          centerTitle: true,
        ),
        cardTheme: CardThemeData(
          elevation: AppElevation.level1,
          color: Color.lerp(
            darkColorScheme.surface,
            darkColorScheme.surfaceVariant,
            0.16,
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppRadius.large),
          ),
        ),
        floatingActionButtonTheme: const FloatingActionButtonThemeData(
          elevation: AppElevation.level2,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.all(Radius.circular(AppRadius.large)),
          ),
        ),
      );
}
