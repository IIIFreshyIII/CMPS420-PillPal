import 'dart:async' show Timer;
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import '../core/scheduling/reminder_scheduler.dart';
import '../data/models/prescription.dart';
import '../data/models/profile.dart';
import 'bedtime_service.dart';
import 'snooze_settings_service.dart';

export '../core/scheduling/reminder_scheduler.dart'
    show
        DoseBatch,
        batchIdForTimeSlot,
        calculateBedtimeDateTime,
        calculateDoseBatch,
        calculateNextMorningReset,
        calculatePendingDosesBeforeBedtime,
        calculatePreBedtimeNotificationTime,
        calculateRemainingDosesCount,
        clampSnoozeDurationToBedtime,
        formatLeadTimeDuration,
        formatPreBedtimeFinalCallMessage,
        formatSnoozeNotificationBody,
        formatSnoozeNotificationTitle,
        isAtOrPastBedtime,
        isSameTimeSlot,
        notificationIdForPreBedtime,
        notificationIdForSnooze,
        shouldSuppressFollowUpNudgeForSnooze,
        timeUntilScheduledSlot;
export 'snooze_settings_service.dart';

/// Outcome of attempting to start a native snooze countdown / Live Activity.
enum SnoozeStartStatus {
  started,
  alreadyActive,
  blockedByBedtime,
  noPendingDoses,
  liveActivitiesDisabled,
  failed,
}

class SnoozeStartOutcome {
  const SnoozeStartOutcome({
    required this.status,
    this.batchId,
    this.snoozeEndTime,
    this.effectiveDurationMinutes = 0,
    this.clampedToBedtime = false,
    this.errorMessage,
  });

  final SnoozeStartStatus status;
  final String? batchId;
  final DateTime? snoozeEndTime;
  final int effectiveDurationMinutes;
  final bool clampedToBedtime;
  final String? errorMessage;

  bool get started => status == SnoozeStartStatus.started;
}

/// Native bridge service for managing persistent, real-time snooze countdowns
/// on iOS (ActivityKit / Dynamic Island Live Activity) and Android
/// (Ongoing `NotificationCompat.Builder` chronometer notification).
///
/// Follows the Zero Dart Background Loops rule: no Dart `Timer` or background
/// isolate tick is ever started. Instead, [startSnoozeActivity] computes the
/// target epoch millisecond timestamp (`snoozeEndTimestampMs`) and passes it
/// over the dedicated `com.pillpal.app/live_reminders` [MethodChannel] so the
/// native system compositors render decrementing countdowns autonomously.
class LiveReminderService extends ChangeNotifier {
  LiveReminderService({
    MethodChannel? channel,
    SnoozeSettingsService? snoozeSettings,
    BedtimeService? bedtimeService,
    DateTime Function()? clock,
  })  : _channel = channel ?? const MethodChannel(channelName),
        _snoozeSettings = snoozeSettings,
        _bedtimeService = bedtimeService,
        _clock = clock ?? DateTime.now;

  static const String channelName = 'com.pillpal.app/live_reminders';

  static final LiveReminderService instance = LiveReminderService();

  final MethodChannel _channel;
  final SnoozeSettingsService? _snoozeSettings;
  final BedtimeService? _bedtimeService;
  final DateTime Function() _clock;
  final Map<String, Timer> _bedtimeTimers = {};
  final Map<String, DateTime> _activeSnoozeEnds = {};
  SnoozeStartOutcome? _lastStartOutcome;

  /// Outcome of the most recent [startSnoozeActivity] or [startSnoozeForTimeSlot] call.
  SnoozeStartOutcome? get lastStartOutcome => _lastStartOutcome;

  /// Active (non-expired) snooze end timestamps keyed by `batchId`.
  Map<String, DateTime> get activeSnoozeEnds {
    final now = _clock();
    return Map.unmodifiable({
      for (final entry in _activeSnoozeEnds.entries)
        if (now.isBefore(entry.value)) entry.key: entry.value,
    });
  }

  /// Active snooze end timestamp for [timeSlot], or `null` if none is running
  /// or if the previously recorded countdown has already expired.
  DateTime? activeSnoozeEndForTimeSlot(String timeSlot) {
    final end = _activeSnoozeEnds[batchIdForTimeSlot(timeSlot)];
    if (end == null) return null;
    return _clock().isBefore(end) ? end : null;
  }

  /// True when a snooze countdown for [timeSlot]'s batch is currently active
  /// (`now.isBefore(endTime)`).
  bool isSnoozeActiveForTimeSlot(String timeSlot) =>
      activeSnoozeEndForTimeSlot(timeSlot) != null;

  /// Removes any locally expired snoozes and returns their `batchId`s.
  Set<String> pruneExpiredSnoozes() {
    final now = _clock();
    final expired = <String>{};
    _activeSnoozeEnds.removeWhere((batchId, endTime) {
      final isExpired = !now.isBefore(endTime);
      if (isExpired) {
        expired.add(batchId);
        _bedtimeTimers.remove(batchId)?.cancel();
      }
      return isExpired;
    });
    if (expired.isNotEmpty) {
      notifyListeners();
    }
    return expired;
  }

  /// Queries the native host (iOS ActivityKit + pending snooze notifications,
  /// or Android `LiveReminderManager`) on app resume so native cancellations
  /// made from the Lock Screen / Dynamic Island / notification shade stay in
  /// sync with Flutter UI state.
  ///
  /// Returns the set of `batchId`s that were previously active locally and are
  /// no longer active natively.
  Future<Set<String>> syncActiveSnoozesFromNative() async {
    final now = _clock();
    try {
      final raw = await _channel.invokeMethod<dynamic>('getActiveSnoozes');
      if (raw is! Map) {
        return pruneExpiredSnoozes();
      }

      final nativeActive = <String, DateTime>{};
      for (final entry in raw.entries) {
        final batchId = entry.key?.toString().trim() ?? '';
        final endMs = (entry.value is num) ? (entry.value as num).toInt() : null;
        if (batchId.isEmpty || endMs == null) continue;
        final endTime = DateTime.fromMillisecondsSinceEpoch(endMs);
        if (now.isBefore(endTime)) {
          nativeActive[batchId] = endTime;
        }
      }

      final removed = <String>{};
      var changed = false;
      for (final existingBatchId in _activeSnoozeEnds.keys.toList()) {
        if (!nativeActive.containsKey(existingBatchId)) {
          removed.add(existingBatchId);
          _activeSnoozeEnds.remove(existingBatchId);
          _bedtimeTimers.remove(existingBatchId)?.cancel();
          changed = true;
        }
      }

      for (final entry in nativeActive.entries) {
        final prev = _activeSnoozeEnds[entry.key];
        if (prev == null ||
            prev.millisecondsSinceEpoch != entry.value.millisecondsSinceEpoch) {
          _activeSnoozeEnds[entry.key] = entry.value;
          changed = true;
        }
      }

      if (changed) {
        notifyListeners();
      }
      return removed;
    } on MissingPluginException {
      return pruneExpiredSnoozes();
    } on PlatformException catch (e) {
      debugPrint('LiveReminderService.syncActiveSnoozesFromNative failed: ${e.message}');
      return pruneExpiredSnoozes();
    }
  }

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
    int? snoozeNotificationId,
    bool clampedToBedtime = false,
  }) async {
    final nowMs = _clock().millisecondsSinceEpoch;
    final effectiveEndMs =
        snoozeEndTimestampMs ?? (nowMs + (snoozeDurationMinutes * 60 * 1000));
    final snoozeEnd = DateTime.fromMillisecondsSinceEpoch(effectiveEndMs);

    try {
      await _channel.invokeMethod<void>('startSnoozeActivity', <String, dynamic>{
        'batchId': batchId,
        'snoozeDurationMinutes': snoozeDurationMinutes,
        'snoozeEndTimestampMs': effectiveEndMs,
        'remainingCount': remainingCount,
        'remainingDoseCount': remainingCount,
        'medicationNames': List<String>.from(medicationNames),
        'profileName': profileName,
        if (snoozeNotificationId != null)
          'snoozeNotificationId': snoozeNotificationId,
      });
      _activeSnoozeEnds[batchId] = snoozeEnd;
      _lastStartOutcome = SnoozeStartOutcome(
        status: SnoozeStartStatus.started,
        batchId: batchId,
        snoozeEndTime: snoozeEnd,
        effectiveDurationMinutes: snoozeDurationMinutes,
        clampedToBedtime: clampedToBedtime,
      );
      notifyListeners();
    } on MissingPluginException {
      // Safe no-op in unit/widget test environments without a native host.
      _activeSnoozeEnds[batchId] = snoozeEnd;
      _lastStartOutcome = SnoozeStartOutcome(
        status: SnoozeStartStatus.started,
        batchId: batchId,
        snoozeEndTime: snoozeEnd,
        effectiveDurationMinutes: snoozeDurationMinutes,
        clampedToBedtime: clampedToBedtime,
      );
      notifyListeners();
    } on PlatformException catch (e) {
      debugPrint('LiveReminderService.startSnoozeActivity failed: ${e.message}');
      final status = e.code == 'LIVE_ACTIVITIES_DISABLED'
          ? SnoozeStartStatus.liveActivitiesDisabled
          : SnoozeStartStatus.failed;
      // Notification-only snooze still runs when Live Activities are disabled
      // or unavailable, so track the active end time for the double-snooze guard.
      _activeSnoozeEnds[batchId] = snoozeEnd;
      _lastStartOutcome = SnoozeStartOutcome(
        status: status,
        batchId: batchId,
        snoozeEndTime: snoozeEnd,
        effectiveDurationMinutes: snoozeDurationMinutes,
        clampedToBedtime: clampedToBedtime,
        errorMessage: e.message ?? e.code,
      );
      notifyListeners();
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
    final removed = _activeSnoozeEnds.remove(batchId) != null;

    try {
      await _channel.invokeMethod<void>('dismissActivity', <String, dynamic>{
        'batchId': batchId,
      });
    } on MissingPluginException {
      // Safe no-op in unit/widget test environments without a native host.
    } on PlatformException catch (e) {
      debugPrint('LiveReminderService.dismissActivity failed: ${e.message}');
    }
    if (removed) {
      notifyListeners();
    }
  }

  /// Resolves the applicable profile bedtime string for a [DoseBatch].
  static String? resolveBedtimeForBatch({
    required DoseBatch batch,
    List<Profile>? profiles,
  }) {
    if (profiles == null || profiles.isEmpty) return null;
    final profileMap = {for (final p in profiles) p.id: p};
    final profileIds =
        batch.remainingPrescriptions.map((p) => p.profileId).toSet();
    String? profileBedtime;
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
    return profileBedtime ??
        profiles
            .firstWhere((p) => p.isPrimary, orElse: () => profiles.first)
            .bedtime;
  }

  /// Calculates the [DoseBatch] for all medications sharing [timeSlot] and,
  /// if any doses remain untaken, starts the native snooze countdown using
  /// either [snoozeDurationMinutes] or the persisted default snooze duration.
  ///
  /// Clamps the snooze countdown to end at the profile's bedtime blackout window
  /// unless [bypassBedtime] is `true` or bedtime quiet hours are paused tonight.
  /// If bedtime has arrived or passed (and not bypassed), dismisses the live countdown.
  Future<DoseBatch> startSnoozeForTimeSlot({
    required String timeSlot,
    required List<Prescription> prescriptions,
    List<Profile>? profiles,
    int? snoozeDurationMinutes,
    Set<String>? skippedSlotKeys,
    bool bypassBedtime = false,
  }) async {
    final now = _clock();
    final bedtimeService = _bedtimeService;
    final effectiveBypass = bypassBedtime ||
        (bedtimeService != null
            ? bedtimeService.isPausedAt(now)
            : (_snoozeSettings?.isBedtimeBypassed(now: now) ?? false));

    final batch = calculateDoseBatch(
      prescriptions,
      timeSlot,
      profiles: profiles,
      skippedSlotKeys: skippedSlotKeys,
      bypassBedtime: effectiveBypass,
      bedtimeSchedule: bedtimeService?.schedule,
      weekday: now.weekday,
    );

    if (batch.remainingDosesCount <= 0) {
      await dismissActivity(batchId: batch.batchId);
      _lastStartOutcome = SnoozeStartOutcome(
        status: SnoozeStartStatus.noPendingDoses,
        batchId: batch.batchId,
      );
      return batch;
    }

    // Double-snooze guard: if a snooze countdown for this batch is already
    // actively running (`now.isBefore(endTime)`), leave it undisturbed rather
    // than starting a duplicate timer.
    final existingEnd = _activeSnoozeEnds[batch.batchId];
    if (existingEnd != null && now.isBefore(existingEnd)) {
      final remainingMins = existingEnd.difference(now).inMinutes.clamp(1, 999);
      _lastStartOutcome = SnoozeStartOutcome(
        status: SnoozeStartStatus.alreadyActive,
        batchId: batch.batchId,
        snoozeEndTime: existingEnd,
        effectiveDurationMinutes: remainingMins,
      );
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

    final int clampedDuration;
    DateTime? targetBedtime;
    if (bedtimeService != null) {
      clampedDuration = bedtimeService.clampSnoozeMinutes(
        now: now,
        requestedMinutes: duration,
        bypassBedtime: effectiveBypass,
      );
      if (!effectiveBypass && bedtimeService.isEnabled) {
        targetBedtime = bedtimeService.nextQuietWindow(now: now)?.start;
      }
    } else {
      final profileBedtime = effectiveBypass
          ? null
          : resolveBedtimeForBatch(batch: batch, profiles: profiles);
      clampedDuration = effectiveBypass
          ? duration
          : clampSnoozeDurationToBedtime(
              now: now,
              requestedMinutes: duration,
              bedtime: profileBedtime,
            );
      if (profileBedtime != null) {
        targetBedtime =
            calculateBedtimeDateTime(now: now, bedtime: profileBedtime);
      }
    }

    if (clampedDuration <= 0) {
      await dismissActivity(batchId: batch.batchId);
      _lastStartOutcome = SnoozeStartOutcome(
        status: SnoozeStartStatus.blockedByBedtime,
        batchId: batch.batchId,
      );
      return batch;
    }

    int? endTimestampMs;
    var wasClamped = false;
    if (targetBedtime != null) {
      final requestedEnd = now.add(Duration(minutes: duration));
      if (requestedEnd.isAfter(targetBedtime)) {
        endTimestampMs = targetBedtime.millisecondsSinceEpoch;
        wasClamped = true;
      }
    }

    await startSnoozeActivity(
      batchId: batch.batchId,
      snoozeDurationMinutes: clampedDuration,
      remainingCount: batch.remainingDosesCount,
      medicationNames: batch.medicationNames,
      profileName: batch.profileName,
      snoozeEndTimestampMs: endTimestampMs,
      snoozeNotificationId: notificationIdForSnooze(timeSlot),
      clampedToBedtime: wasClamped,
    );

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

    return batch;
  }

  /// Reconciles an active time-slot batch after a dose is marked taken,
  /// untaken, skipped, or deleted: updates the native countdown when doses
  /// remain, or dismisses the activity once `remainingDosesCount` reaches 0.
  Future<DoseBatch> syncTimeSlotDoses({
    required String timeSlot,
    required List<Prescription> prescriptions,
    List<Profile>? profiles,
    Set<String>? skippedSlotKeys,
    bool bypassBedtime = false,
  }) async {
    final now = _clock();
    final bedtimeService = _bedtimeService;
    final effectiveBypass = bypassBedtime ||
        (bedtimeService != null
            ? bedtimeService.isPausedAt(now)
            : (_snoozeSettings?.isBedtimeBypassed(now: now) ?? false));
    final batch = calculateDoseBatch(
      prescriptions,
      timeSlot,
      profiles: profiles,
      skippedSlotKeys: skippedSlotKeys,
      bypassBedtime: effectiveBypass,
      bedtimeSchedule: bedtimeService?.schedule,
      weekday: now.weekday,
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
