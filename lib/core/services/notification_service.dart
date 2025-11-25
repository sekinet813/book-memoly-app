import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest.dart' as tz;
import 'package:timezone/timezone.dart' as tz;

class NotificationService {
  NotificationService();

  final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();

  bool _initialized = false;

  static const _dailyReminderId = 1;
  static const _reflectionPromptId = 2;

  Future<void> initialize() async {
    if (_initialized) {
      return;
    }

    const androidInit = AndroidInitializationSettings('@mipmap/ic_launcher');
    const darwinInit = DarwinInitializationSettings(
      requestAlertPermission: false,
      requestBadgePermission: false,
      requestSoundPermission: false,
    );

    final settings = const InitializationSettings(
      android: androidInit,
      iOS: darwinInit,
      macOS: darwinInit,
    );

    await _plugin.initialize(settings);
    tz.initializeTimeZones();
    _setLocalTimezone();

    _initialized = true;
  }

  Future<bool> ensurePermissionsGranted() async {
    await initialize();

    final areEnabled = await _plugin.areNotificationsEnabled();
    if (areEnabled ?? false) {
      return true;
    }

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

  Future<void> scheduleDailyReminder(TimeOfDay time) async {
    await initialize();

    final scheduledDate = _nextInstance(time);

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
      matchDateTimeComponents: DateTimeComponents.time,
    );
  }

  Future<void> cancelDailyReminder() async {
    await initialize();
    await _plugin.cancel(_dailyReminderId);
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

  tz.TZDateTime _nextInstance(TimeOfDay time) {
    final now = tz.TZDateTime.now(tz.local);
    var scheduled = tz.TZDateTime(
      tz.local,
      now.year,
      now.month,
      now.day,
      time.hour,
      time.minute,
    );

    if (!scheduled.isAfter(now)) {
      scheduled = scheduled.add(const Duration(days: 1));
    }

    return scheduled;
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
