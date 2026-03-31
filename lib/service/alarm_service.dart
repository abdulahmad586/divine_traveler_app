import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:tahfeex/model/journey_alarm.dart';
import 'package:timezone/data/latest_all.dart' as tz_data;
import 'package:timezone/timezone.dart' as tz;

// ── Background notification response ────────────────────────────────────────
// Must be a top-level function. Called when user taps a notification action
// while the app is terminated or in the background.
@pragma('vm:entry-point')
void _onBackgroundNotificationResponse(NotificationResponse response) async {
  if (response.actionId == 'snooze') {
    tz_data.initializeTimeZones();
    await AlarmService._scheduleSnooze(
      AlarmService._snoozeNotifId(response.id ?? 0),
      response.payload,
      useUtc: true,
    );
  }
  // 'dismiss': no-op — notification already dismissed by the OS.
}

// ── Service ──────────────────────────────────────────────────────────────────

class AlarmService {
  AlarmService._();

  static final _plugin = FlutterLocalNotificationsPlugin();

  static const _alarmChannelId = 'tahfeex_alarm';
  static const _reminderChannelId = 'tahfeex_reminder';

  // ── Init ──────────────────────────────────────────────────────────────────

  static Future<void> init() async {
    // Initialize the tz database — required by the library even when we only
    // use tz.UTC. We never call tz.setLocalLocation; instead we convert native
    // DateTime (always correct local time) → UTC for all scheduling.
    tz_data.initializeTimeZones();

    final settings = InitializationSettings(
      android: const AndroidInitializationSettings('@mipmap/ic_launcher'),
      iOS: DarwinInitializationSettings(
        requestAlertPermission: false,
        requestBadgePermission: false,
        requestSoundPermission: false,
        notificationCategories: [
          DarwinNotificationCategory(
            'alarm_category',
            actions: [
              DarwinNotificationAction.plain(
                'snooze',
                'Snooze 10 min',
                options: <DarwinNotificationActionOption>{
                  DarwinNotificationActionOption.foreground
                },
              ),
              DarwinNotificationAction.plain('dismiss', 'Dismiss'),
            ],
          ),
        ],
      ),
    );

    await _plugin.initialize(
      settings,
      onDidReceiveNotificationResponse: _onForegroundResponse,
      onDidReceiveBackgroundNotificationResponse:
          _onBackgroundNotificationResponse,
    );

    // Create Android notification channels.
    final android = _plugin
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>();
    if (android != null) {
      await android.createNotificationChannel(
        const AndroidNotificationChannel(
          _alarmChannelId,
          'Study Alarms',
          description: 'Alarms for your Tahfeex study journeys',
          importance: Importance.max,
          playSound: true,
          enableVibration: true,
          audioAttributesUsage: AudioAttributesUsage.alarm,
        ),
      );
      await android.createNotificationChannel(
        const AndroidNotificationChannel(
          _reminderChannelId,
          'Study Reminders',
          description: '10-minute heads-up before your study alarm',
          importance: Importance.high,
          playSound: true,
        ),
      );
    }
  }

  // ── Permissions ───────────────────────────────────────────────────────────

  static Future<bool> requestPermissions() async {
    final android = _plugin
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>();
    final ios = _plugin
        .resolvePlatformSpecificImplementation<
            IOSFlutterLocalNotificationsPlugin>();

    if (android != null) {
      final notifGranted =
          await android.requestNotificationsPermission() ?? false;
      if (!notifGranted) return false;

      // Check if exact alarms are already permitted before opening settings.
      final exactGranted = await android.canScheduleExactNotifications() ?? false;
      if (!exactGranted) {
        // Opens "Alarms & reminders" settings page. User must grant manually
        // and return to the app — we can't await the result.
        await android.requestExactAlarmsPermission();
        return false; // caller should re-check after user returns
      }
      return true;
    }
    if (ios != null) {
      return await ios.requestPermissions(
            alert: true,
            badge: true,
            sound: true,
          ) ??
          false;
    }
    return true;
  }

  /// Returns true if the device can schedule exact alarms right now.
  static Future<bool> canScheduleExactAlarms() async {
    final android = _plugin
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>();
    if (android == null) return true;
    return await android.canScheduleExactNotifications() ?? false;
  }

  // ── Schedule ──────────────────────────────────────────────────────────────

  static Future<void> schedule(JourneyAlarm alarm) async {
    await cancel(alarm); // cancel old instances first
    if (!alarm.enabled) return;

    final effectiveDays =
        alarm.days.isEmpty ? [1, 2, 3, 4, 5, 6, 7] : alarm.days;
    final payload = '${alarm.journeyTitle}|${alarm.id}';

    for (final day in effectiveDays) {
      final alarmTime = _nextInstanceOf(day, alarm.hour, alarm.minute);
      final reminderTime = alarmTime.subtract(const Duration(minutes: 10));
      final now = tz.TZDateTime.now(tz.UTC);

      // 10-min heads-up (skip if the reminder would fire in the past)
      if (reminderTime.isAfter(now)) {
        await _plugin.zonedSchedule(
          _reminderNotifId(alarm.id, day),
          'Study time in 10 minutes',
          alarm.journeyTitle,
          reminderTime,
          const NotificationDetails(
            android: AndroidNotificationDetails(
              _reminderChannelId,
              'Study Reminders',
              importance: Importance.high,
              priority: Priority.high,
            ),
            iOS: DarwinNotificationDetails(
              presentAlert: true,
              presentSound: true,
            ),
          ),
          androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
          uiLocalNotificationDateInterpretation:
              UILocalNotificationDateInterpretation.absoluteTime,
          matchDateTimeComponents: DateTimeComponents.dayOfWeekAndTime,
          payload: payload,
        );
      }

      // Alarm
      await _plugin.zonedSchedule(
        _alarmNotifId(alarm.id, day),
        'Time to study!',
        alarm.journeyTitle,
        alarmTime,
        const NotificationDetails(
          android: AndroidNotificationDetails(
            _alarmChannelId,
            'Study Alarms',
            importance: Importance.max,
            priority: Priority.max,
            fullScreenIntent: true,
            category: AndroidNotificationCategory.alarm,
            audioAttributesUsage: AudioAttributesUsage.alarm,
            actions: [
              AndroidNotificationAction(
                'snooze',
                'Snooze 10 min',
                showsUserInterface: true,
              ),
              AndroidNotificationAction('dismiss', 'Dismiss'),
            ],
          ),
          iOS: DarwinNotificationDetails(
            presentAlert: true,
            presentSound: true,
            categoryIdentifier: 'alarm_category',
          ),
        ),
        androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
        uiLocalNotificationDateInterpretation:
            UILocalNotificationDateInterpretation.absoluteTime,
        matchDateTimeComponents: DateTimeComponents.dayOfWeekAndTime,
        payload: payload,
      );
    }
  }

  // ── Cancel ────────────────────────────────────────────────────────────────

  static Future<void> cancel(JourneyAlarm alarm) async {
    final effectiveDays =
        alarm.days.isEmpty ? [1, 2, 3, 4, 5, 6, 7] : alarm.days;
    for (final day in effectiveDays) {
      await _plugin.cancel(_alarmNotifId(alarm.id, day));
      await _plugin.cancel(_reminderNotifId(alarm.id, day));
    }
  }

  static Future<void> cancelAllForJourney(List<JourneyAlarm> alarms) async {
    for (final a in alarms) {
      await cancel(a);
    }
  }

  // ── Snooze ────────────────────────────────────────────────────────────────

  static void _onForegroundResponse(NotificationResponse response) {
    if (response.actionId == 'snooze') {
      _scheduleSnooze(_snoozeNotifId(response.id ?? 0), response.payload);
    }
  }

  /// [useUtc] is set to true in the background isolate where tz.local may not
  /// be configured; UTC + 10 min is functionally identical.
  static Future<void> _scheduleSnooze(
    int snoozeId,
    String? payload, {
    bool useUtc = false,
  }) async {
    final location = useUtc ? tz.UTC : tz.local;
    final snoozeTime =
        tz.TZDateTime.now(location).add(const Duration(minutes: 10));

    await _plugin.zonedSchedule(
      snoozeId,
      'Time to study!',
      payload?.split('|').firstOrNull ?? 'Time to study',
      snoozeTime,
      const NotificationDetails(
        android: AndroidNotificationDetails(
          _alarmChannelId,
          'Study Alarms',
          importance: Importance.max,
          priority: Priority.max,
          fullScreenIntent: true,
          category: AndroidNotificationCategory.alarm,
          audioAttributesUsage: AudioAttributesUsage.alarm,
          actions: [
            AndroidNotificationAction(
              'snooze',
              'Snooze 10 min',
              showsUserInterface: true,
            ),
            AndroidNotificationAction('dismiss', 'Dismiss'),
          ],
        ),
        iOS: DarwinNotificationDetails(
          presentAlert: true,
          presentSound: true,
          categoryIdentifier: 'alarm_category',
        ),
      ),
      androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
      uiLocalNotificationDateInterpretation:
          UILocalNotificationDateInterpretation.absoluteTime,
      payload: payload,
    );
  }

  // ── Helpers ───────────────────────────────────────────────────────────────

  /// Returns the next future UTC TZDateTime that falls on [weekday] at
  /// [hour]:[minute] in the device's local time.
  ///
  /// We use the native [DateTime] (always correct local clock) and convert to
  /// UTC so we never need [tz.local], which requires an IANA timezone lookup
  /// that isn't reliably available on Android without a native plugin.
  static tz.TZDateTime _nextInstanceOf(int weekday, int hour, int minute) {
    final now = DateTime.now(); // correct local time from the OS
    var local = DateTime(now.year, now.month, now.day, hour, minute);
    // Push into the future if the time has already passed today.
    if (!local.isAfter(now)) local = local.add(const Duration(days: 1));
    // Advance to the target weekday.
    while (local.weekday != weekday) {
      local = local.add(const Duration(days: 1));
    }
    // Convert to UTC for scheduling — tz.UTC is always available.
    final utc = local.toUtc();
    return tz.TZDateTime(tz.UTC, utc.year, utc.month, utc.day, utc.hour, utc.minute);
  }

  /// Unique int notification ID for an alarm occurrence.
  static int _alarmNotifId(String alarmId, int day) =>
      (alarmId.hashCode.abs() % 10000000) * 20 + (day - 1) * 2;

  /// Unique int notification ID for a 10-min reminder.
  static int _reminderNotifId(String alarmId, int day) =>
      (alarmId.hashCode.abs() % 10000000) * 20 + (day - 1) * 2 + 1;

  /// Snooze notification ID (offset away from the alarm ID range).
  static int _snoozeNotifId(int originalId) => originalId + 500000000;
}
