import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/book.dart';
import '../database/app_database.dart';
import '../services/notification_service.dart';
import 'database_providers.dart';
import '../repositories/local_database_repository.dart';
import '../routing/app_router.dart';

class NotificationSettingsState {
  const NotificationSettingsState({
    required this.reminderEnabled,
    required this.reminderTime,
    required this.reminderFrequency,
    required this.weeklyWeekday,
    required this.continueReminderEnabled,
    required this.actionPlanRemindersEnabled,
    required this.reflectionPromptEnabled,
    required this.permissionGranted,
  });

  final bool reminderEnabled;
  final TimeOfDay reminderTime;
  final ReminderFrequency reminderFrequency;
  final int weeklyWeekday;
  final bool continueReminderEnabled;
  final bool actionPlanRemindersEnabled;
  final bool reflectionPromptEnabled;
  final bool permissionGranted;

  NotificationSettingsState copyWith({
    bool? reminderEnabled,
    TimeOfDay? reminderTime,
    ReminderFrequency? reminderFrequency,
    int? weeklyWeekday,
    bool? continueReminderEnabled,
    bool? actionPlanRemindersEnabled,
    bool? reflectionPromptEnabled,
    bool? permissionGranted,
  }) {
    return NotificationSettingsState(
      reminderEnabled: reminderEnabled ?? this.reminderEnabled,
      reminderTime: reminderTime ?? this.reminderTime,
      reminderFrequency: reminderFrequency ?? this.reminderFrequency,
      weeklyWeekday: weeklyWeekday ?? this.weeklyWeekday,
      continueReminderEnabled:
          continueReminderEnabled ?? this.continueReminderEnabled,
      actionPlanRemindersEnabled:
          actionPlanRemindersEnabled ?? this.actionPlanRemindersEnabled,
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
  static const _reminderFrequencyKey = 'reading_reminder_frequency';
  static const _weeklyWeekdayKey = 'reading_reminder_weekday';
  static const _continueReminderKey = 'continue_reading_enabled';
  static const _actionPlanReminderKey = 'action_plan_reminder_enabled';
  static const _reflectionPromptKey = 'reflection_prompt_enabled';

  NotificationService get _service => ref.read(notificationServiceProvider);
  LocalDatabaseRepository? get _repositoryOrNull {
    try {
      return ref.read(localDatabaseRepositoryProvider);
    } catch (_) {
      return null;
    }
  }

  @override
  Future<NotificationSettingsState> build() async {
    final prefs = await SharedPreferences.getInstance();
    await _service.initialize();

    final reminderEnabled = prefs.getBool(_reminderEnabledKey) ?? true;
    final reflectionPromptEnabled = prefs.getBool(_reflectionPromptKey) ?? true;
    final reminderFrequency = _parseFrequency(
          prefs.getInt(_reminderFrequencyKey),
        ) ??
        ReminderFrequency.daily;
    final weeklyWeekday = prefs.getInt(_weeklyWeekdayKey) ?? DateTime.monday;
    final continueReminderEnabled =
        prefs.getBool(_continueReminderKey) ?? true;
    final actionPlanRemindersEnabled =
        prefs.getBool(_actionPlanReminderKey) ?? true;
    final reminderTime = _parseReminderTime(
          prefs.getString(_reminderTimeKey),
        ) ??
        const TimeOfDay(hour: 20, minute: 0);

    final permissionGranted = await _service.ensurePermissionsGranted();

    if (reminderEnabled && permissionGranted) {
      await _service.scheduleReadingReminder(
        reminderTime,
        frequency: reminderFrequency,
        weeklyWeekday: weeklyWeekday,
      );
    }

    if (continueReminderEnabled && permissionGranted) {
      await _scheduleContinueReadingReminder(
        time: reminderTime,
        frequency: reminderFrequency,
        weeklyWeekday: weeklyWeekday,
      );
    }

    if (actionPlanRemindersEnabled && permissionGranted) {
      await refreshActionPlanReminders();
    }

    return NotificationSettingsState(
      reminderEnabled: reminderEnabled,
      reminderTime: reminderTime,
      reminderFrequency: reminderFrequency,
      weeklyWeekday: weeklyWeekday,
      continueReminderEnabled: continueReminderEnabled,
      actionPlanRemindersEnabled: actionPlanRemindersEnabled,
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
        await _service.scheduleReadingReminder(
          current.reminderTime,
          frequency: current.reminderFrequency,
          weeklyWeekday: current.weeklyWeekday,
        );
        if (current.continueReminderEnabled) {
          await _scheduleContinueReadingReminder(
            time: current.reminderTime,
            frequency: current.reminderFrequency,
            weeklyWeekday: current.weeklyWeekday,
          );
        }
      }
    } else {
      await _service.cancelDailyReminder();
      await _service.cancelContinueReadingReminder();
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
      await _service.scheduleReadingReminder(
        time,
        frequency: current.reminderFrequency,
        weeklyWeekday: current.weeklyWeekday,
      );
      if (current.continueReminderEnabled) {
        await _scheduleContinueReadingReminder(
          time: time,
          frequency: current.reminderFrequency,
          weeklyWeekday: current.weeklyWeekday,
        );
      }
    }

    state = AsyncData(current.copyWith(reminderTime: time));
  }

  Future<void> updateReminderFrequency(ReminderFrequency frequency) async {
    final current = state.valueOrNull;
    if (current == null) {
      return;
    }

    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_reminderFrequencyKey, frequency.index);

    final newState = current.copyWith(reminderFrequency: frequency);
    await _rescheduleReadingReminders(newState);

    state = AsyncData(newState);
  }

  Future<void> updateWeeklyWeekday(int weekday) async {
    final current = state.valueOrNull;
    if (current == null) {
      return;
    }

    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_weeklyWeekdayKey, weekday);

    final newState = current.copyWith(weeklyWeekday: weekday);
    await _rescheduleReadingReminders(newState);

    state = AsyncData(newState);
  }

  Future<void> updateContinueReminderEnabled(bool enabled) async {
    final current = state.valueOrNull;
    if (current == null) {
      return;
    }

    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_continueReminderKey, enabled);

    if (enabled && current.permissionGranted && current.reminderEnabled) {
      await _scheduleContinueReadingReminder(
        time: current.reminderTime,
        frequency: current.reminderFrequency,
        weeklyWeekday: current.weeklyWeekday,
      );
    } else {
      await _service.cancelContinueReadingReminder();
    }

    state = AsyncData(current.copyWith(continueReminderEnabled: enabled));
  }

  Future<void> updateActionPlanReminderEnabled(bool enabled) async {
    final current = state.valueOrNull;
    if (current == null) {
      return;
    }

    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_actionPlanReminderKey, enabled);

    if (enabled) {
      await refreshActionPlanReminders();
    } else {
      await _cancelAllActionPlanReminders();
    }

    state = AsyncData(current.copyWith(actionPlanRemindersEnabled: enabled));
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

  Future<void> refreshContinueReadingReminder() async {
    final current = state.valueOrNull;
    if (current == null ||
        !current.permissionGranted ||
        !current.reminderEnabled ||
        !current.continueReminderEnabled) {
      return;
    }

    await _scheduleContinueReadingReminder(
      time: current.reminderTime,
      frequency: current.reminderFrequency,
      weeklyWeekday: current.weeklyWeekday,
    );
  }

  Future<void> refreshActionPlanReminders() async {
    final current = state.valueOrNull;
    final repository = _repositoryOrNull;
    if (current == null || repository == null) {
      return;
    }

    final actions = await repository.getAllActions();
    final books = await repository.getAllBooks();
    final bookTitleMap = {for (final book in books) book.id: book.title};

    for (final action in actions) {
      if (action.remindAt == null ||
          !current.permissionGranted ||
          !current.actionPlanRemindersEnabled) {
        await _service.cancelActionPlanReminder(action.id);
        continue;
      }

      if (action.remindAt!.isAfter(DateTime.now())) {
        await _service.scheduleActionPlanReminder(
          actionId: action.id,
          actionTitle: action.title,
          remindAt: action.remindAt!,
          bookId: action.bookId,
          bookTitle: bookTitleMap[action.bookId],
        );
      } else {
        await _service.cancelActionPlanReminder(action.id);
      }
    }
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

  ReminderFrequency? _parseFrequency(int? stored) {
    if (stored == null) {
      return null;
    }

    if (stored < 0 || stored >= ReminderFrequency.values.length) {
      return null;
    }

    return ReminderFrequency.values[stored];
  }

  Future<void> _rescheduleReadingReminders(
    NotificationSettingsState newState,
  ) async {
    if (!newState.permissionGranted || !newState.reminderEnabled) {
      return;
    }

    await _service.scheduleReadingReminder(
      newState.reminderTime,
      frequency: newState.reminderFrequency,
      weeklyWeekday: newState.weeklyWeekday,
    );

    if (newState.continueReminderEnabled) {
      await _scheduleContinueReadingReminder(
        time: newState.reminderTime,
        frequency: newState.reminderFrequency,
        weeklyWeekday: newState.weeklyWeekday,
      );
    }
  }

  Future<void> _scheduleContinueReadingReminder({
    required TimeOfDay time,
    required ReminderFrequency frequency,
    required int weeklyWeekday,
  }) async {
    final repository = _repositoryOrNull;
    if (repository == null) {
      return;
    }

    final books = await repository.getAllBooks();
    final readingBooks = books
        .where((book) => book.status == BookStatus.reading.toDbValue)
        .toList();

    if (readingBooks.isEmpty) {
      await _service.cancelContinueReadingReminder();
      return;
    }

    readingBooks
        .sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
    final target = readingBooks.first;

    await _service.scheduleContinueReadingReminder(
      bookId: target.id,
      bookTitle: target.title,
      time: time,
      frequency: frequency,
      weeklyWeekday: weeklyWeekday,
    );
  }

  Future<void> _cancelAllActionPlanReminders() async {
    final repository = _repositoryOrNull;
    if (repository == null) {
      return;
    }

    final actions = await repository.getAllActions();
    for (final action in actions) {
      await _service.cancelActionPlanReminder(action.id);
    }
  }
}

final notificationPayloadProvider =
    StateProvider<NotificationPayload?>((_) => null);

final notificationNavigationProvider =
    Provider<NotificationNavigationHandler>((ref) {
  return NotificationNavigationHandler(ref);
});

class NotificationNavigationHandler {
  NotificationNavigationHandler(this._ref) {
    _setup();
  }

  final Ref _ref;

  void _setup() {
    final service = _ref.read(notificationServiceProvider);
    service.registerSelectNotificationHandler(_onNotificationResponse);
    _loadInitialPayload(service);
  }

  Future<void> _loadInitialPayload(NotificationService service) async {
    final payload = await service.getLaunchPayload();
    if (payload != null) {
      _handlePayload(payload);
    }
  }

  void _onNotificationResponse(NotificationResponse response) {
    final rawPayload = response.payload;
    if (rawPayload == null) {
      return;
    }

    try {
      final payload = NotificationPayload.fromJson(rawPayload);
      _handlePayload(payload);
    } catch (_) {
      // Ignore malformed payloads
    }
  }

  void _handlePayload(NotificationPayload payload) {
    _ref.read(notificationPayloadProvider.notifier).state = payload;
    final router = _ref.read(appRouterProvider);
    router.go(payload.targetRoute);
  }
}
