const _weekdayNames = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
const _monthNames = [
  'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
  'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
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
