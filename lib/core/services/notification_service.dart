import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest.dart' as tz;
import 'package:timezone/timezone.dart' as tz;

enum ReminderFrequency {
  daily,
  weekly;

  String get label {
    switch (this) {
      case ReminderFrequency.daily:
        return '毎日';
      case ReminderFrequency.weekly:
        return '毎週';
    }
  }
}

enum NotificationType {
  readingReminder,
  continueReading,
  actionPlanDue,
}

class NotificationPayload {
  NotificationPayload({
    required this.type,
    this.bookId,
    this.bookTitle,
    this.actionId,
    required this.targetRoute,
  });

  factory NotificationPayload.fromJson(String? raw) {
    if (raw == null || raw.isEmpty) {
      throw const FormatException('Empty notification payload');
    }

    final map = jsonDecode(raw) as Map<String, dynamic>;
    final typeIndex = map['type'] as int?;
    if (typeIndex == null ||
        typeIndex < 0 ||
        typeIndex >= NotificationType.values.length) {
      throw const FormatException('Unknown notification type');
    }

    return NotificationPayload(
      type: NotificationType.values[typeIndex],
      bookId: map['bookId'] as int?,
      bookTitle: map['bookTitle'] as String?,
      actionId: map['actionId'] as int?,
      targetRoute: map['route'] as String? ?? '/',
    );
  }

  final NotificationType type;
  final int? bookId;
  final String? bookTitle;
  final int? actionId;
  final String targetRoute;

  String encode() {
    return jsonEncode({
      'type': type.index,
      'bookId': bookId,
      'bookTitle': bookTitle,
      'actionId': actionId,
      'route': targetRoute,
    });
  }
}

class NotificationService {
  NotificationService();

  final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();

  bool _initialized = false;
  void Function(NotificationResponse)? _onSelectNotification;

  static const _dailyReminderId = 1;
  static const _reflectionPromptId = 2;
  static const _continueReadingId = 3;
  static const _actionPlanBaseId = 5000;

  Future<void> initialize() async {
    if (_initialized) {
      return;
    }

    await _plugin.initialize(
      _buildInitializationSettings(),
      onDidReceiveNotificationResponse: _onSelectNotification,
      onDidReceiveBackgroundNotificationResponse: _onSelectNotification,
    );
    tz.initializeTimeZones();
    _setLocalTimezone();

    _initialized = true;
  }

  Future<bool> ensurePermissionsGranted() async {
    await initialize();

    final androidPlugin =
        _plugin.resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>();
    final macPlugin = _plugin.resolvePlatformSpecificImplementation<
        MacOSFlutterLocalNotificationsPlugin>();
    final iosPlugin = _plugin.resolvePlatformSpecificImplementation<
        IOSFlutterLocalNotificationsPlugin>();

    final androidGranted =
        await androidPlugin?.requestNotificationsPermission() ?? false;
    final iosGranted = await iosPlugin?.requestPermissions(
          alert: true,
          sound: true,
          badge: true,
        ) ??
        false;
    final macGranted = await macPlugin?.requestPermissions(
          alert: true,
          sound: true,
          badge: true,
        ) ??
        false;

    return androidGranted || iosGranted || macGranted;
  }

  void registerSelectNotificationHandler(
    void Function(NotificationResponse) onSelectNotification,
  ) {
    _onSelectNotification = onSelectNotification;

    if (_initialized) {
      _plugin.initialize(
        _buildInitializationSettings(),
        onDidReceiveNotificationResponse: _onSelectNotification,
        onDidReceiveBackgroundNotificationResponse: _onSelectNotification,
      );
    }
  }

  Future<NotificationPayload?> getLaunchPayload() async {
    await initialize();
    final launchDetails = await _plugin.getNotificationAppLaunchDetails();
    final payload = launchDetails?.notificationResponse?.payload;
    if (payload == null) {
      return null;
    }

    try {
      return NotificationPayload.fromJson(payload);
    } catch (_) {
      return null;
    }
  }

  Future<void> scheduleReadingReminder(
    TimeOfDay time, {
    ReminderFrequency frequency = ReminderFrequency.daily,
    int weeklyWeekday = DateTime.monday,
  }) async {
    await initialize();

    final scheduledDate = _nextInstance(time, weeklyWeekday, frequency);

    final payload = NotificationPayload(
      type: NotificationType.readingReminder,
      targetRoute: '/reading-speed',
    );

    await _plugin.zonedSchedule(
      _dailyReminderId,
      '今日の読書リマインド',
      '少しだけでも読書を進めませんか？',
      scheduledDate,
      NotificationDetails(
        android: AndroidNotificationDetails(
          'daily_reading_reminder',
          'Daily Reading Reminder',
          channelDescription: '毎日の読書を習慣化するための通知',
          importance: Importance.max,
          priority: Priority.high,
          visibility: NotificationVisibility.public,
        ),
        iOS: const DarwinNotificationDetails(),
        macOS: const DarwinNotificationDetails(),
      ),
      androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
      uiLocalNotificationDateInterpretation:
          UILocalNotificationDateInterpretation.wallClockTime,
      matchDateTimeComponents: frequency == ReminderFrequency.daily
          ? DateTimeComponents.time
          : DateTimeComponents.dayOfWeekAndTime,
      payload: payload.encode(),
    );
  }

  Future<void> cancelDailyReminder() async {
    await initialize();
    await _plugin.cancel(_dailyReminderId);
  }

  Future<void> scheduleContinueReadingReminder({
    required int bookId,
    required String bookTitle,
    required TimeOfDay time,
    ReminderFrequency frequency = ReminderFrequency.daily,
    int weeklyWeekday = DateTime.monday,
  }) async {
    await initialize();

    final scheduledDate = _nextInstance(time, weeklyWeekday, frequency);

    final payload = NotificationPayload(
      type: NotificationType.continueReading,
      bookId: bookId,
      bookTitle: bookTitle,
      targetRoute: '/reading-speed?bookId=$bookId',
    );

    await _plugin.zonedSchedule(
      _continueReadingId,
      '「$bookTitle」の続き、読みませんか？',
      '読んだところから再開しましょう。',
      scheduledDate,
      NotificationDetails(
        android: AndroidNotificationDetails(
          'continue_reading',
          'Continue Reading Reminder',
          channelDescription: '読書中の本に戻るためのリマインダー',
          importance: Importance.high,
          priority: Priority.high,
        ),
        iOS: const DarwinNotificationDetails(),
        macOS: const DarwinNotificationDetails(),
      ),
      androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
      uiLocalNotificationDateInterpretation:
          UILocalNotificationDateInterpretation.wallClockTime,
      matchDateTimeComponents: frequency == ReminderFrequency.daily
          ? DateTimeComponents.time
          : DateTimeComponents.dayOfWeekAndTime,
      payload: payload.encode(),
    );
  }

  Future<void> cancelContinueReadingReminder() async {
    await initialize();
    await _plugin.cancel(_continueReadingId);
  }

  Future<void> scheduleActionPlanReminder({
    required int actionId,
    required String actionTitle,
    required DateTime remindAt,
    int? bookId,
    String? bookTitle,
  }) async {
    await initialize();

    final payload = NotificationPayload(
      type: NotificationType.actionPlanDue,
      actionId: actionId,
      bookId: bookId,
      bookTitle: bookTitle,
      targetRoute:
          bookId != null ? '/actions?bookId=$bookId' : '/actions',
    );

    await _plugin.zonedSchedule(
      _actionPlanBaseId + actionId,
      'アクションプランの期限',
      '$actionTitle${bookTitle != null ? '（$bookTitle）' : ''}',
      tz.TZDateTime.from(remindAt, tz.local),
      NotificationDetails(
        android: AndroidNotificationDetails(
          'action_plan_due',
          'Action Plan Reminder',
          channelDescription: '読書後の行動アイデアを思い出すための通知',
          importance: Importance.high,
          priority: Priority.high,
        ),
        iOS: const DarwinNotificationDetails(),
        macOS: const DarwinNotificationDetails(),
      ),
      androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
      uiLocalNotificationDateInterpretation:
          UILocalNotificationDateInterpretation.absoluteTime,
      payload: payload.encode(),
    );
  }

  Future<void> cancelActionPlanReminder(int actionId) async {
    await initialize();
    await _plugin.cancel(_actionPlanBaseId + actionId);
  }

  Future<void> showReflectionPrompt() async {
    await initialize();

    await _plugin.show(
      _reflectionPromptId,
      '今日の学びを書く？',
      'メモに残すことで明日の読書がもっと楽になります。',
      NotificationDetails(
        android: AndroidNotificationDetails(
          'reading_reflection',
          'Reading Reflection',
          channelDescription: '読書後に気づきを振り返るためのリマインド',
          importance: Importance.high,
          priority: Priority.high,
        ),
        iOS: const DarwinNotificationDetails(),
        macOS: const DarwinNotificationDetails(),
      ),
    );
  }

  tz.TZDateTime _nextInstance(
    TimeOfDay time,
    int weeklyWeekday,
    ReminderFrequency frequency,
  ) {
    final now = tz.TZDateTime.now(tz.local);
    var scheduled = tz.TZDateTime(
      tz.local,
      now.year,
      now.month,
      now.day,
      time.hour,
      time.minute,
    );

    if (frequency == ReminderFrequency.weekly) {
      while (scheduled.weekday != weeklyWeekday || !scheduled.isAfter(now)) {
        scheduled = scheduled.add(const Duration(days: 1));
      }
      return scheduled;
    }

    if (!scheduled.isAfter(now)) {
      scheduled = scheduled.add(const Duration(days: 1));
    }

    return scheduled;
  }

  InitializationSettings _buildInitializationSettings() {
    const androidInit = AndroidInitializationSettings('@mipmap/ic_launcher');
    const darwinInit = DarwinInitializationSettings(
      requestAlertPermission: false,
      requestBadgePermission: false,
      requestSoundPermission: false,
    );

    return const InitializationSettings(
      android: androidInit,
      iOS: darwinInit,
      macOS: darwinInit,
    );
  }

  void _setLocalTimezone() {
    final timeZoneName = DateTime.now().timeZoneName;

    try {
      tz.setLocalLocation(tz.getLocation(timeZoneName));
    } catch (_) {
      tz.setLocalLocation(tz.getLocation('Asia/Tokyo'));
    }
  }
}
