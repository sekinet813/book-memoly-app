import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../theme/typography.dart';

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
