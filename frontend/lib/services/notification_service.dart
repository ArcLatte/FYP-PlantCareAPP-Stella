import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:timezone/data/latest.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;
import '../models/plant.dart';

/// Local care reminders. After every plant load/care action the home screen
/// calls [scheduleCareReminders], which rebuilds the schedule: one grouped
/// notification per day ("3 plants need water") at the user's chosen reminder
/// time (default 9:00), up to two weeks out. Overdue/today plants roll into
/// tomorrow's reminder — the user is presumably looking at the app right now.
class NotificationService {
  NotificationService._();

  static final _plugin = FlutterLocalNotificationsPlugin();
  static bool _initialized = false;
  static const _horizonDays = 14;

  // User-chosen daily reminder time, persisted across launches. Defaults to
  // 9:00 if never set.
  static const _prefHourKey = 'reminder_hour';
  static const _prefMinuteKey = 'reminder_minute';
  static const defaultReminderHour = 9;
  static const defaultReminderMinute = 0;

  /// The reminder time as (hour, minute), 24-hour. Reads from prefs each call
  /// so a change made in Settings is picked up on the next schedule rebuild.
  static Future<(int, int)> getReminderTime() async {
    final prefs = await SharedPreferences.getInstance();
    return (
      prefs.getInt(_prefHourKey) ?? defaultReminderHour,
      prefs.getInt(_prefMinuteKey) ?? defaultReminderMinute,
    );
  }

  /// Persists the daily reminder time. The caller should follow with
  /// [scheduleCareReminders] to rebuild the schedule at the new time.
  static Future<void> setReminderTime(int hour, int minute) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_prefHourKey, hour);
    await prefs.setInt(_prefMinuteKey, minute);
  }

  static Future<bool> init() async {
    if (_initialized) return true;
    try {
      // No named-timezone lookup needed: target times are built as local
      // DateTimes (which carry the device's UTC offset) and converted to
      // absolute UTC instants below.
      tzdata.initializeTimeZones();
      await _plugin.initialize(
        const InitializationSettings(
          android: AndroidInitializationSettings('ic_stat_notification'),
        ),
      );
      await _plugin
          .resolvePlatformSpecificImplementation<
              AndroidFlutterLocalNotificationsPlugin>()
          ?.requestNotificationsPermission();
      _initialized = true;
      return true;
    } catch (_) {
      return false;
    }
  }

  /// Fires a single notification ~10s out so the user can confirm reminders
  /// are working (permission, channel, sound, delivery). Triggered by
  /// long-pressing the reminder-time row in Settings. The user must background
  /// the app after triggering — Android suppresses notifications while
  /// foreground.
  static Future<bool> sendTestNotification() async {
    if (!await init()) return false;
    try {
      final at = tz.TZDateTime.now(tz.UTC).add(const Duration(seconds: 10));
      await _plugin.zonedSchedule(
        99999,
        'Test reminder',
        'If you see this, notifications work.',
        at,
        const NotificationDetails(
          android: AndroidNotificationDetails(
            'care_reminders',
            'Care reminders',
            channelDescription: 'Reminders when plants are due for watering',
            importance: Importance.defaultImportance,
            priority: Priority.defaultPriority,
            icon: 'ic_stat_notification',
          ),
        ),
        androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
        uiLocalNotificationDateInterpretation:
            UILocalNotificationDateInterpretation.absoluteTime,
      );
      return true;
    } catch (_) {
      return false;
    }
  }

  static Future<void> scheduleCareReminders(List<Plant> plants) async {
    if (!await init()) return;
    try {
      await _plugin.cancelAll();

      final (hour, minute) = await getReminderTime();
      final today = DateTime.now();
      final midnight = DateTime(today.year, today.month, today.day);

      // Group plant names by the day their watering comes due.
      final byDay = <int, List<String>>{};
      for (final p in plants) {
        final d = p.daysUntilWater;
        if (d == null) continue;
        final dueInDays = d <= 0 ? 1 : d; // overdue/today → tomorrow
        if (dueInDays > _horizonDays) continue;
        byDay.putIfAbsent(dueInDays, () => []).add(p.name);
      }

      for (final entry in byDay.entries) {
        final day = midnight.add(Duration(days: entry.key));
        // Reminder time local → absolute UTC instant. Skips the
        // flutter_timezone native lookup; if a DST change lands between now
        // and the reminder it may drift an hour, which is fine for watering.
        final localTarget =
            DateTime(day.year, day.month, day.day, hour, minute);
        final at = tz.TZDateTime.from(localTarget.toUtc(), tz.UTC);
        if (at.isBefore(tz.TZDateTime.now(tz.UTC))) continue;

        final names = entry.value;
        final title = names.length == 1
            ? '${names.first} needs water'
            : '${names.length} plants need water';
        final body = names.length == 1
            ? 'Open Stella to log the watering.'
            : names.take(3).join(', ') + (names.length > 3 ? '…' : '');

        await _plugin.zonedSchedule(
          entry.key, // one notification per due-day → day offset is a stable id
          title,
          body,
          at,
          const NotificationDetails(
            android: AndroidNotificationDetails(
              'care_reminders',
              'Care reminders',
              channelDescription:
                  'Reminders when plants are due for watering',
              importance: Importance.defaultImportance,
              priority: Priority.defaultPriority,
              icon: 'ic_stat_notification',
            ),
          ),
          // Inexact delivery avoids the exact-alarm permission; a few
          // minutes of drift is fine for a watering reminder.
          androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
          uiLocalNotificationDateInterpretation:
              UILocalNotificationDateInterpretation.absoluteTime,
        );
      }
    } catch (_) {
      // Reminders are best-effort; never let them break the plant flows.
    }
  }
}
