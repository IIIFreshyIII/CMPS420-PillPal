import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pillpal/core/scheduling/reminder_scheduler.dart';
import 'package:pillpal/data/models/prescription.dart';
import 'package:pillpal/data/models/profile.dart';

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

  group('Dose Batching Logic (calculateDoseBatch & calculateRemainingDosesCount)', () {
    const profileMe = Profile(
      id: '1',
      name: 'Me',
      color: Colors.blue,
      isPrimary: true,
      bedtime: '10:00 PM',
    );

    const allegra = Prescription(
      id: 'rx-1',
      profileId: '1',
      name: 'Allegra',
      dosage: '10mg',
      reminderTimes: ['8:00 AM'],
      remaining: 14,
      daysSupply: 14,
    );

    const lisinopril = Prescription(
      id: 'rx-2',
      profileId: '1',
      name: 'Lisinopril',
      dosage: '20mg',
      reminderTimes: ['8:00 AM', '8:00 PM'],
      remaining: 10,
      daysSupply: 5,
    );

    const metforminTaken = Prescription(
      id: 'rx-3',
      profileId: '1',
      name: 'Metformin',
      dosage: '500mg',
      reminderTimes: ['8:00 AM', '12:00 PM'],
      takenTimes: {'8:00 AM'},
      remaining: 20,
      daysSupply: 10,
    );

    test('counts all untaken medications sharing the exact scheduled time slot', () {
      final prescriptions = [allegra, lisinopril, metforminTaken];

      final count = calculateRemainingDosesCount(prescriptions, '8:00 AM');
      expect(count, 2);

      final batch = calculateDoseBatch(prescriptions, '8:00 AM');
      expect(batch.batchId, 'batch_08_00');
      expect(batch.timeSlot, '8:00 AM');
      expect(batch.scheduledPrescriptions.length, 3);
      expect(batch.remainingDosesCount, 2);
      expect(batch.medicationNames, ['Allegra', 'Lisinopril']);
    });

    test('matches equivalent time formatting (08:00 am vs 8:00 AM)', () {
      final batch = calculateDoseBatch([allegra, lisinopril], '08:00 am');
      expect(batch.batchId, 'batch_08_00');
      expect(batch.remainingDosesCount, 2);
      expect(batch.medicationNames, ['Allegra', 'Lisinopril']);
    });

    test('excludes medications blocked by profile bedtime when profiles are provided', () {
      const lateMedBlocked = Prescription(
        id: 'rx-late',
        profileId: '1',
        name: 'Melatonin',
        dosage: '5mg',
        reminderTimes: ['11:00 PM'],
        remaining: 30,
        daysSupply: 30,
        allowAfterBedtime: false,
      );
      const lateMedAllowed = Prescription(
        id: 'rx-late-override',
        profileId: '1',
        name: 'Night Med',
        dosage: '10mg',
        reminderTimes: ['11:00 PM'],
        remaining: 30,
        daysSupply: 30,
        allowAfterBedtime: true,
      );

      final batch = calculateDoseBatch(
        [lateMedBlocked, lateMedAllowed],
        '11:00 PM',
        profiles: [profileMe],
      );
      expect(batch.remainingDosesCount, 1);
      expect(batch.medicationNames, ['Night Med']);
    });

    test('resolves profileName for single-profile batches and null for multi-profile', () {
      const profileLeo = Profile(
        id: '1',
        name: 'Leo',
        color: Colors.blue,
        isPrimary: true,
      );
      const profileMom = Profile(
        id: '2',
        name: 'Mom',
        color: Colors.purple,
      );

      const medLeo1 = Prescription(
        id: 'rx-1',
        profileId: '1',
        name: 'Allegra',
        dosage: '10mg',
        reminderTimes: ['8:00 AM'],
        remaining: 10,
        daysSupply: 10,
      );
      const medLeo2 = Prescription(
        id: 'rx-2',
        profileId: '1',
        name: 'Lisinopril',
        dosage: '20mg',
        reminderTimes: ['8:00 AM'],
        remaining: 10,
        daysSupply: 10,
      );
      const medMom = Prescription(
        id: 'rx-3',
        profileId: '2',
        name: 'Vitamin D',
        dosage: '1000IU',
        reminderTimes: ['8:00 AM'],
        remaining: 10,
        daysSupply: 10,
      );

      // Single profile batch -> "Leo"
      final leoBatch = calculateDoseBatch(
        [medLeo1, medLeo2],
        '8:00 AM',
        profiles: [profileLeo, profileMom],
      );
      expect(leoBatch.profileName, 'Leo');
      expect(leoBatch.remainingDosesCount, 2);

      // Multi-profile batch -> null
      final mixedBatch = calculateDoseBatch(
        [medLeo1, medMom],
        '8:00 AM',
        profiles: [profileLeo, profileMom],
      );
      expect(mixedBatch.profileName, isNull);
      expect(mixedBatch.remainingDosesCount, 2);

      // No profiles passed -> null
      final unassignedBatch = calculateDoseBatch(
        [medLeo1],
        '8:00 AM',
      );
      expect(unassignedBatch.profileName, isNull);
    });
  });

  group('Pre-Bedtime Snooze Clamp Logic (clampSnoozeDurationToBedtime)', () {
    test('snooze duration before bedtime is unclamped', () {
      // 9:00 PM, requested 30m, bedtime 10:00 PM -> ends at 9:30 PM (before 10:00 PM)
      final now = DateTime(2026, 10, 26, 21, 0);
      final clamped = clampSnoozeDurationToBedtime(
        now: now,
        requestedMinutes: 30,
        bedtime: '10:00 PM',
      );
      expect(clamped, 30);
    });

    test('snooze duration exceeding bedtime is clamped to end at bedtime', () {
      // 9:45 PM, requested 30m, bedtime 10:00 PM -> would end at 10:15 PM -> clamped to 15m
      final now = DateTime(2026, 10, 26, 21, 45);
      final clamped = clampSnoozeDurationToBedtime(
        now: now,
        requestedMinutes: 30,
        bedtime: '10:00 PM',
      );
      expect(clamped, 15);
    });

    test('snooze duration requested at or past bedtime returns 0', () {
      // 10:00 PM exactly -> 0
      final atBedtime = DateTime(2026, 10, 26, 22, 0);
      expect(
        clampSnoozeDurationToBedtime(
          now: atBedtime,
          requestedMinutes: 15,
          bedtime: '10:00 PM',
        ),
        0,
      );

      // 10:15 PM (past bedtime) -> 0
      final pastBedtime = DateTime(2026, 10, 26, 22, 15);
      expect(
        clampSnoozeDurationToBedtime(
          now: pastBedtime,
          requestedMinutes: 15,
          bedtime: '10:00 PM',
        ),
        0,
      );
    });

    test('handles early morning bedtime after midnight', () {
      // 11:30 PM, requested 90m, bedtime 12:30 AM (next morning) -> 60m remaining
      final now = DateTime(2026, 10, 26, 23, 30);
      final clamped = clampSnoozeDurationToBedtime(
        now: now,
        requestedMinutes: 90,
        bedtime: '12:30 AM',
      );
      expect(clamped, 60);
    });

    test('null or invalid bedtime falls back to requested minutes', () {
      final now = DateTime(2026, 10, 26, 21, 45);
      expect(
        clampSnoozeDurationToBedtime(now: now, requestedMinutes: 30, bedtime: null),
        30,
      );
      expect(
        clampSnoozeDurationToBedtime(now: now, requestedMinutes: 30, bedtime: 'invalid'),
        30,
      );
    });

    test('isAtOrPastBedtime correctly detects bedtime blackout window', () {
      expect(
        isAtOrPastBedtime(
          dateTime: DateTime(2026, 10, 26, 21, 59),
          bedtime: '10:00 PM',
        ),
        isFalse,
      );
      expect(
        isAtOrPastBedtime(
          dateTime: DateTime(2026, 10, 26, 22, 0),
          bedtime: '10:00 PM',
        ),
        isTrue,
      );
      expect(
        isAtOrPastBedtime(
          dateTime: DateTime(2026, 10, 26, 22, 30),
          bedtime: '10:00 PM',
        ),
        isTrue,
      );
    });
  });

  group('Pre-Bedtime Final Call Handling', () {
    const profileLeo = Profile(
      id: 'p1',
      name: 'Leo',
      color: Colors.blue,
      isPrimary: true,
      bedtime: '10:00 PM',
    );

    const morningMed = Prescription(
      id: 'rx-1',
      profileId: 'p1',
      name: 'Allegra',
      dosage: '10mg',
      reminderTimes: ['8:00 AM'],
      remaining: 10,
      daysSupply: 10,
    );
    const eveningMed = Prescription(
      id: 'rx-2',
      profileId: 'p1',
      name: 'Lisinopril',
      dosage: '20mg',
      reminderTimes: ['8:00 PM'],
      remaining: 10,
      daysSupply: 10,
    );
    const postBedtimeMed = Prescription(
      id: 'rx-3',
      profileId: 'p1',
      name: 'Night Med',
      dosage: '10mg',
      reminderTimes: ['11:00 PM'],
      remaining: 10,
      daysSupply: 10,
      allowAfterBedtime: false,
    );

    test('calculatePendingDosesBeforeBedtime counts untaken doses scheduled before bedtime', () {
      final allUntaken = [morningMed, eveningMed, postBedtimeMed];
      expect(
        calculatePendingDosesBeforeBedtime(
          profile: profileLeo,
          prescriptions: allUntaken,
        ),
        2, // 8:00 AM and 8:00 PM (11:00 PM excluded by bedtime)
      );

      final oneTaken = [
        morningMed.copyWith(takenTimes: {'8:00 AM'}),
        eveningMed,
        postBedtimeMed,
      ];
      expect(
        calculatePendingDosesBeforeBedtime(
          profile: profileLeo,
          prescriptions: oneTaken,
        ),
        1, // Only 8:00 PM remains
      );

      final allTaken = [
        morningMed.copyWith(takenTimes: {'8:00 AM'}),
        eveningMed.copyWith(takenTimes: {'8:00 PM'}),
        postBedtimeMed,
      ];
      expect(
        calculatePendingDosesBeforeBedtime(
          profile: profileLeo,
          prescriptions: allTaken,
        ),
        0,
      );
    });

    test('calculatePreBedtimeNotificationTime defaults to 10 minutes prior to bedtime', () {
      final tod10pm = calculatePreBedtimeNotificationTime(bedtime: '10:00 PM');
      expect(tod10pm, const TimeOfDay(hour: 21, minute: 50)); // 9:50 PM

      final todMidnightWrap = calculatePreBedtimeNotificationTime(bedtime: '12:05 AM');
      expect(todMidnightWrap, const TimeOfDay(hour: 23, minute: 55)); // 11:55 PM previous day
    });

    test('formatPreBedtimeFinalCallMessage formats exact professional message', () {
      final msgMultiple = formatPreBedtimeFinalCallMessage(
        pendingDosesCount: 2,
        bedtime: '10:00 PM',
      );
      expect(
        msgMultiple,
        'Bedtime Reminder: You have 2 pending doses scheduled before your 10:00 PM bedtime. Please log or review your medications before going to sleep.',
      );

      final msgSingle = formatPreBedtimeFinalCallMessage(
        pendingDosesCount: 1,
        bedtime: '10:00 PM',
      );
      expect(
        msgSingle,
        'Bedtime Reminder: You have 1 pending dose scheduled before your 10:00 PM bedtime. Please log or review your medications before going to sleep.',
      );
    });

    test('notificationIdForPreBedtime is stable and positive', () {
      final id1 = notificationIdForPreBedtime('p1');
      final id2 = notificationIdForPreBedtime('p1');
      final idOther = notificationIdForPreBedtime('p2');

      expect(id1, id2);
      expect(id1, isNot(idOther));
      expect(id1, greaterThanOrEqualTo(0));
    });
  });
}
