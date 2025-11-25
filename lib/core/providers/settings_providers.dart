import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../theme/typography.dart';

enum AppThemeMode {
  system('システム連動'),
  light('ライト'),
  dark('ダーク');

  const AppThemeMode(this.label);

  final String label;

  ThemeMode toMaterialThemeMode() {
    switch (this) {
      case AppThemeMode.system:
        return ThemeMode.system;
      case AppThemeMode.light:
        return ThemeMode.light;
      case AppThemeMode.dark:
        return ThemeMode.dark;
    }
  }
}

class ThemeModeNotifier extends StateNotifier<AppThemeMode> {
  ThemeModeNotifier() : super(AppThemeMode.system) {
    _loadFromStorage();
  }

  static const _themeModeKey = 'app_theme_mode';

  Future<void> _loadFromStorage() async {
    final prefs = await SharedPreferences.getInstance();
    final savedIndex = prefs.getInt(_themeModeKey);
    if (savedIndex != null &&
        savedIndex >= 0 &&
        savedIndex < AppThemeMode.values.length) {
      state = AppThemeMode.values[savedIndex];
    }
  }

  Future<void> update(AppThemeMode mode) async {
    state = mode;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_themeModeKey, mode.index);
  }
}

class FontScaleNotifier extends StateNotifier<AppFontScale> {
  FontScaleNotifier() : super(AppFontScale.normal) {
    _loadFromStorage();
  }

  static const _fontScaleKey = 'app_font_scale';

  Future<void> _loadFromStorage() async {
    final prefs = await SharedPreferences.getInstance();
    final savedIndex = prefs.getInt(_fontScaleKey);
    if (savedIndex != null && savedIndex >= 0 && savedIndex < AppFontScale.values.length) {
      state = AppFontScale.values[savedIndex];
    }
  }

  Future<void> update(AppFontScale scale) async {
    state = scale;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_fontScaleKey, scale.index);
  }
}

final fontScaleProvider =
    StateNotifierProvider<FontScaleNotifier, AppFontScale>((ref) => FontScaleNotifier());

final themeModeProvider =
    StateNotifierProvider<ThemeModeNotifier, AppThemeMode>((ref) => ThemeModeNotifier());
