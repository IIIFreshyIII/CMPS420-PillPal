import 'package:flutter_test/flutter_test.dart';
import 'package:pillpal/core/utils/adherence_calculator.dart';
import 'package:pillpal/data/models/dose_event.dart';

void main() {
  final refDate = DateTime(2026, 10, 10, 12, 0);

  test('calculates empty events summary correctly', () {
    final summary = AdherenceCalculator.calculate(
      events: const [],
      range: AdherenceTimeRange.sevenDays,
      now: refDate,
    );

    expect(summary.totalLogged, 0);
    expect(summary.adherencePercentage, 0);
    expect(summary.statusLabel, 'No Logs Yet');
    expect(summary.buckets.length, 7);
    expect(summary.buckets.every((b) => b.totalCount == 0), isTrue);
  });

  test('calculates 7-day buckets with on-time, late, and skipped doses', () {
    final events = [
      // Today (Oct 10): 2 on time
      DoseEvent(
        id: '1',
        prescriptionId: 'rx1',
        profileId: 'p1',
        occurredAt: DateTime(2026, 10, 10, 8, 0),
        action: DoseAction.taken,
      ),
      DoseEvent(
        id: '2',
        prescriptionId: 'rx2',
        profileId: 'p1',
        occurredAt: DateTime(2026, 10, 10, 12, 0),
        action: DoseAction.taken,
      ),
      // Yesterday (Oct 9): 1 late
      DoseEvent(
        id: '3',
        prescriptionId: 'rx1',
        profileId: 'p1',
        occurredAt: DateTime(2026, 10, 9, 14, 0),
        action: DoseAction.late,
      ),
      // 2 days ago (Oct 8): 1 skipped
      DoseEvent(
        id: '4',
        prescriptionId: 'rx1',
        profileId: 'p1',
        occurredAt: DateTime(2026, 10, 8, 8, 0),
        action: DoseAction.skipped,
      ),
    ];

    final summary = AdherenceCalculator.calculate(
      events: events,
      range: AdherenceTimeRange.sevenDays,
      now: refDate,
    );

    expect(summary.totalLogged, 4);
    expect(summary.onTimeCount, 2);
    expect(summary.lateCount, 1);
    expect(summary.skippedCount, 1);
    expect(summary.buckets.length, 7);

    final todayBucket = summary.buckets.last;
    expect(todayBucket.isCurrent, isTrue);
    expect(todayBucket.onTimeCount, 2);
    expect(todayBucket.lateCount, 0);
    expect(todayBucket.skippedCount, 0);

    final yesterdayBucket = summary.buckets[5];
    expect(yesterdayBucket.lateCount, 1);

    final twoDaysAgoBucket = summary.buckets[4];
    expect(twoDaysAgoBucket.skippedCount, 1);
  });

  test('filters by profile ID correctly', () {
    final events = [
      DoseEvent(
        id: '1',
        prescriptionId: 'rx1',
        profileId: 'p1',
        occurredAt: DateTime(2026, 10, 10, 8, 0),
        action: DoseAction.taken,
      ),
      DoseEvent(
        id: '2',
        prescriptionId: 'rx2',
        profileId: 'p2',
        occurredAt: DateTime(2026, 10, 10, 8, 0),
        action: DoseAction.skipped,
      ),
    ];

    final p1Summary = AdherenceCalculator.calculate(
      events: events,
      range: AdherenceTimeRange.sevenDays,
      selectedProfileId: 'p1',
      now: refDate,
    );
    expect(p1Summary.totalLogged, 1);
    expect(p1Summary.onTimeCount, 1);
    expect(p1Summary.skippedCount, 0);

    final allSummary = AdherenceCalculator.calculate(
      events: events,
      range: AdherenceTimeRange.sevenDays,
      selectedProfileId: 'all',
      now: refDate,
    );
    expect(allSummary.totalLogged, 2);
  });

  test('generates buckets for 30D, 90D, and 1Y ranges', () {
    final summary30 = AdherenceCalculator.calculate(
      events: const [],
      range: AdherenceTimeRange.thirtyDays,
      now: refDate,
    );
    expect(summary30.buckets.length, 5);

    final summary90 = AdherenceCalculator.calculate(
      events: const [],
      range: AdherenceTimeRange.ninetyDays,
      now: refDate,
    );
    expect(summary90.buckets.length, 6);

    final summary1Y = AdherenceCalculator.calculate(
      events: const [],
      range: AdherenceTimeRange.oneYear,
      now: refDate,
    );
    expect(summary1Y.buckets.length, 12);
  });
}
