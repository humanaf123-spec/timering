import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest_all.dart' as tz;
import 'package:timezone/timezone.dart' as tz;

class NotificationService {
  static final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();

  static Future<void> init() async {
    tz.initializeTimeZones();

    const AndroidInitializationSettings androidSettings =
        AndroidInitializationSettings('@mipmap/ic_launcher');

    const InitializationSettings initSettings =
        InitializationSettings(android: androidSettings);

    await _plugin.initialize(initSettings);

    final androidPlugin = _plugin.resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin>();
    await androidPlugin?.requestNotificationsPermission();
    await androidPlugin?.requestExactAlarmsPermission();
  }

  static Future<void> showInstantNotification({
    required int id,
    required String title,
    required String body,
    bool playAlarmSound = false,
  }) async {
    final AndroidNotificationDetails androidDetails = AndroidNotificationDetails(
      playAlarmSound ? 'timering_alarm_channel' : 'timering_general_channel',
      playAlarmSound ? 'Timering Alarm & Ringtone' : 'Timering Reminders & Alerts',
      channelDescription:
          'Notifications for Timering alarms, calls, SMS status, and study reminders',
      importance: Importance.max,
      priority: Priority.high,
      playSound: true,
      enableVibration: true,
      sound: playAlarmSound
          ? const RawResourceAndroidNotificationSound('alarm_tone')
          : null,
    );

    final NotificationDetails details = NotificationDetails(android: androidDetails);
    await _plugin.show(id, title, body, details);
  }

  static Future<void> scheduleOnceNotification({
    required int id,
    required String title,
    required String body,
    required DateTime scheduledTime,
    bool playAlarmSound = true,
  }) async {
    if (scheduledTime.isBefore(DateTime.now())) return;

    final tzScheduled = tz.TZDateTime.from(scheduledTime, tz.local);

    final AndroidNotificationDetails androidDetails = AndroidNotificationDetails(
      playAlarmSound ? 'timering_alarm_channel' : 'timering_general_channel',
      playAlarmSound ? 'Timering Alarm & Ringtone' : 'Timering Reminders & Alerts',
      channelDescription: 'Scheduled once-only alarm and reminder alerts',
      importance: Importance.max,
      priority: Priority.high,
      playSound: true,
      enableVibration: true,
      sound: playAlarmSound
          ? const RawResourceAndroidNotificationSound('alarm_tone')
          : null,
    );

    final NotificationDetails details = NotificationDetails(android: androidDetails);

    await _plugin.zonedSchedule(
      id,
      title,
      body,
      tzScheduled,
      details,
      androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
      uiLocalNotificationDateInterpretation:
          UILocalNotificationDateInterpretation.absoluteTime,
    );
  }

  static Future<void> cancelNotification(int id) async {
    await _plugin.cancel(id);
  }
}
