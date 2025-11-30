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
  return brightness == Brightness.dark
      ? material2021.white
      : material2021.black;
}

TextStyle? _ensureFontSize(TextStyle? target, TextStyle? fallback) {
  if (target == null && fallback == null) return null;

  final fallbackFontSize = fallback?.fontSize ?? 14.0;

  if (target == null) {
    return fallback?.copyWith(fontSize: fallbackFontSize);
  }

  if (target.fontSize != null) {
    return target;
  }

  return target.copyWith(fontSize: fallbackFontSize);
}

TextTheme _ensureTextThemeFontSizes(TextTheme theme, TextTheme fallback) {
  return theme.copyWith(
    displayLarge: _ensureFontSize(theme.displayLarge, fallback.displayLarge),
    displayMedium: _ensureFontSize(theme.displayMedium, fallback.displayMedium),
    displaySmall: _ensureFontSize(theme.displaySmall, fallback.displaySmall),
    headlineLarge: _ensureFontSize(theme.headlineLarge, fallback.headlineLarge),
    headlineMedium: _ensureFontSize(theme.headlineMedium, fallback.headlineMedium),
    headlineSmall: _ensureFontSize(theme.headlineSmall, fallback.headlineSmall),
    titleLarge: _ensureFontSize(theme.titleLarge, fallback.titleLarge),
    titleMedium: _ensureFontSize(theme.titleMedium, fallback.titleMedium),
    titleSmall: _ensureFontSize(theme.titleSmall, fallback.titleSmall),
    bodyLarge: _ensureFontSize(theme.bodyLarge, fallback.bodyLarge),
    bodyMedium: _ensureFontSize(theme.bodyMedium, fallback.bodyMedium),
    bodySmall: _ensureFontSize(theme.bodySmall, fallback.bodySmall),
    labelLarge: _ensureFontSize(theme.labelLarge, fallback.labelLarge),
    labelMedium: _ensureFontSize(theme.labelMedium, fallback.labelMedium),
    labelSmall: _ensureFontSize(theme.labelSmall, fallback.labelSmall),
  );
}

TextTheme _applyMemoTypography(TextTheme base, AppFontScale scale) {
  final interTheme = GoogleFonts.interTextTheme(base);
  final notoSans = GoogleFonts.notoSansJpTextTheme(interTheme);
  final withFallback = notoSans.apply(
    fontFamily: primaryFontFamily,
    fontFamilyFallback: memoFontFallbacks,
  );

  TextStyle? soften(
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
    displayLarge: soften(
      withFallback.displayLarge,
      fontWeight: FontWeight.w600,
      height: 1.15,
      letterSpacing: -0.25,
    ),
    displayMedium: soften(
      withFallback.displayMedium,
      fontWeight: FontWeight.w600,
      height: 1.16,
      letterSpacing: -0.2,
    ),
    displaySmall: soften(
      withFallback.displaySmall,
      fontWeight: FontWeight.w600,
      height: 1.2,
      letterSpacing: -0.1,
    ),
    headlineLarge: soften(
      withFallback.headlineLarge,
      fontWeight: FontWeight.w600,
      height: 1.2,
      letterSpacing: -0.08,
    ),
    headlineMedium: soften(
      withFallback.headlineMedium,
      fontWeight: FontWeight.w600,
      height: 1.22,
      letterSpacing: -0.04,
    ),
    headlineSmall: soften(
      withFallback.headlineSmall,
      fontWeight: FontWeight.w600,
      height: 1.22,
    ),
    titleLarge: soften(
      withFallback.titleLarge,
      fontWeight: FontWeight.w600,
      height: 1.26,
      letterSpacing: -0.02,
    ),
    titleMedium: soften(
      withFallback.titleMedium,
      fontWeight: FontWeight.w600,
      height: 1.28,
      letterSpacing: -0.01,
    ),
    titleSmall: soften(
      withFallback.titleSmall,
      fontWeight: FontWeight.w600,
      height: 1.3,
      letterSpacing: 0.01,
    ),
    bodyLarge: soften(
      withFallback.bodyLarge,
      fontWeight: FontWeight.w500,
      height: 1.7,
      letterSpacing: 0.01,
    ),
    bodyMedium: soften(
      withFallback.bodyMedium,
      fontWeight: FontWeight.w500,
      height: 1.68,
      letterSpacing: 0.01,
    ),
    bodySmall: soften(
      withFallback.bodySmall,
      fontWeight: FontWeight.w500,
      height: 1.6,
      letterSpacing: 0.02,
    ),
    labelLarge: soften(
      withFallback.labelLarge,
      fontWeight: FontWeight.w600,
      height: 1.4,
      letterSpacing: 0.08,
    ),
    labelMedium: soften(
      withFallback.labelMedium,
      fontWeight: FontWeight.w600,
      height: 1.4,
      letterSpacing: 0.08,
    ),
    labelSmall: soften(
      withFallback.labelSmall,
      fontWeight: FontWeight.w600,
      height: 1.4,
      letterSpacing: 0.1,
    ),
  );

  final withFontSizes = _ensureTextThemeFontSizes(tuned, base);

  return withFontSizes.apply(fontSizeFactor: scale.factor);
}

TextTheme lightTextTheme(AppFontScale scale) =>
    _applyMemoTypography(_baseTextTheme(Brightness.light), scale);

TextTheme darkTextTheme(AppFontScale scale) =>
    _applyMemoTypography(_baseTextTheme(Brightness.dark), scale);
