import 'dart:async' show Timer;
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import '../core/scheduling/reminder_scheduler.dart';
import '../data/models/prescription.dart';
import '../data/models/profile.dart';
import 'snooze_settings_service.dart';

export '../core/scheduling/reminder_scheduler.dart'
    show
        DoseBatch,
        batchIdForTimeSlot,
        calculateBedtimeDateTime,
        calculateDoseBatch,
        calculatePendingDosesBeforeBedtime,
        calculatePreBedtimeNotificationTime,
        calculateRemainingDosesCount,
        clampSnoozeDurationToBedtime,
        formatPreBedtimeFinalCallMessage,
        isAtOrPastBedtime,
        isSameTimeSlot,
        notificationIdForPreBedtime;
export 'snooze_settings_service.dart';

/// Native bridge service for managing persistent, real-time snooze countdowns
/// on iOS (ActivityKit / Dynamic Island Live Activity) and Android
/// (Ongoing `NotificationCompat.Builder` chronometer notification).
///
/// Follows the Zero Dart Background Loops rule: no Dart `Timer` or background
/// isolate tick is ever started. Instead, [startSnoozeActivity] computes the
/// target epoch millisecond timestamp (`snoozeEndTimestampMs`) and passes it
/// over the dedicated `com.pillpal.app/live_reminders` [MethodChannel] so the
/// native system compositors render decrementing countdowns autonomously.
class LiveReminderService {
  LiveReminderService({
    MethodChannel? channel,
    SnoozeSettingsService? snoozeSettings,
    DateTime Function()? clock,
  })  : _channel = channel ?? const MethodChannel(channelName),
        _snoozeSettings = snoozeSettings,
        _clock = clock ?? DateTime.now;

  static const String channelName = 'com.pillpal.app/live_reminders';

  static final LiveReminderService instance = LiveReminderService();

  final MethodChannel _channel;
  final SnoozeSettingsService? _snoozeSettings;
  final DateTime Function() _clock;
  final Map<String, Timer> _bedtimeTimers = {};

  /// Optional callback invoked when the native iOS Live Activity or Android
  /// Ongoing Notification triggers an action back into Flutter.
  Future<void> Function(String action, Map<String, dynamic> payload)?
      onNativeAction;

  /// Attaches a method call handler to receive native reminder actions
  /// (such as "markAllTaken", "snoozeAgain", or "dismiss") over the channel.
  void registerNativeCallbackHandler() {
    _channel.setMethodCallHandler((MethodCall call) async {
      final handler = onNativeAction;
      if (handler == null) return null;
      final args = call.arguments is Map
          ? Map<String, dynamic>.from(call.arguments as Map)
          : <String, dynamic>{};
      await handler(call.method, args);
      return true;
    });
  }

  /// Starts a persistent native snooze countdown for a dose batch.
  ///
  /// Computes `snoozeEndTimestampMs` from the current epoch time plus
  /// [snoozeDurationMinutes] (or uses explicit [snoozeEndTimestampMs]) and sends
  /// it across `com.pillpal.app/live_reminders` without starting any continuous
  /// Dart-side tick loops.
  Future<void> startSnoozeActivity({
    required String batchId,
    required int snoozeDurationMinutes,
    required int remainingCount,
    List<String> medicationNames = const [],
    String? profileName,
    int? snoozeEndTimestampMs,
  }) async {
    final nowMs = _clock().millisecondsSinceEpoch;
    final effectiveEndMs =
        snoozeEndTimestampMs ?? (nowMs + (snoozeDurationMinutes * 60 * 1000));

    try {
      await _channel.invokeMethod<void>('startSnoozeActivity', <String, dynamic>{
        'batchId': batchId,
        'snoozeDurationMinutes': snoozeDurationMinutes,
        'snoozeEndTimestampMs': effectiveEndMs,
        'remainingCount': remainingCount,
        'remainingDoseCount': remainingCount,
        'medicationNames': List<String>.from(medicationNames),
        'profileName': profileName,
      });
    } on MissingPluginException {
      // Safe no-op in unit/widget test environments without a native host.
    } on PlatformException catch (e) {
      debugPrint('LiveReminderService.startSnoozeActivity failed: ${e.message}');
    }
  }

  /// Updates an active native snooze countdown with the latest [remainingCount],
  /// [medicationNames], and [profileName] for [batchId].
  Future<void> updateRemainingDoses({
    required String batchId,
    required int remainingCount,
    List<String> medicationNames = const [],
    String? profileName,
  }) async {
    try {
      await _channel.invokeMethod<void>('updateRemainingDoses', <String, dynamic>{
        'batchId': batchId,
        'remainingCount': remainingCount,
        'remainingDoseCount': remainingCount,
        'medicationNames': List<String>.from(medicationNames),
        'profileName': profileName,
      });
    } on MissingPluginException {
      // Safe no-op in unit/widget test environments without a native host.
    } on PlatformException catch (e) {
      debugPrint('LiveReminderService.updateRemainingDoses failed: ${e.message}');
    }
  }

  /// Immediately dismisses/ends the native Live Activity or Ongoing Notification
  /// associated with [batchId].
  Future<void> dismissActivity({
    required String batchId,
  }) async {
    _bedtimeTimers[batchId]?.cancel();
    _bedtimeTimers.remove(batchId);

    try {
      await _channel.invokeMethod<void>('dismissActivity', <String, dynamic>{
        'batchId': batchId,
      });
    } on MissingPluginException {
      // Safe no-op in unit/widget test environments without a native host.
    } on PlatformException catch (e) {
      debugPrint('LiveReminderService.dismissActivity failed: ${e.message}');
    }
  }

  /// Calculates the [DoseBatch] for all medications sharing [timeSlot] and,
  /// if any doses remain untaken, starts the native snooze countdown using
  /// either [snoozeDurationMinutes] or the persisted default snooze duration.
  ///
  /// Clamps the snooze countdown to end at the profile's bedtime blackout window.
  /// If bedtime has arrived or passed, dismisses the live countdown.
  Future<DoseBatch> startSnoozeForTimeSlot({
    required String timeSlot,
    required List<Prescription> prescriptions,
    List<Profile>? profiles,
    int? snoozeDurationMinutes,
  }) async {
    final batch = calculateDoseBatch(
      prescriptions,
      timeSlot,
      profiles: profiles,
    );

    if (batch.remainingDosesCount <= 0) {
      await dismissActivity(batchId: batch.batchId);
      return batch;
    }

    int duration = snoozeDurationMinutes ??
        _snoozeSettings?.snoozeDurationMinutes ??
        SnoozeSettingsService.defaultSnoozeDurationMinutes;
    if (snoozeDurationMinutes == null && _snoozeSettings == null) {
      final settings = SnoozeSettingsService();
      await settings.load();
      duration = settings.snoozeDurationMinutes;
    }

    // Determine profile bedtime for clamping
    String? profileBedtime;
    if (profiles != null && profiles.isNotEmpty) {
      final profileMap = {for (final p in profiles) p.id: p};
      final profileIds =
          batch.remainingPrescriptions.map((p) => p.profileId).toSet();
      if (profileIds.length == 1) {
        profileBedtime = profileMap[profileIds.first]?.bedtime;
      } else if (profileIds.isNotEmpty) {
        final matchingProfiles =
            profileIds.map((id) => profileMap[id]).whereType<Profile>();
        final withBedtime = matchingProfiles.where((p) => p.bedtime != null);
        if (withBedtime.isNotEmpty) {
          profileBedtime = withBedtime.first.bedtime;
        }
      }
      profileBedtime ??= profiles
          .firstWhere((p) => p.isPrimary, orElse: () => profiles.first)
          .bedtime;
    }

    final now = _clock();
    final clampedDuration = clampSnoozeDurationToBedtime(
      now: now,
      requestedMinutes: duration,
      bedtime: profileBedtime,
    );

    if (clampedDuration <= 0) {
      await dismissActivity(batchId: batch.batchId);
      return batch;
    }

    int? endTimestampMs;
    if (profileBedtime != null) {
      final targetBedtime =
          calculateBedtimeDateTime(now: now, bedtime: profileBedtime);
      if (targetBedtime != null) {
        final requestedEnd = now.add(Duration(minutes: duration));
        if (requestedEnd.isAfter(targetBedtime)) {
          endTimestampMs = targetBedtime.millisecondsSinceEpoch;
        }
      }
    }

    await startSnoozeActivity(
      batchId: batch.batchId,
      snoozeDurationMinutes: clampedDuration,
      remainingCount: batch.remainingDosesCount,
      medicationNames: batch.medicationNames,
      profileName: batch.profileName,
      snoozeEndTimestampMs: endTimestampMs,
    );

    if (profileBedtime != null) {
      final targetBedtime =
          calculateBedtimeDateTime(now: now, bedtime: profileBedtime);
      if (targetBedtime != null) {
        final diffMs = targetBedtime.difference(now).inMilliseconds;
        _bedtimeTimers[batch.batchId]?.cancel();
        if (diffMs > 0) {
          _bedtimeTimers[batch.batchId] =
              Timer(Duration(milliseconds: diffMs), () {
            dismissActivity(batchId: batch.batchId);
          });
        }
      }
    }

    return batch;
  }

  /// Reconciles an active time-slot batch after a dose is marked taken or
  /// untaken: updates the native countdown when doses remain, or dismisses
  /// the activity once `remainingDosesCount` reaches 0.
  Future<DoseBatch> syncTimeSlotDoses({
    required String timeSlot,
    required List<Prescription> prescriptions,
    List<Profile>? profiles,
  }) async {
    final batch = calculateDoseBatch(
      prescriptions,
      timeSlot,
      profiles: profiles,
    );

    if (batch.remainingDosesCount <= 0) {
      await dismissActivity(batchId: batch.batchId);
    } else {
      await updateRemainingDoses(
        batchId: batch.batchId,
        remainingCount: batch.remainingDosesCount,
        medicationNames: batch.medicationNames,
        profileName: batch.profileName,
      );
    }
    return batch;
  }
}
