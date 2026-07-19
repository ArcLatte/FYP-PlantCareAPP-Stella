import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:timezone/data/latest.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;
import '../models/plant.dart';

/// Local care reminders. Plant refreshes rebuild one grouped notification per
/// day for every due Water, Fertilize, and Mist action at the user's chosen
/// reminder time (default 9:00), up to two weeks out.
class NotificationService {
  NotificationService._();

  static final _plugin = FlutterLocalNotificationsPlugin();
  static bool _initialized = false;
  static String? _initializationError;
  static Future<bool>? _permissionRequestInFlight;
  static void Function(String route)? _onNavigate;
  static const _horizonDays = 14;
  static const _channelId = 'care_reminders_v2';

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

  static void configureNavigation(void Function(String route) onNavigate) {
    _onNavigate = onNavigate;
  }

  static Future<bool> init({bool requestPermission = true}) async {
    if (_initialized) {
      if (requestPermission) await requestNotificationPermission();
      return true;
    }
    try {
      // No named-timezone lookup needed: target times are built as local
      // DateTimes (which carry the device's UTC offset) and converted to
      // absolute UTC instants below.
      tzdata.initializeTimeZones();
      await _plugin.initialize(
        settings: const InitializationSettings(
          android: AndroidInitializationSettings('ic_stat_notification'),
        ),
        onDidReceiveNotificationResponse: (response) {
          final route = response.payload;
          if (route != null && route.isNotEmpty) _onNavigate?.call(route);
        },
      );
      _initialized = true;
      _initializationError = null;
      if (requestPermission) await requestNotificationPermission();
      return true;
    } catch (error) {
      _initializationError = error.toString();
      return false;
    }
  }

  /// Requests Android's notification permission and returns the actual state.
  /// Concurrent startup callers share one request so permission activities do
  /// not overlap.
  static Future<bool> requestNotificationPermission() {
    final active = _permissionRequestInFlight;
    if (active != null) return active;

    final future = _requestNotificationPermission();
    _permissionRequestInFlight = future;
    return future.whenComplete(() => _permissionRequestInFlight = null);
  }

  static Future<bool> _requestNotificationPermission() async {
    try {
      if (!await init(requestPermission: false)) return false;
      final current = await Permission.notification.status;
      if (current.isGranted) return true;
      final requested = await Permission.notification.request();
      return requested.isGranted;
    } catch (_) {
      return false;
    }
  }

  static Future<bool> notificationsEnabled() async {
    if (!await init(requestPermission: false)) return false;
    if (!await Permission.notification.isGranted) return false;
    final android = _plugin
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >();
    return await android?.areNotificationsEnabled() ?? true;
  }

  static Future<String?> initialRoute() async {
    if (!await init(requestPermission: false)) return null;
    final details = await _plugin.getNotificationAppLaunchDetails();
    if (details?.didNotificationLaunchApp != true) return null;
    final route = details?.notificationResponse?.payload;
    return route == null || route.isEmpty ? null : route;
  }

  /// Shows a notification immediately, without involving Android's separate
  /// alarm scheduler.
  static Future<NotificationTestResult> sendTestNotification() async {
    if (!await init(requestPermission: false)) {
      return NotificationTestResult.failed(
        _initializationError ?? 'Notification setup failed.',
      );
    }
    if (!await requestNotificationPermission()) {
      return const NotificationTestResult.permissionDenied();
    }
    try {
      await _plugin.show(
        id: 99999,
        title: 'Test reminder',
        body: 'If you see this, notifications work.',
        notificationDetails: const NotificationDetails(
          android: AndroidNotificationDetails(
            _channelId,
            'Care reminders',
            channelDescription: 'Reminders when plant care tasks are due',
            importance: Importance.defaultImportance,
            priority: Priority.defaultPriority,
            icon: 'ic_stat_notification',
          ),
        ),
        payload: '/tasks',
      );
      return const NotificationTestResult.sent();
    } catch (error) {
      return NotificationTestResult.failed(error.toString());
    }
  }

  static Future<void> scheduleCareReminders(List<Plant> plants) async {
    // Background schedule refreshes must never launch a permission dialog.
    if (!await init(requestPermission: false)) return;
    if (!await notificationsEnabled()) return;
    try {
      await _plugin.cancelAll();

      final (hour, minute) = await getReminderTime();
      final today = DateTime.now();
      final midnight = DateTime(today.year, today.month, today.day);

      // Group individual actions by due day. One plant can contribute more
      // than one task, such as Water and Mist.
      final byDay = <int, List<({String action, String plant})>>{};
      for (final p in plants) {
        final care = <({String action, int? days})>[
          (action: 'Water', days: p.daysUntilWater),
          (action: 'Fertilize', days: p.daysUntilFertilizer),
          (action: 'Mist', days: p.daysUntilMisting),
        ];
        for (final item in care) {
          final d = item.days;
          if (d == null) continue;
          final reminderToday = DateTime(
            today.year,
            today.month,
            today.day,
            hour,
            minute,
          );
          final dueInDays = d <= 0 ? (reminderToday.isAfter(today) ? 0 : 1) : d;
          if (dueInDays > _horizonDays) continue;
          byDay.putIfAbsent(dueInDays, () => []).add((
            action: item.action,
            plant: p.name,
          ));
        }
      }

      for (final entry in byDay.entries) {
        final day = midnight.add(Duration(days: entry.key));
        // Reminder time local → absolute UTC instant. Skips the
        // flutter_timezone native lookup; if a DST change lands between now
        // and the reminder it may drift an hour, which is fine for plant care.
        final localTarget = DateTime(
          day.year,
          day.month,
          day.day,
          hour,
          minute,
        );
        final at = tz.TZDateTime.from(localTarget.toUtc(), tz.UTC);
        if (at.isBefore(tz.TZDateTime.now(tz.UTC))) continue;

        final tasks = entry.value;
        final title = tasks.length == 1
            ? '${tasks.first.plant} needs care'
            : '${tasks.length} care tasks due today';
        final body = tasks.length == 1
            ? '${tasks.first.action} is due. Open Tasks to mark it done.'
            : tasks.take(3).map((t) => '${t.action} ${t.plant}').join(' · ') +
                  (tasks.length > 3 ? '…' : '');

        await _plugin.zonedSchedule(
          id: entry.key,
          title: title,
          body: body,
          scheduledDate: at,
          notificationDetails: const NotificationDetails(
            android: AndroidNotificationDetails(
              _channelId,
              'Care reminders',
              channelDescription: 'Reminders when plant care tasks are due',
              importance: Importance.defaultImportance,
              priority: Priority.defaultPriority,
              icon: 'ic_stat_notification',
            ),
          ),
          // Inexact delivery avoids the exact-alarm permission; a few
          // minutes of drift is fine for a care reminder.
          androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
          payload: '/tasks',
        );
      }
    } catch (_) {
      // Reminders are best-effort; never let them break the plant flows.
    }
  }
}

enum NotificationTestStatus { sent, permissionDenied, failed }

class NotificationTestResult {
  final NotificationTestStatus status;
  final String? error;

  const NotificationTestResult.sent()
    : status = NotificationTestStatus.sent,
      error = null;

  const NotificationTestResult.permissionDenied()
    : status = NotificationTestStatus.permissionDenied,
      error = null;

  const NotificationTestResult.failed(this.error)
    : status = NotificationTestStatus.failed;
}
