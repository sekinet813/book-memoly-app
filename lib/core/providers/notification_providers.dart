import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../services/notification_service.dart';

class NotificationSettingsState {
  const NotificationSettingsState({
    required this.reminderEnabled,
    required this.reminderTime,
    required this.reflectionPromptEnabled,
    required this.permissionGranted,
  });

  final bool reminderEnabled;
  final TimeOfDay reminderTime;
  final bool reflectionPromptEnabled;
  final bool permissionGranted;

  NotificationSettingsState copyWith({
    bool? reminderEnabled,
    TimeOfDay? reminderTime,
    bool? reflectionPromptEnabled,
    bool? permissionGranted,
  }) {
    return NotificationSettingsState(
      reminderEnabled: reminderEnabled ?? this.reminderEnabled,
      reminderTime: reminderTime ?? this.reminderTime,
      reflectionPromptEnabled:
          reflectionPromptEnabled ?? this.reflectionPromptEnabled,
      permissionGranted: permissionGranted ?? this.permissionGranted,
    );
  }
}

final notificationServiceProvider = Provider<NotificationService>((ref) {
  return NotificationService();
});

final notificationSettingsNotifierProvider =
    AsyncNotifierProvider<NotificationSettingsNotifier,
        NotificationSettingsState>(NotificationSettingsNotifier.new);

class NotificationSettingsNotifier
    extends AsyncNotifier<NotificationSettingsState> {
  NotificationSettingsNotifier();

  static const _reminderEnabledKey = 'daily_reminder_enabled';
  static const _reminderTimeKey = 'daily_reminder_time';
  static const _reflectionPromptKey = 'reflection_prompt_enabled';

  NotificationService get _service => ref.read(notificationServiceProvider);

  @override
  Future<NotificationSettingsState> build() async {
    final prefs = await SharedPreferences.getInstance();
    await _service.initialize();

    final reminderEnabled = prefs.getBool(_reminderEnabledKey) ?? true;
    final reflectionPromptEnabled = prefs.getBool(_reflectionPromptKey) ?? true;
    final reminderTime = _parseReminderTime(
          prefs.getString(_reminderTimeKey),
        ) ??
        const TimeOfDay(hour: 20, minute: 0);

    final permissionGranted = await _service.ensurePermissionsGranted();

    if (reminderEnabled && permissionGranted) {
      await _service.scheduleDailyReminder(reminderTime);
    }

    return NotificationSettingsState(
      reminderEnabled: reminderEnabled,
      reminderTime: reminderTime,
      reflectionPromptEnabled: reflectionPromptEnabled,
      permissionGranted: permissionGranted,
    );
  }

  Future<void> updateReminderEnabled(bool enabled) async {
    final current = state.valueOrNull;
    if (current == null) {
      return;
    }

    final prefs = await SharedPreferences.getInstance();
    var permissionGranted = current.permissionGranted;

    if (enabled) {
      permissionGranted = await _service.ensurePermissionsGranted();
      if (permissionGranted) {
        await _service.scheduleDailyReminder(current.reminderTime);
      }
    } else {
      await _service.cancelDailyReminder();
    }

    await prefs.setBool(_reminderEnabledKey, enabled);

    state = AsyncData(
      current.copyWith(
        reminderEnabled: enabled,
        permissionGranted: permissionGranted,
      ),
    );
  }

  Future<void> updateReminderTime(TimeOfDay time) async {
    final current = state.valueOrNull;
    if (current == null) {
      return;
    }

    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_reminderTimeKey, _formatTime(time));

    if (current.reminderEnabled && current.permissionGranted) {
      await _service.scheduleDailyReminder(time);
    }

    state = AsyncData(current.copyWith(reminderTime: time));
  }

  Future<void> updateReflectionPromptEnabled(bool enabled) async {
    final current = state.valueOrNull;
    if (current == null) {
      return;
    }

    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_reflectionPromptKey, enabled);

    state = AsyncData(current.copyWith(reflectionPromptEnabled: enabled));
  }

  Future<void> triggerPostReadingPrompt() async {
    final current = state.valueOrNull;
    if (current == null || !current.reflectionPromptEnabled) {
      return;
    }

    await _service.ensurePermissionsGranted();
    await _service.showReflectionPrompt();
  }

  TimeOfDay? _parseReminderTime(String? stored) {
    if (stored == null || !stored.contains(':')) {
      return null;
    }

    final parts = stored.split(':');
    if (parts.length != 2) {
      return null;
    }

    final hour = int.tryParse(parts[0]);
    final minute = int.tryParse(parts[1]);
    if (hour == null || minute == null) {
      return null;
    }

    return TimeOfDay(hour: hour, minute: minute);
  }

  String _formatTime(TimeOfDay time) {
    final hour = time.hour.toString().padLeft(2, '0');
    final minute = time.minute.toString().padLeft(2, '0');
    return '$hour:$minute';
  }
}
