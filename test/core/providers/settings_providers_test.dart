import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_platform_interface.dart';

import 'package:book_memoly_app/core/providers/settings_providers.dart';
import 'package:book_memoly_app/core/theme/typography.dart';

class _ThrowingPreferencesStore extends SharedPreferencesStorePlatform {
  @override
  Future<bool> clear() => Future.error(Exception('clear failed'));

  @override
  Future<Map<String, Object>> getAll() => Future.error(Exception('getAll failed'));

  @override
  Future<bool> remove(String key) => Future.error(Exception('remove failed'));

  @override
  Future<bool> setValue(String valueType, String key, Object value) =>
      Future.error(Exception('setValue failed'));
}

Future<void> _flushMicrotasks() => pumpEventQueue(times: 20);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  group('ThemeModeNotifier', () {
    test('loads saved theme mode on initialization', () async {
      SharedPreferences.setMockInitialValues({
        'app_theme_mode': AppThemeMode.dark.index,
      });

      final notifier = ThemeModeNotifier();
      await _flushMicrotasks();

      expect(notifier.state, AppThemeMode.dark);
    });

    test('persists updates to storage', () async {
      final notifier = ThemeModeNotifier();
      await _flushMicrotasks();

      await notifier.update(AppThemeMode.light);
      final prefs = await SharedPreferences.getInstance();

      expect(prefs.getInt('app_theme_mode'), AppThemeMode.light.index);
    });
  });

  group('FontScaleNotifier', () {
    test('loads saved font scale on initialization', () async {
      SharedPreferences.setMockInitialValues({
        'app_font_scale': AppFontScale.large.index,
      });

      final notifier = FontScaleNotifier();
      await _flushMicrotasks();

      expect(notifier.state, AppFontScale.large);
    });

    test('ignores invalid stored font scale values', () async {
      SharedPreferences.setMockInitialValues({
        'app_font_scale': -1,
      });

      final notifier = FontScaleNotifier();
      await _flushMicrotasks();

      expect(notifier.state, AppFontScale.normal);
    });

    test('continues working when storage access fails', () async {
      final originalStore = SharedPreferencesStorePlatform.instance;
      SharedPreferencesStorePlatform.instance = _ThrowingPreferencesStore();

      addTearDown(() {
        SharedPreferencesStorePlatform.instance = originalStore;
      });

      final notifier = FontScaleNotifier();
      await _flushMicrotasks();

      expect(notifier.state, AppFontScale.normal);

      await notifier.update(AppFontScale.small);

      expect(notifier.state, AppFontScale.small);
    });
  });
}
