import 'package:flutter/material.dart' show TimeOfDay;

import '../utils/date_formatter.dart' show parseTimeOfDayLabel;

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
