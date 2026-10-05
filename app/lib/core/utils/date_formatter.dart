import 'package:flutter/material.dart' show TimeOfDay, DayPeriod;

const _weekdayNames = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
const _monthNames = [
  'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
  'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
];
const _fullWeekdayNames = [
  'Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday', 'Sunday',
];
const _fullMonthNames = [
  'January', 'February', 'March', 'April', 'May', 'June',
  'July', 'August', 'September', 'October', 'November', 'December',
];

/// "Today" / "Yesterday" / "Mon, Sep 28" -- used to group the dose-history
/// feed (Meds tab) by day. [now] is injectable for testing.
String formatDayLabel(DateTime date, {DateTime? now}) {
  final today = now ?? DateTime.now();
  final d = DateTime(date.year, date.month, date.day);
  final t = DateTime(today.year, today.month, today.day);
  final diff = t.difference(d).inDays;
  if (diff == 0) return 'Today';
  if (diff == 1) return 'Yesterday';
  return '${_weekdayNames[d.weekday - 1]}, ${_monthNames[d.month - 1]} ${d.day}';
}

/// "8:02 AM" -- 12-hour clock, matching the rest of the app's time display.
String formatTimeOfDay(DateTime dt) {
  final period = dt.hour >= 12 ? 'PM' : 'AM';
  var hour12 = dt.hour % 12;
  if (hour12 == 0) hour12 = 12;
  final minute = dt.minute.toString().padLeft(2, '0');
  return '$hour12:$minute $period';
}

/// True when [date] falls on the same calendar day as [now] (defaults to
/// `DateTime.now()`).
bool isToday(DateTime date, {DateTime? now}) => formatDayLabel(date, now: now) == 'Today';

/// "Wednesday, September 2" -- full weekday + full month, no year, for the
/// Schedule screen's header. [now] is injectable for testing.
String formatFullDate({DateTime? now}) {
  final d = now ?? DateTime.now();
  return '${_fullWeekdayNames[d.weekday - 1]}, ${_fullMonthNames[d.month - 1]} ${d.day}';
}

/// "Good morning" / "Good afternoon" / "Good evening", based on the hour --
/// before noon, noon to 5pm, and after 5pm respectively. [now] is injectable
/// for testing.
String timeOfDayGreeting({DateTime? now}) {
  final hour = (now ?? DateTime.now()).hour;
  if (hour < 12) return 'Good morning';
  if (hour < 17) return 'Good afternoon';
  return 'Good evening';
}

/// "8:00 AM" -- the formatted-string convention `Prescription.reminderTimes`
/// and `Profile.bedtime` both store times in.
String formatTimeOfDayLabel(TimeOfDay t) {
  final hour = t.hourOfPeriod == 0 ? 12 : t.hourOfPeriod;
  final minute = t.minute.toString().padLeft(2, '0');
  final period = t.period == DayPeriod.am ? 'AM' : 'PM';
  return '$hour:$minute $period';
}

/// Reverses [formatTimeOfDayLabel]. Returns `null` for anything that doesn't
/// match the expected "h:mm AM/PM" shape, rather than throwing.
TimeOfDay? parseTimeOfDayLabel(String? label) {
  if (label == null) return null;
  final match = RegExp(r'^(\d{1,2}):(\d{2})\s*(AM|PM)$', caseSensitive: false).firstMatch(label.trim());
  if (match == null) return null;
  var hour = int.parse(match.group(1)!);
  final minute = int.parse(match.group(2)!);
  final isPm = match.group(3)!.toUpperCase() == 'PM';
  if (hour == 12) hour = 0;
  return TimeOfDay(hour: isPm ? hour + 12 : hour, minute: minute);
}
