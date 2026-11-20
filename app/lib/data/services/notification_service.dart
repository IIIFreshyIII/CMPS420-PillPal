import 'dart:io' show Platform;

import 'package:flutter/services.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:timezone/data/latest.dart' as tz_data;
import 'package:timezone/timezone.dart' as tz;

import '../../core/scheduling/reminder_scheduler.dart';
import '../../core/utils/date_formatter.dart';
import '../../services/live_reminder_service.dart';
import '../models/prescription.dart';
import '../models/profile.dart';

const String _pendingNotifActionsPrefsKey = 'pillpal_pending_notif_actions';

/// Background entry point required by `flutter_local_notifications` when a
/// notification action button is tapped while the app is terminated.
@pragma('vm:entry-point')
Future<void> notificationTapBackground(NotificationResponse response) async {
  final payload = response.payload?.trim() ?? '';
  final actionId = response.actionId ?? '';
  if (payload.isEmpty || actionId.isEmpty) return;

  try {
    final prefs = await SharedPreferences.getInstance();
    final existing = prefs.getStringList(_pendingNotifActionsPrefsKey) ?? <String>[];
    existing.add('$actionId|$payload');
    await prefs.setStringList(_pendingNotifActionsPrefsKey, existing);
  } catch (_) {}
}

/// Wraps `flutter_local_notifications` behind the one thing the rest of the
/// app actually needs: keep every routine's 3-touch reminder system and app
/// icon badge count in sync with the database.
///
/// Strict privacy outside the app: zero medication names or dosages are ever
/// placed in notification titles, bodies, or payloads.
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
  Set<String> _currentSkippedSlotKeys = const {};
  final Map<
      String,
      ({
        String timeSlot,
        DateTime fireAt,
        int remainingCount,
        String? profileName,
      })> _activeSnoozeNotifications = {};

  static const MethodChannel _badgeChannel = MethodChannel('com.pillpal.app/badge');

  /// Optional foreground callback invoked when the user taps [logAllTakenActionId]
  /// from a notification banner. Registered by `HomeScaffold`.
  static Future<void> Function(String timeSlot)? onLogAllTaken;

  static const _channelId = 'dose_reminders';
  static const _channelName = 'Dose Reminders';
  static const _channelDescription = 'Consolidated reminders for each medication routine.';

  static const _followUpChannelId = 'dose_followup_nudge';
  static const _followUpChannelName = 'Follow-Up Nudges';
  static const _followUpChannelDescription =
      'Gentle 1-hour follow-up reminder when doses remain unlogged.';

  static const _finalCallChannelId = 'bedtime_final_call';
  static const _finalCallChannelName = 'Pre-Bedtime Final Call';
  static const _finalCallChannelDescription =
      'High-priority reminder for pending doses before bedtime.';

  static const _snoozeChannelId = 'dose_snooze_reminders';
  static const _snoozeChannelName = 'Snooze Reminders';
  static const _snoozeChannelDescription =
      'Follow-up alert when a snoozed dose countdown completes.';

  static const logAllTakenActionId = 'log_all_taken';
  static const snoozeActionId = 'snooze_dose_reminder';

  Future<void> init() async {
    if (_initialized) return;

    tz_data.initializeTimeZones();
    final localTimezone = await FlutterTimezone.getLocalTimezone();
    tz.setLocalLocation(tz.getLocation(localTimezone.identifier));

    final categories = <DarwinNotificationCategory>[
      DarwinNotificationCategory(
        _channelId,
        actions: <DarwinNotificationAction>[
          DarwinNotificationAction.plain(
            logAllTakenActionId,
            'Log All Taken',
          ),
          DarwinNotificationAction.plain(
            snoozeActionId,
            'Snooze',
          ),
        ],
      ),
    ];

    await _plugin.initialize(
      InitializationSettings(
        android: const AndroidInitializationSettings('@mipmap/ic_launcher'),
        iOS: DarwinInitializationSettings(
          notificationCategories: categories,
        ),
      ),
      onDidReceiveNotificationResponse: _onNotificationResponse,
      onDidReceiveBackgroundNotificationResponse: notificationTapBackground,
    );
    _initialized = true;
  }

  /// Drains any notification action taps queued while the app was terminated.
  Future<List<({String actionId, String timeSlot})>> drainPendingActions() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final list = prefs.getStringList(_pendingNotifActionsPrefsKey) ?? const <String>[];
      if (list.isEmpty) return const [];
      await prefs.remove(_pendingNotifActionsPrefsKey);
      final parsed = <({String actionId, String timeSlot})>[];
      for (final item in list) {
        final idx = item.indexOf('|');
        if (idx <= 0 || idx >= item.length - 1) continue;
        parsed.add((
          actionId: item.substring(0, idx),
          timeSlot: item.substring(idx + 1),
        ));
      }
      return parsed;
    } catch (_) {
      return const [];
    }
  }

  Future<void> _onNotificationResponse(NotificationResponse response) async {
    final payload = response.payload;
    if (payload == null || payload.trim().isEmpty) return;

    if (response.actionId == logAllTakenActionId) {
      if (onLogAllTaken != null) {
        await onLogAllTaken!(payload);
      } else {
        await _liveReminderService.dismissActivity(
          batchId: batchIdForTimeSlot(payload),
        );
      }
      return;
    }

    if (response.actionId == snoozeActionId ||
        response.notificationResponseType ==
            NotificationResponseType.selectedNotificationAction) {
      await handleReminderSnooze(payload);
    }
  }

  /// When a reminder triggers for [timeSlot], calculates `remainingDosesCount`
  /// across all medications sharing that exact scheduled time slot, transitions
  /// the batch into a native snooze countdown via [LiveReminderService], and
  /// schedules a one-shot follow-up push notification for when the snooze ends.
  Future<DoseBatch> handleReminderSnooze(
    String timeSlot, {
    List<Prescription>? prescriptions,
    List<Profile>? profiles,
    int? snoozeDurationMinutes,
    bool bypassBedtime = false,
  }) async {
    final batch = await _liveReminderService.startSnoozeForTimeSlot(
      timeSlot: timeSlot,
      prescriptions: prescriptions ?? _currentPrescriptions,
      profiles: profiles ?? _currentProfiles,
      snoozeDurationMinutes: snoozeDurationMinutes,
      skippedSlotKeys: _currentSkippedSlotKeys,
      bypassBedtime: bypassBedtime,
    );
    final outcome = _liveReminderService.lastStartOutcome;
    if (outcome != null &&
        outcome.snoozeEndTime != null &&
        batch.remainingDosesCount > 0 &&
        (outcome.status == SnoozeStartStatus.started ||
            outcome.status == SnoozeStartStatus.liveActivitiesDisabled)) {
      await scheduleSnoozeNotification(
        timeSlot: timeSlot,
        fireAt: outcome.snoozeEndTime!,
        remainingCount: batch.remainingDosesCount,
        profileName: batch.profileName,
      );
    }
    return batch;
  }

  /// Schedules a single one-shot push notification when a snooze countdown ends.
  /// Strictly privacy-safe (zero drug names or dosages).
  Future<void> scheduleSnoozeNotification({
    required String timeSlot,
    required DateTime fireAt,
    required int remainingCount,
    String? profileName,
  }) async {
    if (remainingCount <= 0) {
      await cancelSnoozeNotification(timeSlot);
      return;
    }

    final batchId = batchIdForTimeSlot(timeSlot);
    _activeSnoozeNotifications[batchId] = (
      timeSlot: timeSlot,
      fireAt: fireAt,
      remainingCount: remainingCount,
      profileName: profileName,
    );

    try {
      await init();
      final scheduledTz = tz.TZDateTime.from(fireAt, tz.local);
      final now = tz.TZDateTime.now(tz.local);
      if (!scheduledTz.isAfter(now)) return;

      const routineActions = <AndroidNotificationAction>[
        AndroidNotificationAction(
          logAllTakenActionId,
          'Log All Taken',
          showsUserInterface: false,
        ),
        AndroidNotificationAction(
          snoozeActionId,
          'Snooze',
          showsUserInterface: true,
        ),
      ];

      await _plugin.zonedSchedule(
        notificationIdForSnooze(timeSlot),
        formatSnoozeNotificationTitle(timeSlot),
        formatSnoozeNotificationBody(
          remainingCount: remainingCount,
          timeSlot: timeSlot,
          profileName: profileName,
        ),
        scheduledTz,
        NotificationDetails(
          android: const AndroidNotificationDetails(
            _snoozeChannelId,
            _snoozeChannelName,
            channelDescription: _snoozeChannelDescription,
            importance: Importance.high,
            priority: Priority.high,
            actions: routineActions,
          ),
          iOS: DarwinNotificationDetails(
            categoryIdentifier: _channelId,
            interruptionLevel: InterruptionLevel.timeSensitive,
            badgeNumber: remainingCount,
          ),
        ),
        androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
        uiLocalNotificationDateInterpretation:
            UILocalNotificationDateInterpretation.absoluteTime,
        payload: timeSlot,
      );
    } catch (_) {
      // Safe no-op in widget/unit test environments without native plugin host.
    }
  }

  /// Cancels any pending snooze completion notification for [timeSlot].
  Future<void> cancelSnoozeNotification(String timeSlot) async {
    _activeSnoozeNotifications.remove(batchIdForTimeSlot(timeSlot));
    try {
      await init();
      await _plugin.cancel(notificationIdForSnooze(timeSlot));
    } catch (_) {
      // Safe no-op in widget/unit test environments without native plugin host.
    }
  }

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

  Future<bool> areNotificationsEnabled() async {
    final android = _plugin
        .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();
    if (android != null) {
      return await android.areNotificationsEnabled() ?? false;
    }
    final ios = _plugin
        .resolvePlatformSpecificImplementation<IOSFlutterLocalNotificationsPlugin>();
    if (ios != null) {
      final perms = await ios.checkPermissions();
      return perms?.isEnabled ?? false;
    }
    return true;
  }

  Future<bool> hasExactAlarmPermission() async {
    final android = _plugin
        .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();
    if (android == null) return true;
    return await android.canScheduleExactNotifications() ?? false;
  }

  /// Reconciles all 3 touches of PillPal's consolidated notification engine:
  /// - Touch 1: 1 consolidated alert per routine time slot (zero drug names).
  /// - Touch 2: 1-hour follow-up nudge if pending doses remain before bedtime.
  /// - Touch 3: Pre-bedtime final call 10 minutes before each profile's bedtime.
  /// Also updates the iOS app icon red badge count to reflect currently due
  /// pending doses.
  Future<void> syncAll(
    List<Prescription> prescriptions,
    List<Profile> profiles, {
    Set<String> skippedSlotKeys = const {},
    Map<String, DateTime> activeSnoozeEnds = const {},
    bool bypassBedtime = false,
  }) async {
    _currentPrescriptions = List.unmodifiable(prescriptions);
    _currentProfiles = List.unmodifiable(profiles);
    _currentSkippedSlotKeys = Set.unmodifiable(skippedSlotKeys);
    await init();
    await _plugin.cancelAll();

    final now = tz.TZDateTime.now(tz.local);
    final duePendingCount = calculateDuePendingDosesCount(
      prescriptions,
      profiles,
      now: now,
      skippedSlotKeys: skippedSlotKeys,
    );
    await _updateAppBadgeCount(duePendingCount);

    final plans = buildConsolidatedSlotPlans(
      prescriptions,
      profiles,
      skippedSlotKeys: skippedSlotKeys,
      bypassBedtime: bypassBedtime,
    );
    final plansByBatchId = {for (final p in plans) p.batchId: p};

    const routineActions = <AndroidNotificationAction>[
      AndroidNotificationAction(
        logAllTakenActionId,
        'Log All Taken',
        showsUserInterface: false,
      ),
      AndroidNotificationAction(
        snoozeActionId,
        'Snooze',
        showsUserInterface: true,
      ),
    ];

    for (final plan in plans) {
      // Touch 1: Initial Consolidated Routine Alert
      var scheduledDate = _nextInstanceOf(plan.timeSlot);
      if (scheduledDate == null) continue;

      final isScheduledToday = scheduledDate.year == now.year &&
          scheduledDate.month == now.month &&
          scheduledDate.day == now.day;
      if (isScheduledToday && plan.remainingCount == 0) {
        // Today's doses for this slot are already taken or skipped;
        // start daily repeat tomorrow instead of nagging today.
        scheduledDate = scheduledDate.add(const Duration(days: 1));
      }

      final projectedBadge = duePendingCount +
          (plan.remainingCount > 0 ? plan.remainingCount : plan.scheduledCount);

      await _plugin.zonedSchedule(
        notificationIdForTimeSlot(plan.timeSlot),
        formatRoutineNotificationTitle(plan),
        formatRoutineNotificationBody(
          plan,
          useRemainingCounts: isScheduledToday && plan.remainingCount > 0,
        ),
        scheduledDate,
        NotificationDetails(
          android: const AndroidNotificationDetails(
            _channelId,
            _channelName,
            channelDescription: _channelDescription,
            actions: routineActions,
          ),
          iOS: DarwinNotificationDetails(
            categoryIdentifier: _channelId,
            badgeNumber: projectedBadge,
          ),
        ),
        androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
        uiLocalNotificationDateInterpretation:
            UILocalNotificationDateInterpretation.absoluteTime,
        matchDateTimeComponents: DateTimeComponents.time,
        payload: plan.timeSlot,
      );

      // Touch 2: 1-Hour Follow-Up Nudge
      if (plan.allowFollowUpNudge) {
        final nudgeTod = calculateFollowUpNudgeTime(plan.timeSlot);
        if (nudgeTod != null) {
          var nudgeDate = _nextInstanceOf(formatTimeOfDayLabel(nudgeTod));
          if (nudgeDate != null) {
            final nudgeIsToday = nudgeDate.year == now.year &&
                nudgeDate.month == now.month &&
                nudgeDate.day == now.day;
            final activeSnoozeEnd = activeSnoozeEnds[plan.batchId] ??
                _activeSnoozeNotifications[plan.batchId]?.fireAt;
            final suppressForSnooze = nudgeIsToday &&
                shouldSuppressFollowUpNudgeForSnooze(
                  nudgeTime: nudgeDate,
                  activeSnoozeEnd: activeSnoozeEnd,
                );
            if (nudgeIsToday && (plan.remainingCount == 0 || suppressForSnooze)) {
              nudgeDate = nudgeDate.add(const Duration(days: 1));
            }

            await _plugin.zonedSchedule(
              notificationIdForFollowUpNudge(plan.timeSlot),
              formatFollowUpNudgeTitle(plan),
              formatFollowUpNudgeBody(
                plan,
                useRemainingCount: nudgeIsToday && plan.remainingCount > 0,
              ),
              nudgeDate,
              NotificationDetails(
                android: const AndroidNotificationDetails(
                  _followUpChannelId,
                  _followUpChannelName,
                  channelDescription: _followUpChannelDescription,
                  actions: routineActions,
                ),
                iOS: DarwinNotificationDetails(
                  categoryIdentifier: _channelId,
                  badgeNumber: projectedBadge,
                ),
              ),
              androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
              uiLocalNotificationDateInterpretation:
                  UILocalNotificationDateInterpretation.absoluteTime,
              matchDateTimeComponents: DateTimeComponents.time,
              payload: plan.timeSlot,
            );
          }
        }
      }
    }

    // Touch 3: Pre-Bedtime Final Call per profile with configured bedtime
    for (final profile in profiles) {
      final bedtime = profile.bedtime;
      if (bedtime == null) continue;

      final scheduledCount = calculateScheduledDosesBeforeBedtime(
        profile: profile,
        prescriptions: prescriptions,
      );
      if (scheduledCount <= 0) continue;

      final pendingCount = calculatePendingDosesBeforeBedtime(
        profile: profile,
        prescriptions: prescriptions,
        skippedSlotKeys: skippedSlotKeys,
      );

      final triggerTod = calculatePreBedtimeNotificationTime(bedtime: bedtime);
      if (triggerTod == null) continue;

      var triggerDate = _nextInstanceOf(formatTimeOfDayLabel(triggerTod));
      if (triggerDate == null) continue;

      final isToday = triggerDate.year == now.year &&
          triggerDate.month == now.month &&
          triggerDate.day == now.day;
      if (isToday && pendingCount == 0) {
        triggerDate = triggerDate.add(const Duration(days: 1));
      }

      final displayCount = isToday && pendingCount > 0 ? pendingCount : scheduledCount;
      final message = formatPreBedtimeFinalCallMessage(
        pendingDosesCount: displayCount,
        bedtime: bedtime,
      );

      await _plugin.zonedSchedule(
        notificationIdForPreBedtime(profile.id),
        'Bedtime Final Call',
        message,
        triggerDate,
        NotificationDetails(
          android: const AndroidNotificationDetails(
            _finalCallChannelId,
            _finalCallChannelName,
            channelDescription: _finalCallChannelDescription,
            importance: Importance.max,
            priority: Priority.high,
          ),
          iOS: DarwinNotificationDetails(
            interruptionLevel: InterruptionLevel.timeSensitive,
            badgeNumber: duePendingCount > 0 ? duePendingCount : displayCount,
          ),
        ),
        androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
        uiLocalNotificationDateInterpretation:
            UILocalNotificationDateInterpretation.absoluteTime,
        matchDateTimeComponents: DateTimeComponents.time,
        payload: 'pre_bedtime:${profile.id}',
      );
    }

    // Re-schedule any still-pending, still-future snooze alerts after cancelAll()
    // and prune completed or expired snooze entries.
    final pendingSnoozes = Map.of(_activeSnoozeNotifications);
    for (final entry in pendingSnoozes.entries) {
      final batchId = entry.key;
      final snooze = entry.value;
      final plan = plansByBatchId[batchId];
      final fireAtTz = tz.TZDateTime.from(snooze.fireAt, tz.local);
      if (plan == null || plan.remainingCount <= 0 || !fireAtTz.isAfter(now)) {
        _activeSnoozeNotifications.remove(batchId);
        continue;
      }
      await scheduleSnoozeNotification(
        timeSlot: snooze.timeSlot,
        fireAt: snooze.fireAt,
        remainingCount: plan.remainingCount,
        profileName: snooze.profileName,
      );
    }
  }

  Future<void> _updateAppBadgeCount(int count) async {
    if (!Platform.isIOS) return;
    try {
      await _badgeChannel.invokeMethod<void>(
        'setBadgeCount',
        <String, dynamic>{'count': count < 0 ? 0 : count},
      );
    } catch (_) {}
  }

  tz.TZDateTime? _nextInstanceOf(String time) {
    final parsed = parseTimeOfDayLabel(time);
    if (parsed == null) return null;

    final now = tz.TZDateTime.now(tz.local);
    var scheduled = tz.TZDateTime(
      tz.local,
      now.year,
      now.month,
      now.day,
      parsed.hour,
      parsed.minute,
    );
    if (scheduled.isBefore(now)) {
      scheduled = scheduled.add(const Duration(days: 1));
    }
    return scheduled;
  }
}
