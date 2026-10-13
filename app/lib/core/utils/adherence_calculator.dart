import '../../data/models/dose_event.dart';

enum AdherenceTimeRange {
  sevenDays('7D', 'Past 7 Days'),
  thirtyDays('30D', 'Past 30 Days'),
  ninetyDays('90D', 'Past 90 Days'),
  oneYear('1Y', 'Past Year');

  const AdherenceTimeRange(this.shortLabel, this.fullLabel);
  final String shortLabel;
  final String fullLabel;
}

class AdherenceBucket {
  final String label;
  final String fullLabel;
  final DateTime startDate;
  final DateTime endDate;
  final bool isCurrent;
  final int onTimeCount;
  final int lateCount;
  final int skippedCount;

  const AdherenceBucket({
    required this.label,
    required this.fullLabel,
    required this.startDate,
    required this.endDate,
    required this.isCurrent,
    required this.onTimeCount,
    required this.lateCount,
    required this.skippedCount,
  });

  int get totalCount => onTimeCount + lateCount + skippedCount;
  int get takenCount => onTimeCount + lateCount;

  double get onTimeRatio => totalCount == 0 ? 0.0 : onTimeCount / totalCount;
  double get lateRatio => totalCount == 0 ? 0.0 : lateCount / totalCount;
  double get skippedRatio => totalCount == 0 ? 0.0 : skippedCount / totalCount;
}

class AdherenceSummary {
  final AdherenceTimeRange range;
  final int totalLogged;
  final int onTimeCount;
  final int lateCount;
  final int skippedCount;
  final int adherencePercentage;
  final int onTimePercentage;
  final int latePercentage;
  final int skippedPercentage;
  final List<AdherenceBucket> buckets;
  final String statusLabel;
  final String statusMessage;

  const AdherenceSummary({
    required this.range,
    required this.totalLogged,
    required this.onTimeCount,
    required this.lateCount,
    required this.skippedCount,
    required this.adherencePercentage,
    required this.onTimePercentage,
    required this.latePercentage,
    required this.skippedPercentage,
    required this.buckets,
    required this.statusLabel,
    required this.statusMessage,
  });
}

class AdherenceCalculator {
  static const _weekdayLetters = ['M', 'T', 'W', 'T', 'F', 'S', 'S'];
  static const _monthNames = [
    'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
    'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
  ];

  static bool _isSameDay(DateTime a, DateTime b) {
    return a.year == b.year && a.month == b.month && a.day == b.day;
  }

  static AdherenceSummary calculate({
    required List<DoseEvent> events,
    required AdherenceTimeRange range,
    String? selectedProfileId,
    DateTime? now,
  }) {
    final current = now ?? DateTime.now();
    final today = DateTime(current.year, current.month, current.day);

    // Filter by profile if specified
    final profileFiltered = (selectedProfileId == null || selectedProfileId == 'all')
        ? events
        : events.where((e) => e.profileId == selectedProfileId).toList();

    final List<AdherenceBucket> buckets;
    final DateTime windowStart;

    switch (range) {
      case AdherenceTimeRange.sevenDays:
        windowStart = today.subtract(const Duration(days: 6));
        buckets = _build7DayBuckets(profileFiltered, today);
        break;

      case AdherenceTimeRange.thirtyDays:
        windowStart = today.subtract(const Duration(days: 29));
        buckets = _build30DayBuckets(profileFiltered, today);
        break;

      case AdherenceTimeRange.ninetyDays:
        windowStart = today.subtract(const Duration(days: 89));
        buckets = _build90DayBuckets(profileFiltered, today);
        break;

      case AdherenceTimeRange.oneYear:
        windowStart = DateTime(today.year - 1, today.month, 1);
        buckets = _build1YearBuckets(profileFiltered, today);
        break;
    }

    // Filter events within window for total stats
    final windowEvents = profileFiltered.where((e) {
      final d = DateTime(e.occurredAt.year, e.occurredAt.month, e.occurredAt.day);
      return !d.isBefore(windowStart) && !d.isAfter(today);
    }).toList();

    int onTime = 0;
    int late = 0;
    int skipped = 0;

    for (final e in windowEvents) {
      switch (e.action) {
        case DoseAction.taken:
          onTime++;
          break;
        case DoseAction.late:
          late++;
          break;
        case DoseAction.skipped:
          skipped++;
          break;
      }
    }

    final total = onTime + late + skipped;
    final int adherencePct;
    final int onTimePct;
    final int latePct;
    final int skippedPct;

    if (total == 0) {
      adherencePct = 0;
      onTimePct = 0;
      latePct = 0;
      skippedPct = 0;
    } else {
      // Adherence treats on-time and late as taken, with on-time weighted highest
      adherencePct = (((onTime * 1.0 + late * 0.7) / total) * 100).round().clamp(0, 100);
      onTimePct = ((onTime / total) * 100).round();
      latePct = ((late / total) * 100).round();
      skippedPct = ((skipped / total) * 100).round();
    }

    final String statusLabel;
    final String statusMessage;

    if (total == 0) {
      statusLabel = 'No Logs Yet';
      statusMessage = 'Mark scheduled doses taken or skipped to see consistency.';
    } else if (adherencePct >= 90) {
      statusLabel = 'Optimal • On Track';
      statusMessage = '$onTime of $total doses logged right on schedule.';
    } else if (adherencePct >= 70) {
      statusLabel = 'Consistent';
      statusMessage = '$late dose${late == 1 ? '' : 's'} logged late, but keeping good routine.';
    } else {
      statusLabel = 'Needs Attention';
      statusMessage = '$skipped dose${skipped == 1 ? '' : 's'} missed or skipped in this period.';
    }

    return AdherenceSummary(
      range: range,
      totalLogged: total,
      onTimeCount: onTime,
      lateCount: late,
      skippedCount: skipped,
      adherencePercentage: adherencePct,
      onTimePercentage: onTimePct,
      latePercentage: latePct,
      skippedPercentage: skippedPct,
      buckets: buckets,
      statusLabel: statusLabel,
      statusMessage: statusMessage,
    );
  }

  static List<AdherenceBucket> _build7DayBuckets(
    List<DoseEvent> events,
    DateTime today,
  ) {
    final buckets = <AdherenceBucket>[];

    for (int i = 6; i >= 0; i--) {
      final day = today.subtract(Duration(days: i));
      final isCurrent = i == 0;
      final weekdayChar = _weekdayLetters[day.weekday - 1];

      int onTime = 0;
      int late = 0;
      int skipped = 0;

      for (final e in events) {
        if (_isSameDay(e.occurredAt, day)) {
          switch (e.action) {
            case DoseAction.taken:
              onTime++;
              break;
            case DoseAction.late:
              late++;
              break;
            case DoseAction.skipped:
              skipped++;
              break;
          }
        }
      }

      final fullLabel = '${_monthNames[day.month - 1]} ${day.day}';

      buckets.add(AdherenceBucket(
        label: weekdayChar,
        fullLabel: fullLabel,
        startDate: day,
        endDate: day,
        isCurrent: isCurrent,
        onTimeCount: onTime,
        lateCount: late,
        skippedCount: skipped,
      ));
    }

    return buckets;
  }

  static List<AdherenceBucket> _build30DayBuckets(
    List<DoseEvent> events,
    DateTime today,
  ) {
    // 5 buckets of 6 days each
    final buckets = <AdherenceBucket>[];

    for (int i = 4; i >= 0; i--) {
      final start = today.subtract(Duration(days: (i + 1) * 6 - 1));
      final end = today.subtract(Duration(days: i * 6));
      final isCurrent = i == 0;

      int onTime = 0;
      int late = 0;
      int skipped = 0;

      for (final e in events) {
        final d = DateTime(e.occurredAt.year, e.occurredAt.month, e.occurredAt.day);
        if (!d.isBefore(start) && !d.isAfter(end)) {
          switch (e.action) {
            case DoseAction.taken:
              onTime++;
              break;
            case DoseAction.late:
              late++;
              break;
            case DoseAction.skipped:
              skipped++;
              break;
          }
        }
      }

      final label = '${end.month}/${end.day}';
      final fullLabel =
          '${_monthNames[start.month - 1]} ${start.day} – ${_monthNames[end.month - 1]} ${end.day}';

      buckets.add(AdherenceBucket(
        label: label,
        fullLabel: fullLabel,
        startDate: start,
        endDate: end,
        isCurrent: isCurrent,
        onTimeCount: onTime,
        lateCount: late,
        skippedCount: skipped,
      ));
    }

    return buckets;
  }

  static List<AdherenceBucket> _build90DayBuckets(
    List<DoseEvent> events,
    DateTime today,
  ) {
    // 6 bi-weekly buckets (15 days each)
    final buckets = <AdherenceBucket>[];

    for (int i = 5; i >= 0; i--) {
      final start = today.subtract(Duration(days: (i + 1) * 15 - 1));
      final end = today.subtract(Duration(days: i * 15));
      final isCurrent = i == 0;

      int onTime = 0;
      int late = 0;
      int skipped = 0;

      for (final e in events) {
        final d = DateTime(e.occurredAt.year, e.occurredAt.month, e.occurredAt.day);
        if (!d.isBefore(start) && !d.isAfter(end)) {
          switch (e.action) {
            case DoseAction.taken:
              onTime++;
              break;
            case DoseAction.late:
              late++;
              break;
            case DoseAction.skipped:
              skipped++;
              break;
          }
        }
      }

      final label = '${end.month}/${end.day}';
      final fullLabel =
          '${_monthNames[start.month - 1]} ${start.day} – ${_monthNames[end.month - 1]} ${end.day}';

      buckets.add(AdherenceBucket(
        label: label,
        fullLabel: fullLabel,
        startDate: start,
        endDate: end,
        isCurrent: isCurrent,
        onTimeCount: onTime,
        lateCount: late,
        skippedCount: skipped,
      ));
    }

    return buckets;
  }

  static List<AdherenceBucket> _build1YearBuckets(
    List<DoseEvent> events,
    DateTime today,
  ) {
    // 12 monthly buckets ending with today's month
    final buckets = <AdherenceBucket>[];

    for (int i = 11; i >= 0; i--) {
      // Calculate month and year
      int targetMonth = today.month - i;
      int targetYear = today.year;
      while (targetMonth <= 0) {
        targetMonth += 12;
        targetYear -= 1;
      }

      final start = DateTime(targetYear, targetMonth, 1);
      final daysInMonth = DateTime(targetYear, targetMonth + 1, 0).day;
      final end = DateTime(targetYear, targetMonth, daysInMonth);
      final isCurrent = i == 0;

      int onTime = 0;
      int late = 0;
      int skipped = 0;

      for (final e in events) {
        final d = DateTime(e.occurredAt.year, e.occurredAt.month, e.occurredAt.day);
        if (!d.isBefore(start) && !d.isAfter(end)) {
          switch (e.action) {
            case DoseAction.taken:
              onTime++;
              break;
            case DoseAction.late:
              late++;
              break;
            case DoseAction.skipped:
              skipped++;
              break;
          }
        }
      }

      final label = _monthNames[targetMonth - 1][0]; // single letter initial 'J', 'F', etc.
      final fullLabel = '${_monthNames[targetMonth - 1]} $targetYear';

      buckets.add(AdherenceBucket(
        label: label,
        fullLabel: fullLabel,
        startDate: start,
        endDate: end,
        isCurrent: isCurrent,
        onTimeCount: onTime,
        lateCount: late,
        skippedCount: skipped,
      ));
    }

    return buckets;
  }
}
