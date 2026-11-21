import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart' show TimeOfDay;
import 'package:shared_preferences/shared_preferences.dart';

import '../core/utils/date_formatter.dart'
    show formatTimeOfDayLabel, parseTimeOfDayLabel;
import '../data/models/profile.dart';

/// How the user configures their 7-day device-level bedtime quiet hours.
enum BedtimeScheduleMode {
  everyDay,
  weekdaysAndWeekends,
  custom,
}

/// Bedtime quiet-hours window for a single weekday (`DateTime.monday`..`DateTime.sunday`).
///
/// Supports both overnight windows crossing midnight (e.g. `10:00 PM -> 7:00 AM`,
/// where `bedtimeMinutes > wakeTimeMinutes`) and same-day windows (e.g.
/// `1:00 AM -> 9:00 AM` or `9:00 AM -> 5:00 PM`, where `bedtimeMinutes < wakeTimeMinutes`).
@immutable
class DayBedtimeWindow {
  const DayBedtimeWindow({
    this.enabled = true,
    this.bedtime = defaultBedtimeLabel,
    this.wakeTime = defaultWakeTimeLabel,
  });

  static const String defaultBedtimeLabel = '10:00 PM';
  static const String defaultWakeTimeLabel = '7:00 AM';

  final bool enabled;
  final String bedtime;
  final String wakeTime;

  TimeOfDay? get bedtimeTod => parseTimeOfDayLabel(bedtime);
  TimeOfDay? get wakeTimeTod => parseTimeOfDayLabel(wakeTime);

  int? get bedtimeMinutes {
    final tod = bedtimeTod;
    return tod == null ? null : tod.hour * 60 + tod.minute;
  }

  int? get wakeTimeMinutes {
    final tod = wakeTimeTod;
    return tod == null ? null : tod.hour * 60 + tod.minute;
  }

  /// Duration in minutes from [bedtime] to [wakeTime], wrapping across midnight
  /// when `bedtimeMinutes > wakeTimeMinutes`. Returns `null` if unparseable or equal.
  int? get durationMinutes {
    final b = bedtimeMinutes;
    final w = wakeTimeMinutes;
    if (b == null || w == null || b == w) return null;
    return b < w ? (w - b) : (24 * 60 - b + w);
  }

  DayBedtimeWindow copyWith({
    bool? enabled,
    String? bedtime,
    String? wakeTime,
  }) {
    return DayBedtimeWindow(
      enabled: enabled ?? this.enabled,
      bedtime: bedtime ?? this.bedtime,
      wakeTime: wakeTime ?? this.wakeTime,
    );
  }

  Map<String, dynamic> toJson() => <String, dynamic>{
        'enabled': enabled,
        'bedtime': bedtime,
        'wakeTime': wakeTime,
      };

  factory DayBedtimeWindow.fromJson(Map<String, dynamic> json) {
    return DayBedtimeWindow(
      enabled: json['enabled'] as bool? ?? true,
      bedtime: (json['bedtime'] as String?)?.trim().isNotEmpty == true
          ? (json['bedtime'] as String).trim()
          : defaultBedtimeLabel,
      wakeTime: (json['wakeTime'] as String?)?.trim().isNotEmpty == true
          ? (json['wakeTime'] as String).trim()
          : defaultWakeTimeLabel,
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is DayBedtimeWindow &&
        other.enabled == enabled &&
        other.bedtime == bedtime &&
        other.wakeTime == wakeTime;
  }

  @override
  int get hashCode => Object.hash(enabled, bedtime, wakeTime);
}

/// Concrete wall-clock interval `[start, end)` produced by a [DayBedtimeWindow]
/// anchored on a specific calendar date.
@immutable
class QuietWindowInterval {
  const QuietWindowInterval({
    required this.start,
    required this.end,
    required this.anchorDate,
    required this.window,
  });

  final DateTime start;
  final DateTime end;
  final DateTime anchorDate;
  final DayBedtimeWindow window;

  /// True when [dt] falls inside `[start, end)`.
  bool contains(DateTime dt) => !dt.isBefore(start) && dt.isBefore(end);
}

/// Complete device-level 7-day bedtime quiet-hours configuration.
///
/// Keys in [days] use Dart's `DateTime.weekday` convention (`1` = Monday .. `7` = Sunday).
@immutable
class BedtimeSchedule {
  BedtimeSchedule({
    required this.isEnabled,
    required this.mode,
    required Map<int, DayBedtimeWindow> days,
  }) : days = Map<int, DayBedtimeWindow>.unmodifiable({
          for (var wd = DateTime.monday; wd <= DateTime.sunday; wd++)
            wd: days[wd] ?? const DayBedtimeWindow(),
        });

  final bool isEnabled;
  final BedtimeScheduleMode mode;
  final Map<int, DayBedtimeWindow> days;

  /// Standard default schedule: `10:00 PM -> 7:00 AM` every day.
  factory BedtimeSchedule.everyDay({
    bool isEnabled = true,
    String bedtime = DayBedtimeWindow.defaultBedtimeLabel,
    String wakeTime = DayBedtimeWindow.defaultWakeTimeLabel,
  }) {
    final window = DayBedtimeWindow(
      enabled: true,
      bedtime: bedtime,
      wakeTime: wakeTime,
    );
    return BedtimeSchedule(
      isEnabled: isEnabled,
      mode: BedtimeScheduleMode.everyDay,
      days: {
        for (var wd = DateTime.monday; wd <= DateTime.sunday; wd++) wd: window,
      },
    );
  }

  /// Unconfigured / master-off schedule pre-populated with sensible defaults
  /// so flipping the master switch on immediately yields `10:00 PM -> 7:00 AM`.
  factory BedtimeSchedule.disabled() => BedtimeSchedule.everyDay(isEnabled: false);

  factory BedtimeSchedule.weekdaysAndWeekends({
    bool isEnabled = true,
    DayBedtimeWindow weekdayWindow = const DayBedtimeWindow(
      enabled: true,
      bedtime: '10:00 PM',
      wakeTime: '7:00 AM',
    ),
    DayBedtimeWindow weekendWindow = const DayBedtimeWindow(
      enabled: true,
      bedtime: '11:00 PM',
      wakeTime: '8:00 AM',
    ),
  }) {
    return BedtimeSchedule(
      isEnabled: isEnabled,
      mode: BedtimeScheduleMode.weekdaysAndWeekends,
      days: {
        for (var wd = DateTime.monday; wd <= DateTime.friday; wd++)
          wd: weekdayWindow,
        DateTime.saturday: weekendWindow,
        DateTime.sunday: weekendWindow,
      },
    );
  }

  DayBedtimeWindow windowForWeekday(int weekday) {
    final normalized = ((weekday - 1) % 7) + 1;
    return days[normalized] ?? const DayBedtimeWindow();
  }

  bool get hasAnyActiveDay => isEnabled && days.values.any((d) => d.enabled);

  /// True when all 7 days share the exact same [DayBedtimeWindow].
  bool get isUniform {
    final first = windowForWeekday(DateTime.monday);
    for (var wd = DateTime.tuesday; wd <= DateTime.sunday; wd++) {
      if (windowForWeekday(wd) != first) return false;
    }
    return true;
  }

  BedtimeSchedule copyWith({
    bool? isEnabled,
    BedtimeScheduleMode? mode,
    Map<int, DayBedtimeWindow>? days,
  }) {
    return BedtimeSchedule(
      isEnabled: isEnabled ?? this.isEnabled,
      mode: mode ?? this.mode,
      days: days ?? this.days,
    );
  }

  BedtimeSchedule withDay(int weekday, DayBedtimeWindow window) {
    final updated = Map<int, DayBedtimeWindow>.from(days);
    updated[weekday] = window;
    return copyWith(days: updated);
  }

  BedtimeSchedule withEveryDayWindow(DayBedtimeWindow window) {
    return copyWith(
      mode: BedtimeScheduleMode.everyDay,
      days: {
        for (var wd = DateTime.monday; wd <= DateTime.sunday; wd++) wd: window,
      },
    );
  }

  BedtimeSchedule withWeekdaysWindow(DayBedtimeWindow window) {
    final updated = Map<int, DayBedtimeWindow>.from(days);
    for (var wd = DateTime.monday; wd <= DateTime.friday; wd++) {
      updated[wd] = window;
    }
    return copyWith(
      mode: BedtimeScheduleMode.weekdaysAndWeekends,
      days: updated,
    );
  }

  BedtimeSchedule withWeekendsWindow(DayBedtimeWindow window) {
    final updated = Map<int, DayBedtimeWindow>.from(days);
    updated[DateTime.saturday] = window;
    updated[DateTime.sunday] = window;
    return copyWith(
      mode: BedtimeScheduleMode.weekdaysAndWeekends,
      days: updated,
    );
  }

  /// Switches mode cleanly without losing the user's configured times.
  BedtimeSchedule switchedToMode(BedtimeScheduleMode nextMode) {
    if (nextMode == mode) return this;
    switch (nextMode) {
      case BedtimeScheduleMode.everyDay:
        final base = days[DateTime.monday]?.enabled == true
            ? days[DateTime.monday]!
            : days.values.firstWhere(
                (w) => w.enabled,
                orElse: () => const DayBedtimeWindow(),
              );
        return withEveryDayWindow(base.copyWith(enabled: true));
      case BedtimeScheduleMode.weekdaysAndWeekends:
        final weekday = windowForWeekday(DateTime.monday);
        final weekend = windowForWeekday(DateTime.saturday);
        return copyWith(
          mode: BedtimeScheduleMode.weekdaysAndWeekends,
          days: {
            for (var wd = DateTime.monday; wd <= DateTime.friday; wd++)
              wd: weekday,
            DateTime.saturday: weekend,
            DateTime.sunday: weekend,
          },
        );
      case BedtimeScheduleMode.custom:
        return copyWith(mode: BedtimeScheduleMode.custom);
    }
  }

  Map<String, dynamic> toJson() => <String, dynamic>{
        'isEnabled': isEnabled,
        'mode': mode.name,
        'days': {
          for (final entry in days.entries) '${entry.key}': entry.value.toJson(),
        },
      };

  factory BedtimeSchedule.fromJson(Map<String, dynamic> json) {
    final rawMode = json['mode'] as String?;
    final mode = BedtimeScheduleMode.values.firstWhere(
      (m) => m.name == rawMode,
      orElse: () => BedtimeScheduleMode.everyDay,
    );
    final rawDays = json['days'] as Map<String, dynamic>? ?? const {};
    final parsedDays = <int, DayBedtimeWindow>{};
    for (var wd = DateTime.monday; wd <= DateTime.sunday; wd++) {
      final entry = rawDays['$wd'];
      if (entry is Map<String, dynamic>) {
        parsedDays[wd] = DayBedtimeWindow.fromJson(entry);
      } else {
        parsedDays[wd] = const DayBedtimeWindow();
      }
    }
    return BedtimeSchedule(
      isEnabled: json['isEnabled'] as bool? ?? false,
      mode: mode,
      days: parsedDays,
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    if (other is! BedtimeSchedule) return false;
    if (other.isEnabled != isEnabled || other.mode != mode) return false;
    for (var wd = DateTime.monday; wd <= DateTime.sunday; wd++) {
      if (other.days[wd] != days[wd]) return false;
    }
    return true;
  }

  @override
  int get hashCode => Object.hash(
        isEnabled,
        mode,
        Object.hashAll([
          for (var wd = DateTime.monday; wd <= DateTime.sunday; wd++) days[wd],
        ]),
      );
}

/// Shared, pure quiet-hours geometry helpers used by [BedtimeService],
/// `reminder_scheduler.dart`, `live_reminder_service.dart`, `notification_service.dart`,
/// and `home_scaffold.dart`.
class BedtimeQuietHours {
  const BedtimeQuietHours._();

  /// Adds [hours] (wrapping modulo 24h) to a formatted time label like `'10:00 PM'`.
  /// Falls back to [fallback] if [timeLabel] cannot be parsed.
  static String addHoursToLabel(
    String timeLabel,
    int hours, {
    String fallback = DayBedtimeWindow.defaultWakeTimeLabel,
  }) {
    final tod = parseTimeOfDayLabel(timeLabel);
    if (tod == null) return fallback;
    final totalMinutes = (tod.hour * 60 + tod.minute + hours * 60) % (24 * 60);
    final normalized = totalMinutes < 0 ? totalMinutes + 24 * 60 : totalMinutes;
    return formatTimeOfDayLabel(
      TimeOfDay(hour: normalized ~/ 60, minute: normalized % 60),
    );
  }

  /// Checks whether wall-clock time [time] falls inside the quiet window
  /// `[bedtime, wakeTime)`, handling both midnight-crossing schedules
  /// (`bedtime > wakeTime`, e.g. `10:00 PM -> 7:00 AM`) and same-day schedules
  /// (`bedtime < wakeTime`, e.g. `1:00 AM -> 9:00 AM` or `9:00 AM -> 5:00 PM`).
  ///
  /// When `bedtime == wakeTime`, returns `false` (empty window).
  static bool isTimeOfDayInWindow({
    required TimeOfDay time,
    required TimeOfDay bedtime,
    required TimeOfDay wakeTime,
  }) {
    final t = time.hour * 60 + time.minute;
    final b = bedtime.hour * 60 + bedtime.minute;
    final w = wakeTime.hour * 60 + wakeTime.minute;
    if (b == w) return false;
    if (b < w) {
      // Same-day window: [b, w)
      return t >= b && t < w;
    }
    // Midnight-crossing window: [b, 24:00) U [00:00, w)
    return t >= b || t < w;
  }

  /// Returns the concrete [QuietWindowInterval] anchored on [anchorDate]'s
  /// calendar day (midnight), or `null` if that weekday is disabled or invalid.
  static QuietWindowInterval? intervalForDate(
    BedtimeSchedule schedule,
    DateTime anchorDate,
  ) {
    final dayStart = DateTime(anchorDate.year, anchorDate.month, anchorDate.day);
    final window = schedule.windowForWeekday(dayStart.weekday);
    if (!window.enabled) return null;

    final bedTod = window.bedtimeTod;
    final wakeTod = window.wakeTimeTod;
    if (bedTod == null || wakeTod == null) return null;

    final bedMin = bedTod.hour * 60 + bedTod.minute;
    final wakeMin = wakeTod.hour * 60 + wakeTod.minute;
    if (bedMin == wakeMin) return null;

    final start = DateTime(
      dayStart.year,
      dayStart.month,
      dayStart.day,
      bedTod.hour,
      bedTod.minute,
    );
    final endDate = bedMin > wakeMin
        ? dayStart.add(const Duration(days: 1))
        : dayStart;
    final end = DateTime(
      endDate.year,
      endDate.month,
      endDate.day,
      wakeTod.hour,
      wakeTod.minute,
    );
    return QuietWindowInterval(
      start: start,
      end: end,
      anchorDate: dayStart,
      window: window,
    );
  }

  /// Returns the active [QuietWindowInterval] containing [dt], checking both
  /// yesterday's overnight spillover and today's window. Returns `null` when
  /// [schedule.isEnabled] is false or [dt] is outside quiet hours.
  static QuietWindowInterval? activeWindowAt(
    BedtimeSchedule schedule,
    DateTime dt,
  ) {
    if (!schedule.isEnabled) return null;
    final today = DateTime(dt.year, dt.month, dt.day);
    final yesterday = today.subtract(const Duration(days: 1));

    final prevInterval = intervalForDate(schedule, yesterday);
    if (prevInterval != null && prevInterval.contains(dt)) {
      return prevInterval;
    }
    final todayInterval = intervalForDate(schedule, today);
    if (todayInterval != null && todayInterval.contains(dt)) {
      return todayInterval;
    }
    return null;
  }

  /// Returns the next [QuietWindowInterval] whose `start` is strictly after [after].
  static QuietWindowInterval? nextWindowAfter(
    BedtimeSchedule schedule,
    DateTime after,
  ) {
    if (!schedule.isEnabled || !schedule.hasAnyActiveDay) return null;
    final baseDay = DateTime(after.year, after.month, after.day);
    for (var offset = 0; offset <= 14; offset++) {
      final candidate = intervalForDate(
        schedule,
        baseDay.add(Duration(days: offset)),
      );
      if (candidate != null && candidate.start.isAfter(after)) {
        return candidate;
      }
    }
    return null;
  }

  /// Returns `true` when wall-clock reminder [timeSlot] on [weekday] falls
  /// inside quiet hours (accounting for both [weekday]'s own window and the
  /// previous weekday's overnight spillover into [weekday]'s morning).
  static bool isTimeSlotInQuietHours({
    required BedtimeSchedule schedule,
    required String timeSlot,
    required int weekday,
  }) {
    if (!schedule.isEnabled) return false;
    final slotTod = parseTimeOfDayLabel(timeSlot);
    if (slotTod == null) return false;
    final slotMin = slotTod.hour * 60 + slotTod.minute;

    final normalizedWd = ((weekday - 1) % 7) + 1;
    final prevWd = normalizedWd == DateTime.monday
        ? DateTime.sunday
        : normalizedWd - 1;

    // 1. Check previous weekday's overnight spillover into this morning.
    final prevWindow = schedule.windowForWeekday(prevWd);
    if (prevWindow.enabled) {
      final prevBed = prevWindow.bedtimeMinutes;
      final prevWake = prevWindow.wakeTimeMinutes;
      if (prevBed != null && prevWake != null && prevBed > prevWake) {
        if (slotMin < prevWake) return true;
      }
    }

    // 2. Check this weekday's own quiet window.
    final todayWindow = schedule.windowForWeekday(normalizedWd);
    if (todayWindow.enabled) {
      final bed = todayWindow.bedtimeMinutes;
      final wake = todayWindow.wakeTimeMinutes;
      if (bed != null && wake != null && bed != wake) {
        if (bed < wake) {
          // Same-day window [bed, wake)
          if (slotMin >= bed && slotMin < wake) return true;
        } else {
          // Overnight window starts at [bed, 24:00) on this weekday
          if (slotMin >= bed) return true;
        }
      }
    }

    return false;
  }

  /// Clamps a requested snooze duration so it does not extend into the next
  /// quiet window. Returns `0` if [now] is already inside quiet hours.
  static int clampSnoozeMinutes({
    required BedtimeSchedule schedule,
    required DateTime now,
    required int requestedMinutes,
  }) {
    if (requestedMinutes <= 0) return 0;
    if (!schedule.isEnabled || !schedule.hasAnyActiveDay) {
      return requestedMinutes;
    }
    if (activeWindowAt(schedule, now) != null) {
      return 0;
    }
    final next = nextWindowAfter(schedule, now);
    if (next == null) return requestedMinutes;

    final diffSeconds = next.start.difference(now).inSeconds;
    final remainingMinutes = (diffSeconds / 60.0).ceil();
    if (remainingMinutes <= 0) return 0;
    return requestedMinutes > remainingMinutes
        ? remainingMinutes
        : requestedMinutes;
  }

  /// Computes the auto-resume timestamp when the user pauses Bedtime Quiet Hours
  /// at [now]:
  /// - If [now] is inside an active quiet window, skips the rest of that window
  ///   and resumes at the start of the next scheduled bedtime.
  /// - If [now] is outside quiet hours, skips the upcoming night's quiet window
  ///   and resumes at the start of the scheduled bedtime after that.
  static DateTime? computePauseResumeTime({
    required BedtimeSchedule schedule,
    required DateTime now,
  }) {
    if (!schedule.isEnabled || !schedule.hasAnyActiveDay) return null;

    final active = activeWindowAt(schedule, now);
    if (active != null) {
      return nextWindowAfter(schedule, active.start)?.start;
    }

    final upcoming = nextWindowAfter(schedule, now);
    if (upcoming == null) return null;
    return nextWindowAfter(schedule, upcoming.start)?.start;
  }
}

/// Manages PillPal's device-level 7-day Bedtime Quiet Hours schedule, one-time
/// migration from legacy per-profile bedtimes, and "Skip Tonight" pause state.
class BedtimeService extends ChangeNotifier {
  BedtimeService({
    SharedPreferences? prefs,
    DateTime Function()? clock,
    BedtimeSchedule? initialSchedule,
  })  : _prefs = prefs,
        _clock = clock ?? DateTime.now,
        _schedule = initialSchedule ?? BedtimeSchedule.disabled();

  SharedPreferences? _prefs;
  final DateTime Function() _clock;

  static const String keyScheduleJson = 'device_bedtime_schedule_v1';
  static const String keyPausedUntilMs = 'device_bedtime_paused_until_ms';
  static const String keyMigratedV1 = 'device_bedtime_migrated_v1';

  BedtimeSchedule _schedule;
  DateTime? _pausedUntil;
  bool _isLoaded = false;
  bool _hasPersistedSchedule = false;
  bool _migratedV1 = false;

  BedtimeSchedule get schedule => _schedule;
  bool get isEnabled => _schedule.isEnabled;
  bool get isLoaded => _isLoaded;
  DateTime? get pausedUntil => _pausedUntil;

  /// True when quiet hours are temporarily paused at [now].
  bool isPausedAt([DateTime? now]) {
    final until = _pausedUntil;
    if (until == null) return false;
    return (now ?? _clock()).isBefore(until);
  }

  /// True when quiet hours are actively suppressing alerts at [now]
  /// (master enabled, not paused, and [now] falls inside an enabled window).
  bool isInQuietHours([DateTime? now]) {
    final t = now ?? _clock();
    if (!_schedule.isEnabled || isPausedAt(t)) return false;
    return BedtimeQuietHours.activeWindowAt(_schedule, t) != null;
  }

  /// Active quiet window containing [now], or `null` if outside quiet hours
  /// (or disabled / paused unless [ignorePause] is true).
  QuietWindowInterval? activeQuietWindow({
    DateTime? now,
    bool ignorePause = false,
  }) {
    final t = now ?? _clock();
    if (!_schedule.isEnabled) return null;
    if (!ignorePause && isPausedAt(t)) return null;
    return BedtimeQuietHours.activeWindowAt(_schedule, t);
  }

  /// Next scheduled quiet window starting strictly after [now].
  QuietWindowInterval? nextQuietWindow({DateTime? now}) {
    return BedtimeQuietHours.nextWindowAfter(_schedule, now ?? _clock());
  }

  /// Whether a reminder at [timeSlot] should be scheduled/delivered on [weekday]
  /// (defaults to today's weekday at [now]).
  bool shouldScheduleReminder({
    required String timeSlot,
    required bool allowAfterBedtime,
    int? weekday,
    DateTime? now,
    bool bypassBedtime = false,
  }) {
    if (allowAfterBedtime || bypassBedtime) return true;
    final t = now ?? _clock();
    if (!_schedule.isEnabled || isPausedAt(t)) return true;
    return !BedtimeQuietHours.isTimeSlotInQuietHours(
      schedule: _schedule,
      timeSlot: timeSlot,
      weekday: weekday ?? t.weekday,
    );
  }

  /// Clamps a snooze request against the device-level quiet hours schedule.
  /// Returns [requestedMinutes] if disabled or paused; returns `0` if already
  /// inside quiet hours.
  int clampSnoozeMinutes({
    required int requestedMinutes,
    DateTime? now,
    bool bypassBedtime = false,
  }) {
    final t = now ?? _clock();
    if (bypassBedtime || !_schedule.isEnabled || isPausedAt(t)) {
      return requestedMinutes;
    }
    return BedtimeQuietHours.clampSnoozeMinutes(
      schedule: _schedule,
      now: t,
      requestedMinutes: requestedMinutes,
    );
  }

  /// Today's active bedtime label (e.g. `'10:00 PM'`), or `null` if quiet hours
  /// are disabled globally or disabled for today.
  String? todayBedtimeLabel([DateTime? now]) {
    if (!_schedule.isEnabled) return null;
    final t = now ?? _clock();
    final window = _schedule.windowForWeekday(t.weekday);
    return window.enabled ? window.bedtime : null;
  }

  /// Concise single-line status summary for the Settings row card.
  String summaryLabel({DateTime? now}) {
    final t = now ?? _clock();
    if (!_schedule.isEnabled || !_schedule.hasAnyActiveDay) {
      return 'Off';
    }
    if (isPausedAt(t)) {
      final until = _pausedUntil!;
      final day = _shortWeekday(until.weekday);
      final time = formatTimeOfDayLabel(TimeOfDay.fromDateTime(until));
      return 'Paused tonight · Resumes $day $time';
    }
    switch (_schedule.mode) {
      case BedtimeScheduleMode.everyDay:
        final w = _schedule.windowForWeekday(DateTime.monday);
        return '${w.bedtime} – ${w.wakeTime} · Every day';
      case BedtimeScheduleMode.weekdaysAndWeekends:
        final w = _schedule.windowForWeekday(t.weekday);
        final isWeekend = t.weekday == DateTime.saturday ||
            t.weekday == DateTime.sunday;
        final group = isWeekend ? 'Weekends' : 'Weekdays';
        if (!w.enabled) return 'Off tonight · $group';
        return 'Tonight: ${w.bedtime} – ${w.wakeTime} · $group';
      case BedtimeScheduleMode.custom:
        final w = _schedule.windowForWeekday(t.weekday);
        if (!w.enabled) return 'Off tonight · Custom';
        return 'Tonight: ${w.bedtime} – ${w.wakeTime} · Custom';
    }
  }

  /// Concise resume timestamp label when paused (e.g. `'Tue at 10:00 PM'`).
  String? pausedResumeLabel({DateTime? now}) {
    final t = now ?? _clock();
    if (!isPausedAt(t)) return null;
    final until = _pausedUntil!;
    final day = _shortWeekday(until.weekday);
    final time = formatTimeOfDayLabel(TimeOfDay.fromDateTime(until));
    return '$day at $time';
  }

  static String _shortWeekday(int weekday) {
    const names = {
      DateTime.monday: 'Mon',
      DateTime.tuesday: 'Tue',
      DateTime.wednesday: 'Wed',
      DateTime.thursday: 'Thu',
      DateTime.friday: 'Fri',
      DateTime.saturday: 'Sat',
      DateTime.sunday: 'Sun',
    };
    return names[weekday] ?? '';
  }

  Future<void> load() async {
    try {
      final prefs = _prefs ?? await SharedPreferences.getInstance();
      _prefs = prefs;
      _migratedV1 = prefs.getBool(keyMigratedV1) ?? false;

      final rawSchedule = prefs.getString(keyScheduleJson);
      if (rawSchedule != null && rawSchedule.isNotEmpty) {
        final decoded = jsonDecode(rawSchedule);
        if (decoded is Map<String, dynamic>) {
          _schedule = BedtimeSchedule.fromJson(decoded);
          _hasPersistedSchedule = true;
        }
      }

      final pausedMs = prefs.getInt(keyPausedUntilMs);
      if (pausedMs != null && pausedMs > 0) {
        final candidate = DateTime.fromMillisecondsSinceEpoch(pausedMs);
        if (_clock().isBefore(candidate)) {
          _pausedUntil = candidate;
        } else {
          _pausedUntil = null;
          await prefs.remove(keyPausedUntilMs);
        }
      } else {
        _pausedUntil = null;
      }
    } catch (_) {
      // Fall back to in-memory state if SharedPreferences is unavailable.
    }
    _isLoaded = true;
    notifyListeners();
  }

  /// One-time migration from legacy per-profile `Profile.bedtime` into the
  /// single device-level 7-day schedule.
  ///
  /// Seeds from the primary profile's existing bedtime (falling back to the
  /// first profile with a bedtime), defaulting Wake Time to `+8h`.
  /// No-op if already migrated or if a device-level schedule was already saved.
  Future<bool> migrateFromProfilesIfNeeded(List<Profile> profiles) async {
    if (_migratedV1 || _hasPersistedSchedule) return false;
    if (profiles.isEmpty) return false;

    String? legacyBedtime;
    final primary = profiles.firstWhere(
      (p) => p.isPrimary,
      orElse: () => profiles.first,
    );
    if (primary.bedtime != null && primary.bedtime!.trim().isNotEmpty) {
      legacyBedtime = primary.bedtime!.trim();
    } else {
      for (final p in profiles) {
        if (p.bedtime != null && p.bedtime!.trim().isNotEmpty) {
          legacyBedtime = p.bedtime!.trim();
          break;
        }
      }
    }

    _migratedV1 = true;
    if (legacyBedtime != null) {
      final wakeTime = BedtimeQuietHours.addHoursToLabel(
        legacyBedtime,
        8,
        fallback: DayBedtimeWindow.defaultWakeTimeLabel,
      );
      _schedule = BedtimeSchedule.everyDay(
        isEnabled: true,
        bedtime: legacyBedtime,
        wakeTime: wakeTime,
      );
      _hasPersistedSchedule = true;
      await _persistSchedule();
    }

    try {
      final prefs = _prefs ?? await SharedPreferences.getInstance();
      _prefs = prefs;
      await prefs.setBool(keyMigratedV1, true);
    } catch (_) {}

    if (legacyBedtime != null) {
      notifyListeners();
      return true;
    }
    return false;
  }

  /// Replaces and persists the device-level [BedtimeSchedule].
  /// Turning master off clears any active pause.
  Future<void> updateSchedule(BedtimeSchedule nextSchedule) async {
    _schedule = nextSchedule;
    _hasPersistedSchedule = true;
    _migratedV1 = true;
    if (!nextSchedule.isEnabled || !nextSchedule.hasAnyActiveDay) {
      _pausedUntil = null;
      await _removePausedUntil();
    }
    await _persistSchedule();
    try {
      final prefs = _prefs ?? await SharedPreferences.getInstance();
      _prefs = prefs;
      await prefs.setBool(keyMigratedV1, true);
    } catch (_) {}
    notifyListeners();
  }

  /// Toggles the master Bedtime Quiet Hours on/off switch.
  Future<void> setEnabled(bool enabled) async {
    await updateSchedule(_schedule.copyWith(isEnabled: enabled));
  }

  /// Pauses tonight's quiet hours (whether tapped before or during tonight's
  /// window) and auto-resumes at the start of the next scheduled bedtime.
  Future<DateTime?> pauseTonight({DateTime? now}) async {
    final t = now ?? _clock();
    final resumeAt = BedtimeQuietHours.computePauseResumeTime(
      schedule: _schedule,
      now: t,
    );
    if (resumeAt == null) return null;
    _pausedUntil = resumeAt;
    try {
      final prefs = _prefs ?? await SharedPreferences.getInstance();
      _prefs = prefs;
      await prefs.setInt(keyPausedUntilMs, resumeAt.millisecondsSinceEpoch);
    } catch (_) {}
    notifyListeners();
    return resumeAt;
  }

  /// Clears any active "Skip Tonight" pause immediately.
  Future<void> resumeNow() async {
    final wasPaused = _pausedUntil != null;
    _pausedUntil = null;
    await _removePausedUntil();
    if (wasPaused) {
      notifyListeners();
    }
  }

  /// Clears a persisted pause once its next-bedtime auto-resume timestamp has passed.
  Future<bool> clearExpiredPause({DateTime? now}) async {
    final until = _pausedUntil;
    if (until == null) return false;
    if ((now ?? _clock()).isBefore(until)) return false;
    await resumeNow();
    return true;
  }

  /// Resets all bedtime settings (used by clean-slate onboarding reset).
  Future<void> reset() async {
    _schedule = BedtimeSchedule.disabled();
    _pausedUntil = null;
    _hasPersistedSchedule = false;
    _migratedV1 = false;
    try {
      final prefs = _prefs ?? await SharedPreferences.getInstance();
      _prefs = prefs;
      await prefs.remove(keyScheduleJson);
      await prefs.remove(keyPausedUntilMs);
      await prefs.remove(keyMigratedV1);
    } catch (_) {}
    notifyListeners();
  }

  Future<void> _persistSchedule() async {
    try {
      final prefs = _prefs ?? await SharedPreferences.getInstance();
      _prefs = prefs;
      await prefs.setString(keyScheduleJson, jsonEncode(_schedule.toJson()));
    } catch (_) {}
  }

  Future<void> _removePausedUntil() async {
    try {
      final prefs = _prefs ?? await SharedPreferences.getInstance();
      _prefs = prefs;
      await prefs.remove(keyPausedUntilMs);
    } catch (_) {}
  }
}
