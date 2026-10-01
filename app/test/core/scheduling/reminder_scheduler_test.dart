import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pillpal/core/scheduling/reminder_scheduler.dart';

void main() {
  group('parseFrequencyIntervalHours', () {
    const periodicCases = {
      'every 8 hours': 8,
      'every 12 hours': 12,
      'every 6 hours': 6,
      'every 4 to 6 hours': 4,
      'q6h': 6,
      'q8h': 8,
      'twice a day': 12,
      'once a day': 24,
      'three times a day': 8,
      'once daily': 24,
      'twice daily': 12,
      'three times daily': 8,
      'four times daily': 6,
      'daily': 24,
      '2 times per day': 12,
      '3 times per day': 8,
      'BID': 12,
      'TID': 8,
      'QID': 6,
    };

    for (final entry in periodicCases.entries) {
      test('"${entry.key}" -> ${entry.value}h interval', () {
        expect(parseFrequencyIntervalHours(entry.key), entry.value);
      });
    }

    const nonPeriodicCases = [
      'as needed',
      'as needed for pain',
      'as needed for anxiety',
      'with meals',
      'before meals',
      'every other day',
      'weekly',
      'once weekly',
      'every night at bedtime',
      'at bedtime',
      'every morning',
      'every evening',
      'in the morning and evening',
      'at the first sign of migraine',
      'QHS',
    ];

    for (final freq in nonPeriodicCases) {
      test('"$freq" is not periodic -> null', () {
        expect(parseFrequencyIntervalHours(freq), isNull);
      });
    }

    test('null and empty frequency -> null', () {
      expect(parseFrequencyIntervalHours(null), isNull);
      expect(parseFrequencyIntervalHours(''), isNull);
      expect(parseFrequencyIntervalHours('   '), isNull);
    });
  });

  group('buildReminderTimes', () {
    test('null interval -> just the start time', () {
      expect(
        buildReminderTimes(startTime: const TimeOfDay(hour: 8, minute: 0), intervalHours: null),
        [const TimeOfDay(hour: 8, minute: 0)],
      );
    });

    test('every 4 hours from 8am with a 10pm bedtime stops before bedtime', () {
      final times = buildReminderTimes(
        startTime: const TimeOfDay(hour: 8, minute: 0),
        intervalHours: 4,
        bedtime: const TimeOfDay(hour: 22, minute: 0),
      );
      expect(times, [
        const TimeOfDay(hour: 8, minute: 0),
        const TimeOfDay(hour: 12, minute: 0),
        const TimeOfDay(hour: 16, minute: 0),
        const TimeOfDay(hour: 20, minute: 0),
      ]);
    });

    test('no bedtime set falls back to end-of-day (stops before crossing midnight)', () {
      final times = buildReminderTimes(
        startTime: const TimeOfDay(hour: 8, minute: 0),
        intervalHours: 6,
      );
      expect(times, [
        const TimeOfDay(hour: 8, minute: 0),
        const TimeOfDay(hour: 14, minute: 0),
        const TimeOfDay(hour: 20, minute: 0),
      ]);
    });

    test('start time already at/after bedtime yields just the start time', () {
      final times = buildReminderTimes(
        startTime: const TimeOfDay(hour: 23, minute: 0),
        intervalHours: 4,
        bedtime: const TimeOfDay(hour: 22, minute: 0),
      );
      expect(times, [const TimeOfDay(hour: 23, minute: 0)]);
    });

    test('is hard-capped at 6 generated times', () {
      final times = buildReminderTimes(
        startTime: const TimeOfDay(hour: 0, minute: 0),
        intervalHours: 1,
        bedtime: const TimeOfDay(hour: 23, minute: 59),
      );
      expect(times.length, 6);
    });
  });

  group('shouldScheduleReminder', () {
    test('before bedtime -> scheduled', () {
      expect(
        shouldScheduleReminder(time: '8:00 PM', bedtime: '10:00 PM', allowAfterBedtime: false),
        isTrue,
      );
    });

    test('at bedtime exactly -> not scheduled', () {
      expect(
        shouldScheduleReminder(time: '10:00 PM', bedtime: '10:00 PM', allowAfterBedtime: false),
        isFalse,
      );
    });

    test('after bedtime -> not scheduled', () {
      expect(
        shouldScheduleReminder(time: '11:00 PM', bedtime: '10:00 PM', allowAfterBedtime: false),
        isFalse,
      );
    });

    test('after bedtime, but override on -> scheduled', () {
      expect(
        shouldScheduleReminder(time: '11:00 PM', bedtime: '10:00 PM', allowAfterBedtime: true),
        isTrue,
      );
    });

    test('no bedtime set -> always scheduled', () {
      expect(
        shouldScheduleReminder(time: '11:00 PM', bedtime: null, allowAfterBedtime: false),
        isTrue,
      );
    });

    test('unparseable time strings default to scheduled, never silently drop a dose', () {
      expect(
        shouldScheduleReminder(time: 'garbage', bedtime: '10:00 PM', allowAfterBedtime: false),
        isTrue,
      );
      expect(
        shouldScheduleReminder(time: '8:00 PM', bedtime: 'garbage', allowAfterBedtime: false),
        isTrue,
      );
    });
  });

  group('notificationIdFor', () {
    test('is deterministic across calls', () {
      expect(
        notificationIdFor('rx-1', '8:00 AM'),
        notificationIdFor('rx-1', '8:00 AM'),
      );
    });

    test('differs for different times on the same prescription', () {
      expect(
        notificationIdFor('rx-1', '8:00 AM'),
        isNot(notificationIdFor('rx-1', '12:00 PM')),
      );
    });

    test('differs for different prescriptions at the same time', () {
      expect(
        notificationIdFor('rx-1', '8:00 AM'),
        isNot(notificationIdFor('rx-2', '8:00 AM')),
      );
    });

    test('is always a non-negative 31-bit int', () {
      for (final id in [
        notificationIdFor('rx-1', '8:00 AM'),
        notificationIdFor('some-other-id', '11:59 PM'),
        notificationIdFor('', ''),
      ]) {
        expect(id, greaterThanOrEqualTo(0));
        expect(id, lessThanOrEqualTo(0x7FFFFFFF));
      }
    });
  });
}
