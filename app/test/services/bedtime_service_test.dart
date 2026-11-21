import 'package:flutter/material.dart' show Colors, TimeOfDay;
import 'package:flutter_test/flutter_test.dart';
import 'package:pillpal/core/scheduling/reminder_scheduler.dart';
import 'package:pillpal/data/models/prescription.dart';
import 'package:pillpal/data/models/profile.dart';
import 'package:pillpal/services/bedtime_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  group('BedtimeQuietHours geometry', () {
    test('handles overnight schedule crossing midnight (10:00 PM -> 7:00 AM)',
        () {
      final schedule = BedtimeSchedule.everyDay(
        isEnabled: true,
        bedtime: '10:00 PM',
        wakeTime: '7:00 AM',
      );

      // Monday 9:59 PM -> outside
      expect(
        BedtimeQuietHours.activeWindowAt(
          schedule,
          DateTime(2026, 10, 26, 21, 59),
        ),
        isNull,
      );
      // Monday 10:00 PM -> inside
      expect(
        BedtimeQuietHours.activeWindowAt(
          schedule,
          DateTime(2026, 10, 26, 22, 0),
        ),
        isNotNull,
      );
      // Tuesday 2:30 AM (overnight spillover from Monday) -> inside
      expect(
        BedtimeQuietHours.activeWindowAt(
          schedule,
          DateTime(2026, 10, 27, 2, 30),
        ),
        isNotNull,
      );
      // Tuesday 7:00 AM (wake time exclusive) -> outside
      expect(
        BedtimeQuietHours.activeWindowAt(
          schedule,
          DateTime(2026, 10, 27, 7, 0),
        ),
        isNull,
      );

      // Wall-clock reminder checks
      expect(
        BedtimeQuietHours.isTimeSlotInQuietHours(
          schedule: schedule,
          timeSlot: '11:00 PM',
          weekday: DateTime.monday,
        ),
        isTrue,
      );
      expect(
        BedtimeQuietHours.isTimeSlotInQuietHours(
          schedule: schedule,
          timeSlot: '5:30 AM',
          weekday: DateTime.tuesday,
        ),
        isTrue,
      );
      expect(
        BedtimeQuietHours.isTimeSlotInQuietHours(
          schedule: schedule,
          timeSlot: '7:00 AM',
          weekday: DateTime.tuesday,
        ),
        isFalse,
      );
      expect(
        BedtimeQuietHours.isTimeSlotInQuietHours(
          schedule: schedule,
          timeSlot: '8:00 PM',
          weekday: DateTime.monday,
        ),
        isFalse,
      );
    });

    test('handles same-day start < end schedule (1:00 AM -> 9:00 AM)', () {
      final schedule = BedtimeSchedule.everyDay(
        isEnabled: true,
        bedtime: '1:00 AM',
        wakeTime: '9:00 AM',
      );

      // 11:30 PM -> awake (outside quiet hours!)
      expect(
        BedtimeQuietHours.activeWindowAt(
          schedule,
          DateTime(2026, 10, 26, 23, 30),
        ),
        isNull,
      );
      // 1:00 AM -> inside
      expect(
        BedtimeQuietHours.activeWindowAt(
          schedule,
          DateTime(2026, 10, 27, 1, 0),
        ),
        isNotNull,
      );
      // 8:59 AM -> inside
      expect(
        BedtimeQuietHours.activeWindowAt(
          schedule,
          DateTime(2026, 10, 27, 8, 59),
        ),
        isNotNull,
      );
      // 9:00 AM -> outside
      expect(
        BedtimeQuietHours.activeWindowAt(
          schedule,
          DateTime(2026, 10, 27, 9, 0),
        ),
        isNull,
      );

      // Reminders at 11:00 PM and 10:00 AM allowed; 3:00 AM blocked
      expect(
        shouldScheduleReminder(
          time: '11:00 PM',
          bedtimeSchedule: schedule,
          weekday: DateTime.monday,
          allowAfterBedtime: false,
        ),
        isTrue,
      );
      expect(
        shouldScheduleReminder(
          time: '3:00 AM',
          bedtimeSchedule: schedule,
          weekday: DateTime.monday,
          allowAfterBedtime: false,
        ),
        isFalse,
      );
      expect(
        shouldScheduleReminder(
          time: '10:00 AM',
          bedtimeSchedule: schedule,
          weekday: DateTime.monday,
          allowAfterBedtime: false,
        ),
        isTrue,
      );
    });

    test('handles daytime shift worker schedule (9:00 AM -> 5:00 PM)', () {
      final schedule = BedtimeSchedule.everyDay(
        isEnabled: true,
        bedtime: '9:00 AM',
        wakeTime: '5:00 PM',
      );

      expect(
        BedtimeQuietHours.isTimeOfDayInWindow(
          time: const TimeOfDay(hour: 12, minute: 0),
          bedtime: const TimeOfDay(hour: 9, minute: 0),
          wakeTime: const TimeOfDay(hour: 17, minute: 0),
        ),
        isTrue,
      );
      expect(
        BedtimeQuietHours.isTimeOfDayInWindow(
          time: const TimeOfDay(hour: 22, minute: 0),
          bedtime: const TimeOfDay(hour: 9, minute: 0),
          wakeTime: const TimeOfDay(hour: 17, minute: 0),
        ),
        isFalse,
      );
      // At 8:45 AM requesting 30m snooze -> clamped to 15m (ends at 9:00 AM)
      expect(
        BedtimeQuietHours.clampSnoozeMinutes(
          schedule: schedule,
          now: DateTime(2026, 10, 26, 8, 45),
          requestedMinutes: 30,
        ),
        15,
      );
    });

    test('handles 7-day custom schedule with disabled day & overnight spillover',
        () {
      // Saturday 11:30 PM -> 8:00 AM; Sunday disabled
      final custom = BedtimeSchedule.everyDay(
        isEnabled: true,
        bedtime: '10:00 PM',
        wakeTime: '7:00 AM',
      )
          .switchedToMode(BedtimeScheduleMode.custom)
          .withDay(
            DateTime.saturday,
            const DayBedtimeWindow(
              enabled: true,
              bedtime: '11:30 PM',
              wakeTime: '8:00 AM',
            ),
          )
          .withDay(
            DateTime.sunday,
            const DayBedtimeWindow(
              enabled: false,
              bedtime: '10:00 PM',
              wakeTime: '7:00 AM',
            ),
          );

      // Sunday 7:30 AM is still inside Saturday's 11:30 PM -> 8:00 AM window
      expect(
        BedtimeQuietHours.isTimeSlotInQuietHours(
          schedule: custom,
          timeSlot: '7:30 AM',
          weekday: DateTime.sunday,
        ),
        isTrue,
      );
      // Sunday 11:00 PM is allowed because Sunday quiet hours are off
      expect(
        BedtimeQuietHours.isTimeSlotInQuietHours(
          schedule: custom,
          timeSlot: '11:00 PM',
          weekday: DateTime.sunday,
        ),
        isFalse,
      );
      // Monday 5:00 AM is allowed because Sunday was off (no overnight spillover)
      expect(
        BedtimeQuietHours.isTimeSlotInQuietHours(
          schedule: custom,
          timeSlot: '5:00 AM',
          weekday: DateTime.monday,
        ),
        isFalse,
      );
    });
  });

  group('BedtimeService pauseTonight & auto-resume at next bedtime', () {
    test('pausing before tonight\'s bedtime skips tonight and resumes tomorrow\'s bedtime',
        () async {
      // Monday Oct 26, 2026 at 2:00 PM
      var now = DateTime(2026, 10, 26, 14, 0);
      final service = BedtimeService(
        clock: () => now,
        initialSchedule: BedtimeSchedule.weekdaysAndWeekends(
          isEnabled: true,
          weekdayWindow: const DayBedtimeWindow(
            enabled: true,
            bedtime: '10:00 PM',
            wakeTime: '7:00 AM',
          ),
          weekendWindow: const DayBedtimeWindow(
            enabled: true,
            bedtime: '11:30 PM',
            wakeTime: '8:30 AM',
          ),
        ),
      );
      await service.load();

      // Pause Monday at 2:00 PM -> skips Monday night, resumes Tuesday 10:00 PM
      final resumeAt = await service.pauseTonight();
      expect(resumeAt, DateTime(2026, 10, 27, 22, 0));
      expect(service.isPausedAt(), isTrue);

      // Monday 11:00 PM -> still paused, NOT in quiet hours
      now = DateTime(2026, 10, 26, 23, 0);
      expect(service.isPausedAt(), isTrue);
      expect(service.isInQuietHours(), isFalse);
      expect(
        service.shouldScheduleReminder(
          timeSlot: '11:00 PM',
          allowAfterBedtime: false,
        ),
        isTrue,
      );

      // Tuesday 2:00 AM -> still paused
      now = DateTime(2026, 10, 27, 2, 0);
      expect(service.isPausedAt(), isTrue);
      expect(service.isInQuietHours(), isFalse);

      // Tuesday 10:00 PM -> auto-resumed right at Tuesday's bedtime!
      now = DateTime(2026, 10, 27, 22, 0);
      expect(service.isPausedAt(), isFalse);
      expect(service.isInQuietHours(), isTrue);
      expect(await service.clearExpiredPause(), isTrue);
    });

    test('pausing during quiet hours (including after midnight) resumes at next bedtime',
        () async {
      // Friday Oct 30, 2026 at 10:30 PM (Weekday 10 PM -> 7 AM; Sat is 11:30 PM -> 8:30 AM)
      var now = DateTime(2026, 10, 30, 22, 30);
      final service = BedtimeService(
        clock: () => now,
        initialSchedule: BedtimeSchedule.weekdaysAndWeekends(
          isEnabled: true,
          weekdayWindow: const DayBedtimeWindow(
            enabled: true,
            bedtime: '10:00 PM',
            wakeTime: '7:00 AM',
          ),
          weekendWindow: const DayBedtimeWindow(
            enabled: true,
            bedtime: '11:30 PM',
            wakeTime: '8:30 AM',
          ),
        ),
      );
      await service.load();

      expect(service.isInQuietHours(), isTrue);
      final resumeAt = await service.pauseTonight();
      // Saturday's bedtime is 11:30 PM!
      expect(resumeAt, DateTime(2026, 10, 31, 23, 30));
      expect(service.isInQuietHours(), isFalse);

      // Saturday 11:00 PM -> still paused (before Saturday's 11:30 PM bedtime)
      now = DateTime(2026, 10, 31, 23, 0);
      expect(service.isPausedAt(), isTrue);

      // Saturday 11:30 PM -> auto-resumes!
      now = DateTime(2026, 10, 31, 23, 30);
      expect(service.isPausedAt(), isFalse);
      expect(service.isInQuietHours(), isTrue);
    });
  });

  group('BedtimeService migration, persistence & summaries', () {
    test('one-time migration seeds from primary profile bedtime with +8h wake time',
        () async {
      final service = BedtimeService();
      await service.load();
      expect(service.isEnabled, isFalse);

      const profiles = [
        Profile(
          id: '1',
          name: 'Me',
          color: Colors.blue,
          isPrimary: true,
          bedtime: '11:00 PM',
        ),
        Profile(
          id: '2',
          name: 'Mom',
          color: Colors.purple,
          bedtime: '9:00 PM',
        ),
      ];

      final migrated = await service.migrateFromProfilesIfNeeded(profiles);
      expect(migrated, isTrue);
      expect(service.isEnabled, isTrue);
      expect(service.schedule.mode, BedtimeScheduleMode.everyDay);
      expect(service.schedule.windowForWeekday(DateTime.monday).bedtime,
          '11:00 PM');
      expect(service.schedule.windowForWeekday(DateTime.monday).wakeTime,
          '7:00 AM');

      // Reload from SharedPreferences -> persists and never re-migrates
      final reloaded = BedtimeService();
      await reloaded.load();
      expect(reloaded.isEnabled, isTrue);
      expect(reloaded.schedule.windowForWeekday(DateTime.friday).bedtime,
          '11:00 PM');
      expect(reloaded.schedule.windowForWeekday(DateTime.friday).wakeTime,
          '7:00 AM');
      expect(await reloaded.migrateFromProfilesIfNeeded(profiles), isFalse);
    });

    test('summaryLabel stays concise across Off, Active, and Paused states',
        () async {
      final monday = DateTime(2026, 10, 26, 15, 0);
      final service = BedtimeService(clock: () => monday);
      await service.load();

      expect(service.summaryLabel(), 'Off');

      await service.updateSchedule(
        BedtimeSchedule.everyDay(
          isEnabled: true,
          bedtime: '10:00 PM',
          wakeTime: '7:00 AM',
        ),
      );
      expect(service.summaryLabel(), '10:00 PM – 7:00 AM · Every day');

      await service.pauseTonight();
      expect(service.summaryLabel(), 'Paused tonight · Resumes Tue 10:00 PM');

      await service.resumeNow();
      await service.updateSchedule(
        BedtimeSchedule.weekdaysAndWeekends(isEnabled: true),
      );
      expect(service.summaryLabel(), 'Tonight: 10:00 PM – 7:00 AM · Weekdays');

      final saturday = DateTime(2026, 10, 31, 15, 0);
      expect(
        service.summaryLabel(now: saturday),
        'Tonight: 11:00 PM – 8:00 AM · Weekends',
      );
    });

    test('consolidated device-level pending count aggregates all profiles', () {
      final schedule = BedtimeSchedule.everyDay(
        isEnabled: true,
        bedtime: '10:00 PM',
        wakeTime: '7:00 AM',
      );
      final meds = [
        const Prescription(
          id: 'rx1',
          profileId: '1',
          name: 'Med1',
          dosage: '10mg',
          reminderTimes: ['8:00 AM', '11:00 PM'],
          remaining: 10,
          daysSupply: 10,
        ),
        const Prescription(
          id: 'rx2',
          profileId: '2',
          name: 'Med2',
          dosage: '20mg',
          reminderTimes: ['8:00 PM'],
          remaining: 10,
          daysSupply: 10,
        ),
      ];

      expect(
        calculateDevicePendingDosesBeforeBedtime(
          prescriptions: meds,
          bedtimeSchedule: schedule,
          weekday: DateTime.monday,
        ),
        2, // 8:00 AM (p1) + 8:00 PM (p2); 11:00 PM blocked
      );
    });
  });
}
