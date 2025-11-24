import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

enum AppFontScale {
  small,
  normal,
  large;

  double get factor {
    switch (this) {
      case AppFontScale.small:
        return 0.94;
      case AppFontScale.normal:
        return 1.0;
      case AppFontScale.large:
        return 1.08;
    }
  }

  String get label {
    switch (this) {
      case AppFontScale.small:
        return 'Small';
      case AppFontScale.normal:
        return 'Normal';
      case AppFontScale.large:
        return 'Large';
    }
  }

  String get description {
    switch (this) {
      case AppFontScale.small:
        return 'コンパクトに表示して情報量を重視';
      case AppFontScale.normal:
        return '標準の文字サイズでバランス良く表示';
      case AppFontScale.large:
        return 'ゆったりとした文字サイズで読みやすく';
    }
  }
}

final String japaneseFontFamily = GoogleFonts.notoSansJp().fontFamily!;
final String primaryFontFamily = GoogleFonts.inter().fontFamily!;
final List<String> memoFontFallbacks = [japaneseFontFamily];

TextTheme _baseTextTheme(Brightness brightness) {
  final material2021 = Typography.material2021();
  return brightness == Brightness.dark ? material2021.white : material2021.black;
}

TextTheme _applyMemoTypography(TextTheme base, AppFontScale scale) {
  final interTheme = GoogleFonts.interTextTheme(base);
  final notoSans = GoogleFonts.notoSansJpTextTheme(interTheme);
  final withFallback = notoSans.apply(
    fontFamily: primaryFontFamily,
    fontFamilyFallback: memoFontFallbacks,
  );

  TextStyle? _soften(
    TextStyle? style, {
    required FontWeight fontWeight,
    required double height,
    double? letterSpacing,
  }) {
    return style?.copyWith(
      fontWeight: fontWeight,
      height: height,
      letterSpacing: letterSpacing,
      leadingDistribution: TextLeadingDistribution.even,
    );
  }

  final tuned = withFallback.copyWith(
    displayLarge: _soften(
      withFallback.displayLarge,
      fontWeight: FontWeight.w600,
      height: 1.15,
      letterSpacing: -0.25,
    ),
    displayMedium: _soften(
      withFallback.displayMedium,
      fontWeight: FontWeight.w600,
      height: 1.16,
      letterSpacing: -0.2,
    ),
    displaySmall: _soften(
      withFallback.displaySmall,
      fontWeight: FontWeight.w600,
      height: 1.2,
      letterSpacing: -0.1,
    ),
    headlineLarge: _soften(
      withFallback.headlineLarge,
      fontWeight: FontWeight.w600,
      height: 1.2,
      letterSpacing: -0.08,
    ),
    headlineMedium: _soften(
      withFallback.headlineMedium,
      fontWeight: FontWeight.w600,
      height: 1.22,
      letterSpacing: -0.04,
    ),
    headlineSmall: _soften(
      withFallback.headlineSmall,
      fontWeight: FontWeight.w600,
      height: 1.22,
    ),
    titleLarge: _soften(
      withFallback.titleLarge,
      fontWeight: FontWeight.w600,
      height: 1.26,
      letterSpacing: -0.02,
    ),
    titleMedium: _soften(
      withFallback.titleMedium,
      fontWeight: FontWeight.w600,
      height: 1.28,
      letterSpacing: -0.01,
    ),
    titleSmall: _soften(
      withFallback.titleSmall,
      fontWeight: FontWeight.w600,
      height: 1.3,
      letterSpacing: 0.01,
    ),
    bodyLarge: _soften(
      withFallback.bodyLarge,
      fontWeight: FontWeight.w500,
      height: 1.7,
      letterSpacing: 0.01,
    ),
    bodyMedium: _soften(
      withFallback.bodyMedium,
      fontWeight: FontWeight.w500,
      height: 1.68,
      letterSpacing: 0.01,
    ),
    bodySmall: _soften(
      withFallback.bodySmall,
      fontWeight: FontWeight.w500,
      height: 1.6,
      letterSpacing: 0.02,
    ),
    labelLarge: _soften(
      withFallback.labelLarge,
      fontWeight: FontWeight.w600,
      height: 1.4,
      letterSpacing: 0.08,
    ),
    labelMedium: _soften(
      withFallback.labelMedium,
      fontWeight: FontWeight.w600,
      height: 1.4,
      letterSpacing: 0.08,
    ),
    labelSmall: _soften(
      withFallback.labelSmall,
      fontWeight: FontWeight.w600,
      height: 1.4,
      letterSpacing: 0.1,
    ),
  );

  return tuned.apply(fontSizeFactor: scale.factor);
}

TextTheme lightTextTheme(AppFontScale scale) =>
    _applyMemoTypography(_baseTextTheme(Brightness.light), scale);

TextTheme darkTextTheme(AppFontScale scale) =>
    _applyMemoTypography(_baseTextTheme(Brightness.dark), scale);
