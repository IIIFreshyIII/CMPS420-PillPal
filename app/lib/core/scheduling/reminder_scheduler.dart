import 'package:flutter/material.dart' show TimeOfDay;

import '../../data/models/prescription.dart';
import '../../data/models/profile.dart';
import '../utils/date_formatter.dart' show formatTimeOfDayLabel, parseTimeOfDayLabel;

/// Converts a label's free-text frequency into a fixed hourly repeat
/// interval, when the phrase actually describes one. Returns `null` for
/// anything that doesn't -- "as needed", "with meals", "weekly", "every
/// other day", etc. have no fixed interval, and this never guesses one.
///
/// Recognizes the periodic phrasings the NER model is trained to extract
/// (see `distill/label_generator.py`'s `FREQ` list): explicit hour
/// intervals ("every 4 hours", "every 4 to 6 hours", "q6h") and
/// count-per-day phrasings ("once/twice/three times/four times daily",
/// "BID"/"TID"/"QID", "N times a/per day"), converting the latter into an
/// hour interval via `24 ~/ count` -- so "once daily" naturally yields just
/// one dose a day, since a 24-hour interval never repeats within a day.
int? parseFrequencyIntervalHours(String? frequency) {
  if (frequency == null) return null;
  final text = frequency.trim().toLowerCase();
  if (text.isEmpty) return null;

  final everyHours = RegExp(r'every\s+(\d+)(?:\s*(?:to|-)\s*\d+)?\s*hours?').firstMatch(text);
  if (everyHours != null) return int.parse(everyHours.group(1)!);

  final qnh = RegExp(r'\bq\s*(\d+)\s*h\b').firstMatch(text);
  if (qnh != null) return int.parse(qnh.group(1)!);

  final numberedTimes = RegExp(r'\b(\d+)\s*times?\s*(?:a|per)\s*day\b').firstMatch(text);
  if (numberedTimes != null) {
    final count = int.parse(numberedTimes.group(1)!);
    return count > 0 ? 24 ~/ count : null;
  }

  const countWords = {'once': 1, 'twice': 2, 'three times': 3, 'four times': 4};
  for (final entry in countWords.entries) {
    if (text.contains('${entry.key} daily') || text.contains('${entry.key} a day')) {
      return 24 ~/ entry.value;
    }
  }

  const abbreviations = {'bid': 2, 'tid': 3, 'qid': 4, 'qd': 1};
  if (abbreviations.containsKey(text)) return 24 ~/ abbreviations[text]!;

  if (text == 'daily' || text == 'every day') return 24;

  return null;
}

/// Always includes [startTime]; when [intervalHours] is non-null, repeats
/// every that many hours until the next one would land on or after
/// [bedtime] (end-of-day/midnight when the profile has no bedtime set) or
/// wrap past midnight. Hard-capped at 6 generated times as a defensive
/// backstop against a pathological interval.
List<TimeOfDay> buildReminderTimes({
  required TimeOfDay startTime,
  int? intervalHours,
  TimeOfDay? bedtime,
}) {
  final times = <TimeOfDay>[startTime];
  if (intervalHours == null || intervalHours <= 0) return times;

  final bedtimeMinutes = bedtime != null ? bedtime.hour * 60 + bedtime.minute : 24 * 60;
  var minutesSinceMidnight = startTime.hour * 60 + startTime.minute;

  while (times.length < 6) {
    minutesSinceMidnight += intervalHours * 60;
    if (minutesSinceMidnight >= 24 * 60) break; // wrapped past midnight
    if (minutesSinceMidnight >= bedtimeMinutes) break; // at/after bedtime
    times.add(TimeOfDay(hour: minutesSinceMidnight ~/ 60, minute: minutesSinceMidnight % 60));
  }
  return times;
}

/// False when this specific reminder [time] should NOT actually be
/// scheduled as a notification -- it falls at/after the assigned profile's
/// [bedtime] and this medication hasn't been given the after-bedtime
/// override ([allowAfterBedtime]). A missing [bedtime], the override being
/// on, or either time failing to parse all default to `true` (schedule it)
/// -- the safer failure mode for a medication reminder is over-notifying,
/// never silently dropping a dose reminder.
///
/// Known limitation, confirmed on-device, not just theoretical: both
/// [time] and [bedtime] are compared as plain minutes-since-midnight, which
/// assumes an evening bedtime (the normal case -- e.g. bedtime 10:00 PM
/// correctly blocks an 11:00 PM reminder and allows an 8:00 AM one). A
/// bedtime set to an early-morning hour (e.g. 12:45 AM) instead reads as
/// "blocked until just before midnight the *next* night," which silently
/// suppresses every reminder for the rest of that calendar day -- there's
/// no separate "wake time" concept to bound the quiet window the other
/// way. Not fixed here: the correct behavior for a past-midnight bedtime
/// is a genuine product question (it needs a wake-time input to answer),
/// not a one-line bug fix.
bool shouldScheduleReminder({
  required String time,
  required String? bedtime,
  required bool allowAfterBedtime,
}) {
  if (allowAfterBedtime || bedtime == null) return true;
  final reminderTod = parseTimeOfDayLabel(time);
  final bedtimeTod = parseTimeOfDayLabel(bedtime);
  if (reminderTod == null || bedtimeTod == null) return true;
  final reminderMinutes = reminderTod.hour * 60 + reminderTod.minute;
  final bedtimeMinutes = bedtimeTod.hour * 60 + bedtimeTod.minute;
  return reminderMinutes < bedtimeMinutes;
}

/// Deterministic, stable across app runs -- the same (prescriptionId, time)
/// pair always maps to the same Android notification id, so re-syncing
/// never creates duplicates and canceling always finds the right one.
///
/// Deliberately NOT `Object.hash` -- confirmed empirically (not assumed)
/// that Dart salts it per process run specifically to resist hash-flooding,
/// so the same inputs produce a different value every run. That's fine for
/// in-memory use, but wrong here: `NotificationService.syncAll` always
/// `cancelAll()`s before rescheduling within a single run, so it never
/// surfaced as a bug there, but a stable id is still the documented
/// contract, so it needs to actually hold. A plain FNV-1a hash of the two
/// strings (joined with a NUL separator, so `('1','23')` and `('12','3')`
/// can't collide) is used instead, which always produces the same id for
/// the same inputs, run to run. Masked to a positive 31-bit int (Android's
/// notification id is a plain `int`, and a negative hash would still be
/// technically valid but needlessly surprising to see in logs).
int notificationIdFor(String prescriptionId, String time) {
  final combined = '$prescriptionId\u0000$time';
  var hash = 0x811c9dc5; // FNV-1a 32-bit offset basis
  for (final codeUnit in combined.codeUnits) {
    hash ^= codeUnit;
    hash = (hash * 0x01000193) & 0xFFFFFFFF; // FNV prime, wrapped to 32 bits
  }
  return hash & 0x7FFFFFFF;
}

/// Snapshot of all medications sharing an exact scheduled time slot, along
/// with the untaken (`remainingDosesCount`) subset used to drive native iOS
/// ActivityKit Live Activities and Android Ongoing Notifications.
class DoseBatch {
  const DoseBatch({
    required this.batchId,
    required this.timeSlot,
    required this.scheduledPrescriptions,
    required this.remainingPrescriptions,
    required this.remainingDosesCount,
    required this.medicationNames,
    this.profileName,
  });

  /// Deterministic identifier for this scheduled time slot (e.g. `batch_08_00`).
  final String batchId;

  /// Canonical formatted time slot label (e.g. `8:00 AM`).
  final String timeSlot;

  /// All prescriptions scheduled for [timeSlot].
  final List<Prescription> scheduledPrescriptions;

  /// Prescriptions scheduled for [timeSlot] that have not yet been marked taken.
  final List<Prescription> remainingPrescriptions;

  /// Number of untaken medications sharing this exact scheduled time slot.
  final int remainingDosesCount;

  /// Names of the untaken medications in this time slot, in schedule order.
  final List<String> medicationNames;

  /// Name of the profile associated with the medications in this batch, or `null`
  /// if profiles are omitted or medications belong to multiple different profiles.
  final String? profileName;

  /// Convenience alias matching native channel parameter naming.
  int get remainingCount => remainingDosesCount;
}

/// Returns `true` when [timeA] and [timeB] represent the exact same time slot.
/// Compares parsed [TimeOfDay] hour and minute first so minor formatting
/// differences (`8:00 AM` vs `08:00 am`) still batch together, falling back to
/// case-insensitive trimmed string equality for non-standard labels.
bool isSameTimeSlot(String timeA, String timeB) {
  final parsedA = parseTimeOfDayLabel(timeA);
  final parsedB = parseTimeOfDayLabel(timeB);
  if (parsedA != null && parsedB != null) {
    return parsedA.hour == parsedB.hour && parsedA.minute == parsedB.minute;
  }
  return timeA.trim().toUpperCase() == timeB.trim().toUpperCase();
}

/// Produces a deterministic batch identifier for a scheduled [timeSlot].
/// Normalized to 24-hour `batch_HH_MM` when parseable so the same wall-clock
/// slot always maps to the same native activity/notification batch ID.
String batchIdForTimeSlot(String timeSlot) {
  final parsed = parseTimeOfDayLabel(timeSlot);
  if (parsed != null) {
    final hh = parsed.hour.toString().padLeft(2, '0');
    final mm = parsed.minute.toString().padLeft(2, '0');
    return 'batch_${hh}_$mm';
  }
  final sanitized = timeSlot
      .trim()
      .toLowerCase()
      .replaceAll(RegExp(r'[^a-z0-9]+'), '_')
      .replaceAll(RegExp(r'^_+|_+$'), '');
  return 'batch_${sanitized.isEmpty ? 'slot' : sanitized}';
}

/// Calculates the [DoseBatch] for all medications in [prescriptions] sharing
/// the exact scheduled [timeSlot].
///
/// When [profiles] is provided, medications suppressed by their assigned
/// profile's bedtime cutoff (via [shouldScheduleReminder]) are excluded from
/// the triggered batch so unscheduled reminders are never counted.
DoseBatch calculateDoseBatch(
  List<Prescription> prescriptions,
  String timeSlot, {
  List<Profile>? profiles,
}) {
  final parsedSlot = parseTimeOfDayLabel(timeSlot);
  final canonicalSlot =
      parsedSlot != null ? formatTimeOfDayLabel(parsedSlot) : timeSlot.trim();
  final profileMap = profiles != null
      ? {for (final profile in profiles) profile.id: profile}
      : null;

  final scheduled = <Prescription>[];
  final remaining = <Prescription>[];

  for (final prescription in prescriptions) {
    String? matchingReminderTime;
    for (final candidate in prescription.reminderTimes) {
      if (isSameTimeSlot(candidate, timeSlot)) {
        matchingReminderTime = candidate;
        break;
      }
    }
    if (matchingReminderTime == null) continue;

    if (profileMap != null) {
      final profile = profileMap[prescription.profileId];
      final allowed = shouldScheduleReminder(
        time: matchingReminderTime,
        bedtime: profile?.bedtime,
        allowAfterBedtime: prescription.allowAfterBedtime,
      );
      if (!allowed) continue;
    }

    scheduled.add(prescription);

    final isTakenForSlot = prescription.takenTimes.any(
      (takenTime) => isSameTimeSlot(takenTime, matchingReminderTime!),
    );
    if (!isTakenForSlot) {
      remaining.add(prescription);
    }
  }

  String? batchProfileName;
  if (profileMap != null) {
    final targetList = remaining.isNotEmpty ? remaining : scheduled;
    final profileIds = targetList.map((p) => p.profileId).toSet();
    if (profileIds.length == 1) {
      batchProfileName = profileMap[profileIds.first]?.name;
    }
  }

  return DoseBatch(
    batchId: batchIdForTimeSlot(canonicalSlot),
    timeSlot: canonicalSlot,
    scheduledPrescriptions: List.unmodifiable(scheduled),
    remainingPrescriptions: List.unmodifiable(remaining),
    remainingDosesCount: remaining.length,
    medicationNames:
        List.unmodifiable(remaining.map((p) => p.name).toList()),
    profileName: batchProfileName,
  );
}

/// Calculates `remainingDosesCount` for all medications sharing the exact
/// scheduled [timeSlot] that have not yet been marked taken.
int calculateRemainingDosesCount(
  List<Prescription> prescriptions,
  String timeSlot, {
  List<Profile>? profiles,
}) {
  return calculateDoseBatch(
    prescriptions,
    timeSlot,
    profiles: profiles,
  ).remainingDosesCount;
}

/// Resolves the wall-clock [DateTime] representing [bedtime] for the current
/// night relative to [now].
///
/// If bedtime is set to an early morning hour (e.g. `12:30 AM`) and [now] is in
/// late evening (e.g. `10:00 PM`), returns early tomorrow morning. Returns `null`
/// when [bedtime] is missing or unparseable.
DateTime? calculateBedtimeDateTime({
  required DateTime now,
  required String? bedtime,
}) {
  if (bedtime == null) return null;
  final tod = parseTimeOfDayLabel(bedtime);
  if (tod == null) return null;

  var target = DateTime(now.year, now.month, now.day, tod.hour, tod.minute);
  if (target.isBefore(now) && tod.hour < 12 && now.hour >= 18) {
    target = target.add(const Duration(days: 1));
  }
  return target;
}

/// Calculates the clamped snooze duration in minutes so that the snooze countdown
/// does not extend past the profile's configured [bedtime].
///
/// If [bedtime] is null or unparseable, returns [requestedMinutes].
/// If [now] + [requestedMinutes] extends beyond [bedtime], clamps the duration so
/// that snooze ends at [bedtime].
/// If [now] is already on or after [bedtime], returns 0.
int clampSnoozeDurationToBedtime({
  required DateTime now,
  required int requestedMinutes,
  required String? bedtime,
}) {
  if (requestedMinutes <= 0) return 0;
  final targetBedtime = calculateBedtimeDateTime(now: now, bedtime: bedtime);
  if (targetBedtime == null) return requestedMinutes;

  if (!targetBedtime.isAfter(now)) {
    return 0;
  }

  final diffSeconds = targetBedtime.difference(now).inSeconds;
  final remainingMinutes = (diffSeconds / 60.0).ceil();
  if (remainingMinutes <= 0) return 0;

  if (requestedMinutes > remainingMinutes) {
    return remainingMinutes;
  }
  return requestedMinutes;
}

/// Returns `true` if [dateTime] falls within the profile's bedtime blackout window
/// (at or after the resolved [bedtime]).
bool isAtOrPastBedtime({
  required DateTime dateTime,
  required String? bedtime,
}) {
  final target = calculateBedtimeDateTime(now: dateTime, bedtime: bedtime);
  if (target == null) return false;
  return !dateTime.isBefore(target);
}

/// Calculates the number of untaken doses for [profile] that are scheduled
/// before their configured [bedtime].
int calculatePendingDosesBeforeBedtime({
  required Profile profile,
  required List<Prescription> prescriptions,
}) {
  var count = 0;
  for (final prescription in prescriptions) {
    if (prescription.profileId != profile.id) continue;
    for (final time in prescription.reminderTimes) {
      final isBeforeBedtime = shouldScheduleReminder(
        time: time,
        bedtime: profile.bedtime,
        allowAfterBedtime: prescription.allowAfterBedtime,
      );
      if (!isBeforeBedtime) continue;

      final isTaken = prescription.takenTimes.any(
        (t) => isSameTimeSlot(t, time),
      );
      if (!isTaken) {
        count++;
      }
    }
  }
  return count;
}

/// Calculates the [TimeOfDay] for scheduling the Pre-Bedtime Final Call notification,
/// defaulting to [leadTimeMinutes] (10 minutes) before [bedtime].
TimeOfDay? calculatePreBedtimeNotificationTime({
  required String? bedtime,
  int leadTimeMinutes = 10,
}) {
  if (bedtime == null) return null;
  final tod = parseTimeOfDayLabel(bedtime);
  if (tod == null) return null;

  var totalMinutes = (tod.hour * 60 + tod.minute) - leadTimeMinutes;
  if (totalMinutes < 0) {
    totalMinutes += 24 * 60;
  }
  return TimeOfDay(hour: totalMinutes ~/ 60, minute: totalMinutes % 60);
}

/// Formats the professional message for the Pre-Bedtime Final Call notification:
/// "Bedtime Reminder: You have [X] pending doses scheduled before your [Time] bedtime. Please log or review your medications before going to sleep."
String formatPreBedtimeFinalCallMessage({
  required int pendingDosesCount,
  required String bedtime,
}) {
  final doseWord =
      pendingDosesCount == 1 ? '1 pending dose' : '$pendingDosesCount pending doses';
  return 'Bedtime Reminder: You have $doseWord scheduled before your $bedtime bedtime. Please log or review your medications before going to sleep.';
}

/// Deterministic, non-colliding notification ID for a profile's Pre-Bedtime Final Call.
int notificationIdForPreBedtime(String profileId) {
  return notificationIdFor(profileId, 'pre_bedtime_final_call');
}
