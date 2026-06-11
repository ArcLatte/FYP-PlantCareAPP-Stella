import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;
import '../models/plant.dart';

/// Local care reminders. After every plant load/care action the home screen
/// calls [scheduleCareReminders], which rebuilds the schedule: one grouped
/// notification per day at 9:00 ("3 plants need water"), up to two weeks
/// out. Overdue/today plants roll into tomorrow's reminder — the user is
/// presumably looking at the app right now.
class NotificationService {
  NotificationService._();

  static final _plugin = FlutterLocalNotificationsPlugin();
  static bool _initialized = false;
  static const _reminderHour = 9;
  static const _horizonDays = 14;

  static Future<bool> init() async {
    if (_initialized) return true;
    try {
      // No named-timezone lookup needed: target times are built as local
      // DateTimes (which carry the device's UTC offset) and converted to
      // absolute UTC instants below.
      tzdata.initializeTimeZones();
      await _plugin.initialize(
        const InitializationSettings(
          android: AndroidInitializationSettings('@mipmap/ic_launcher'),
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

  static Future<void> scheduleCareReminders(List<Plant> plants) async {
    if (!await init()) return;
    try {
      await _plugin.cancelAll();

      final today = DateTime.now();
      final midnight = DateTime(today.year, today.month, today.day);

      // Group plant names by the day their watering comes due.
      final byDay = <int, List<String>>{};
      for (final p in plants) {
        final d = p.daysUntilWater;
        if (d == null) continue;
        final dueInDays = d <= 0 ? 1 : d; // overdue/today → tomorrow 9:00
        if (dueInDays > _horizonDays) continue;
        byDay.putIfAbsent(dueInDays, () => []).add(p.name);
      }

      for (final entry in byDay.entries) {
        final day = midnight.add(Duration(days: entry.key));
        // 9:00 local → absolute UTC instant. Skips the flutter_timezone
        // native lookup; if a DST change lands between now and the
        // reminder it may drift an hour, which is fine for watering.
        final localTarget =
            DateTime(day.year, day.month, day.day, _reminderHour);
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
              icon: '@mipmap/ic_launcher',
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
