import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:timezone/data/latest.dart' as tz_data;
import 'package:timezone/timezone.dart' as tz;

import '../../core/scheduling/reminder_scheduler.dart';
import '../../core/utils/date_formatter.dart';
import '../../services/live_reminder_service.dart';
import '../models/prescription.dart';
import '../models/profile.dart';

/// Wraps `flutter_local_notifications` behind the one thing the rest of the
/// app actually needs: keep every prescription's scheduled reminders in
/// sync with the database. Nothing else touches the plugin directly.
///
/// Scheduling decisions (does this reminder time pass the assigned
/// profile's bedtime?) live in `core/scheduling/reminder_scheduler.dart` as
/// plain, unit-testable functions -- this class is just the thin, untestable
/// (without a real device) layer that acts on them.
class NotificationService {
  NotificationService({LiveReminderService? liveReminderService})
      : _plugin = FlutterLocalNotificationsPlugin(),
        _liveReminderService =
            liveReminderService ?? LiveReminderService.instance;

  final FlutterLocalNotificationsPlugin _plugin;
  final LiveReminderService _liveReminderService;
  bool _initialized = false;
  List<Prescription> _currentPrescriptions = const [];
  List<Profile> _currentProfiles = const [];

  static const _channelId = 'dose_reminders';
  static const _channelName = 'Dose Reminders';
  static const _channelDescription = 'Reminders to take a scheduled medication dose.';
  static const snoozeActionId = 'snooze_dose_reminder';

  static const _finalCallChannelId = 'bedtime_final_call';
  static const _finalCallChannelName = 'Pre-Bedtime Final Call';
  static const _finalCallChannelDescription =
      'High-priority reminder for pending doses before bedtime.';

  Future<void> init() async {
    if (_initialized) return;

    tz_data.initializeTimeZones();
    final localTimezone = await FlutterTimezone.getLocalTimezone();
    tz.setLocalLocation(tz.getLocation(localTimezone.identifier));

    await _plugin.initialize(
      InitializationSettings(
        android: const AndroidInitializationSettings('@mipmap/ic_launcher'),
        iOS: DarwinInitializationSettings(
          notificationCategories: <DarwinNotificationCategory>[
            DarwinNotificationCategory(
              _channelId,
              actions: <DarwinNotificationAction>[
                DarwinNotificationAction.plain(
                  snoozeActionId,
                  'Snooze',
                  options: <DarwinNotificationActionOption>{
                    DarwinNotificationActionOption.foreground,
                  },
                ),
              ],
            ),
          ],
        ),
      ),
      onDidReceiveNotificationResponse: _onNotificationResponse,
    );
    _initialized = true;
  }

  Future<void> _onNotificationResponse(NotificationResponse response) async {
    final payload = response.payload;
    if (payload == null || payload.trim().isEmpty) return;
    if (response.actionId == snoozeActionId ||
        response.notificationResponseType ==
            NotificationResponseType.selectedNotificationAction) {
      await handleReminderSnooze(payload);
    }
  }

  /// When a reminder triggers for [timeSlot], calculates `remainingDosesCount`
  /// across all medications sharing that exact scheduled time slot and transitions
  /// the batch into a native snooze countdown via [LiveReminderService].
  Future<DoseBatch> handleReminderSnooze(
    String timeSlot, {
    List<Prescription>? prescriptions,
    List<Profile>? profiles,
    int? snoozeDurationMinutes,
  }) {
    return _liveReminderService.startSnoozeForTimeSlot(
      timeSlot: timeSlot,
      prescriptions: prescriptions ?? _currentPrescriptions,
      profiles: profiles ?? _currentProfiles,
      snoozeDurationMinutes: snoozeDurationMinutes,
    );
  }

  /// Requests every permission this app's notifications need on Android:
  /// `POST_NOTIFICATIONS` (13+, to show anything at all) and
  /// `SCHEDULE_EXACT_ALARM` (12+, for the precise timing medication
  /// reminders need -- exact, not approximate, was a deliberate choice).
  /// On iOS, requests the equivalent alert/sound/badge permission. Returns
  /// whether everything needed was granted.
  Future<bool> requestPermissions() async {
    await init();
    final android = _plugin
        .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();
    if (android != null) {
      final notifications = await android.requestNotificationsPermission() ?? false;
      final exactAlarms = await android.requestExactAlarmsPermission() ?? false;
      return notifications && exactAlarms;
    }

    final ios =
        _plugin.resolvePlatformSpecificImplementation<IOSFlutterLocalNotificationsPlugin>();
    final granted = await ios?.requestPermissions(alert: true, badge: true, sound: true);
    return granted ?? true;
  }

  /// Whether notifications can currently be shown at all. `true` on
  /// platforms (like iOS, pre-grant) where this isn't separately queryable
  /// -- `requestPermissions`'s return value is the real signal there.
  Future<bool> areNotificationsEnabled() async {
    final android = _plugin
        .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();
    if (android == null) return true;
    return await android.areNotificationsEnabled() ?? false;
  }

  /// Whether the exact-alarm grant is held. Always `true` on platforms
  /// without this concept (iOS, or Android versions below the restriction).
  Future<bool> hasExactAlarmPermission() async {
    final android = _plugin
        .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();
    if (android == null) return true;
    return await android.canScheduleExactNotifications() ?? false;
  }

  /// The one method everything else calls: reconciles every
  /// (prescription, reminderTime) pair against what should currently be
  /// scheduled, given each one's assigned profile's bedtime and the
  /// medication's own `allowAfterBedtime` override, then cancels everything
  /// and reschedules from scratch. A full reconcile on every call, not
  /// fine-grained create/update/delete diffing -- simplest correct
  /// strategy, and cheap at this app's scale (a handful of profiles and
  /// prescriptions, each with at most a few reminder times). Call this
  /// after any change to `prescriptions` or `profiles` (home_scaffold.dart's
  /// stream listeners do), and once on startup so a reboot that dropped
  /// Android's own scheduled alarms gets them back regardless of whether
  /// the plugin's own boot receiver fired.
  Future<void> syncAll(List<Prescription> prescriptions, List<Profile> profiles) async {
    _currentPrescriptions = List.unmodifiable(prescriptions);
    _currentProfiles = List.unmodifiable(profiles);
    await init();
    await _plugin.cancelAll();

    for (final prescription in prescriptions) {
      final profile = _profileFor(prescription.profileId, profiles);
      for (final time in prescription.reminderTimes) {
        final shouldSchedule = shouldScheduleReminder(
          time: time,
          bedtime: profile?.bedtime,
          allowAfterBedtime: prescription.allowAfterBedtime,
        );
        if (!shouldSchedule) continue;

        final scheduledDate = _nextInstanceOf(time);
        if (scheduledDate == null) continue; // unparseable time -- skip, don't crash the sync

        await _plugin.zonedSchedule(
          notificationIdFor(prescription.id, time),
          prescription.name,
          _bodyFor(prescription, profile),
          scheduledDate,
          const NotificationDetails(
            android: AndroidNotificationDetails(
              _channelId,
              _channelName,
              channelDescription: _channelDescription,
              actions: <AndroidNotificationAction>[
                AndroidNotificationAction(
                  snoozeActionId,
                  'Snooze',
                  showsUserInterface: true,
                ),
              ],
            ),
            iOS: DarwinNotificationDetails(
              categoryIdentifier: _channelId,
            ),
          ),
          androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
          uiLocalNotificationDateInterpretation:
              UILocalNotificationDateInterpretation.absoluteTime,
          // Daily repeat at this time-of-day -- the plugin/OS re-fires it
          // every day on its own; syncAll doesn't need to run on a timer.
          matchDateTimeComponents: DateTimeComponents.time,
          payload: time,
        );
      }
    }

    // Schedule Pre-Bedtime Final Call for each profile with a configured bedtime
    for (final profile in profiles) {
      final bedtime = profile.bedtime;
      if (bedtime == null) continue;

      final pendingCount = calculatePendingDosesBeforeBedtime(
        profile: profile,
        prescriptions: prescriptions,
      );
      if (pendingCount <= 0) continue;

      final triggerTod = calculatePreBedtimeNotificationTime(bedtime: bedtime);
      if (triggerTod == null) continue;

      final triggerDate = _nextInstanceOf(formatTimeOfDayLabel(triggerTod));
      if (triggerDate == null) continue;

      final message = formatPreBedtimeFinalCallMessage(
        pendingDosesCount: pendingCount,
        bedtime: bedtime,
      );

      await _plugin.zonedSchedule(
        notificationIdForPreBedtime(profile.id),
        'Bedtime Reminder',
        message,
        triggerDate,
        const NotificationDetails(
          android: AndroidNotificationDetails(
            _finalCallChannelId,
            _finalCallChannelName,
            channelDescription: _finalCallChannelDescription,
            importance: Importance.max,
            priority: Priority.high,
          ),
          iOS: DarwinNotificationDetails(
            categoryIdentifier: _channelId,
            interruptionLevel: InterruptionLevel.timeSensitive,
          ),
        ),
        androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
        uiLocalNotificationDateInterpretation:
            UILocalNotificationDateInterpretation.absoluteTime,
        matchDateTimeComponents: DateTimeComponents.time,
        payload: formatTimeOfDayLabel(triggerTod),
      );
    }
  }

  Profile? _profileFor(String id, List<Profile> profiles) {
    for (final p in profiles) {
      if (p.id == id) return p;
    }
    return null;
  }

  String _bodyFor(Prescription prescription, Profile? profile) {
    final parts = <String>[
      if (prescription.dosage.isNotEmpty) prescription.dosage,
      if (profile != null) 'for ${profile.name}',
    ];
    return parts.isEmpty ? 'Time to take this dose.' : 'Time to take ${parts.join(' ')}.';
  }

  /// The next real wall-clock [tz.TZDateTime] this time-of-day occurs --
  /// today if it hasn't passed yet, otherwise tomorrow. `zonedSchedule`
  /// requires a date in the future even for a daily-repeating notification;
  /// [DateTimeComponents.time] is what makes it actually repeat daily from
  /// there rather than firing once.
  tz.TZDateTime? _nextInstanceOf(String time) {
    final parsed = parseTimeOfDayLabel(time);
    if (parsed == null) return null;

    final now = tz.TZDateTime.now(tz.local);
    var scheduled = tz.TZDateTime(tz.local, now.year, now.month, now.day, parsed.hour, parsed.minute);
    if (scheduled.isBefore(now)) {
      scheduled = scheduled.add(const Duration(days: 1));
    }
    return scheduled;
  }
}
