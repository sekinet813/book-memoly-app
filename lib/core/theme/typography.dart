import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

final String primaryFontFamily = GoogleFonts.notoSansJp().fontFamily!;

TextTheme _baseTextTheme(Brightness brightness) {
  final material2021 = Typography.material2021();
  return brightness == Brightness.dark ? material2021.white : material2021.black;
}

TextTheme _applyJapaneseFont(TextTheme base) {
  final notoSans = GoogleFonts.notoSansJpTextTheme(base);
  return notoSans.copyWith(
    displayLarge: notoSans.displayLarge?.copyWith(fontWeight: FontWeight.w700),
    displayMedium: notoSans.displayMedium?.copyWith(fontWeight: FontWeight.w700),
    displaySmall: notoSans.displaySmall?.copyWith(fontWeight: FontWeight.w700),
    headlineLarge: notoSans.headlineLarge?.copyWith(fontWeight: FontWeight.w700),
    headlineMedium: notoSans.headlineMedium?.copyWith(fontWeight: FontWeight.w700),
    headlineSmall: notoSans.headlineSmall?.copyWith(fontWeight: FontWeight.w700),
    titleLarge: notoSans.titleLarge?.copyWith(fontWeight: FontWeight.w600),
    titleMedium: notoSans.titleMedium?.copyWith(fontWeight: FontWeight.w600),
    titleSmall: notoSans.titleSmall?.copyWith(fontWeight: FontWeight.w600),
    bodyLarge: notoSans.bodyLarge?.copyWith(height: 1.6),
    bodyMedium: notoSans.bodyMedium?.copyWith(height: 1.6),
    bodySmall: notoSans.bodySmall?.copyWith(height: 1.6),
  );
}

TextTheme lightTextTheme() => _applyJapaneseFont(_baseTextTheme(Brightness.light));

TextTheme darkTextTheme() => _applyJapaneseFont(_baseTextTheme(Brightness.dark));
