import 'package:flutter/material.dart' show Colors;
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pillpal/data/models/prescription.dart';
import 'package:pillpal/data/models/profile.dart';
import 'package:pillpal/services/bedtime_service.dart';
import 'package:pillpal/services/live_reminder_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const channel = MethodChannel(LiveReminderService.channelName);
  late List<MethodCall> recordedCalls;
  late LiveReminderService service;
  final fixedNow = DateTime.fromMillisecondsSinceEpoch(1700000000000);

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    recordedCalls = <MethodCall>[];
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (MethodCall call) async {
      recordedCalls.add(call);
      return null;
    });

    final snoozeSettings = SnoozeSettingsService();
    await snoozeSettings.load();

    service = LiveReminderService(
      channel: channel,
      snoozeSettings: snoozeSettings,
      clock: () => fixedNow,
    );
  });

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, null);
  });

  test(
      'startSnoozeActivity passes batchId, snoozeDurationMinutes, snoozeEndTimestampMs, remainingCount, medicationNames, and profileName',
      () async {
    await service.startSnoozeActivity(
      batchId: 'batch_08_00',
      snoozeDurationMinutes: 15,
      remainingCount: 2,
      medicationNames: const ['Allegra', 'Lisinopril'],
      profileName: 'Leo',
    );

    expect(recordedCalls, hasLength(1));
    expect(recordedCalls.single.method, 'startSnoozeActivity');
    expect(
      recordedCalls.single.arguments,
      <String, dynamic>{
        'batchId': 'batch_08_00',
        'snoozeDurationMinutes': 15,
        'snoozeEndTimestampMs': 1700000000000 + (15 * 60 * 1000),
        'remainingCount': 2,
        'remainingDoseCount': 2,
        'medicationNames': ['Allegra', 'Lisinopril'],
        'profileName': 'Leo',
      },
    );
  });

  test('updateRemainingDoses invokes native channel with updated count, names, and profileName',
      () async {
    await service.updateRemainingDoses(
      batchId: 'batch_08_00',
      remainingCount: 1,
      medicationNames: const ['Lisinopril'],
      profileName: 'Leo',
    );

    expect(recordedCalls, hasLength(1));
    expect(recordedCalls.single.method, 'updateRemainingDoses');
    expect(
      recordedCalls.single.arguments,
      <String, dynamic>{
        'batchId': 'batch_08_00',
        'remainingCount': 1,
        'remainingDoseCount': 1,
        'medicationNames': ['Lisinopril'],
        'profileName': 'Leo',
      },
    );
  });

  test('dismissActivity invokes native channel with batchId', () async {
    await service.dismissActivity(batchId: 'batch_08_00');

    expect(recordedCalls, hasLength(1));
    expect(recordedCalls.single.method, 'dismissActivity');
    expect(
      recordedCalls.single.arguments,
      <String, dynamic>{'batchId': 'batch_08_00'},
    );
  });

  test(
      'startSnoozeForTimeSlot batches untaken doses for the slot and includes profileName',
      () async {
    final prescriptions = [
      const Prescription(
        id: '1',
        profileId: 'p1',
        name: 'Allegra',
        dosage: '10mg',
        reminderTimes: ['8:00 AM'],
        remaining: 10,
        daysSupply: 10,
      ),
      const Prescription(
        id: '2',
        profileId: 'p1',
        name: 'Lisinopril',
        dosage: '20mg',
        reminderTimes: ['8:00 AM'],
        remaining: 10,
        daysSupply: 10,
      ),
      const Prescription(
        id: '3',
        profileId: 'p1',
        name: 'Metformin',
        dosage: '500mg',
        reminderTimes: ['8:00 AM'],
        takenTimes: {'8:00 AM'},
        remaining: 10,
        daysSupply: 10,
      ),
    ];

    const profiles = [
      Profile(
        id: 'p1',
        name: 'Leo',
        color: Colors.blue,
        isPrimary: true,
      ),
    ];

    final batch = await service.startSnoozeForTimeSlot(
      timeSlot: '8:00 AM',
      prescriptions: prescriptions,
      profiles: profiles,
    );

    expect(batch.remainingDosesCount, 2);
    expect(batch.profileName, 'Leo');
    expect(recordedCalls, hasLength(1));
    expect(recordedCalls.single.method, 'startSnoozeActivity');
    expect(
      recordedCalls.single.arguments,
      <String, dynamic>{
        'batchId': 'batch_08_00',
        'snoozeDurationMinutes': 15,
        'snoozeEndTimestampMs': 1700000000000 + (15 * 60 * 1000),
        'remainingCount': 2,
        'remainingDoseCount': 2,
        'medicationNames': ['Allegra', 'Lisinopril'],
        'profileName': 'Leo',
      },
    );
  });

  test('startSnoozeForTimeSlot clamps snooze duration when extending past profile bedtime',
      () async {
    // Current time: 9:45 PM on 2026-10-26
    final eveningClock = DateTime(2026, 10, 26, 21, 45);
    final eveningService = LiveReminderService(
      channel: channel,
      clock: () => eveningClock,
    );

    const prescriptions = [
      Prescription(
        id: '1',
        profileId: 'p1',
        name: 'Night Med',
        dosage: '10mg',
        reminderTimes: ['9:30 PM'],
        remaining: 10,
        daysSupply: 10,
      ),
    ];

    const profiles = [
      Profile(
        id: 'p1',
        name: 'Leo',
        color: Colors.blue,
        isPrimary: true,
        bedtime: '10:00 PM',
      ),
    ];

    // Request 30-minute snooze at 9:45 PM -> would reach 10:15 PM -> clamped to 15m (10:00 PM)
    final batch = await eveningService.startSnoozeForTimeSlot(
      timeSlot: '9:30 PM',
      prescriptions: prescriptions,
      profiles: profiles,
      snoozeDurationMinutes: 30,
    );

    expect(batch.remainingDosesCount, 1);
    expect(recordedCalls.last.method, 'startSnoozeActivity');
    expect(recordedCalls.last.arguments['snoozeDurationMinutes'], 15);
    expect(
      recordedCalls.last.arguments['snoozeEndTimestampMs'],
      DateTime(2026, 10, 26, 22, 0).millisecondsSinceEpoch,
    );
  });

  test('startSnoozeForTimeSlot automatically dismisses if already past bedtime',
      () async {
    // Current time: 10:15 PM, bedtime was 10:00 PM
    final pastBedtimeClock = DateTime(2026, 10, 26, 22, 15);
    final pastBedtimeService = LiveReminderService(
      channel: channel,
      clock: () => pastBedtimeClock,
    );

    const prescriptions = [
      Prescription(
        id: '1',
        profileId: 'p1',
        name: 'Night Med',
        dosage: '10mg',
        reminderTimes: ['9:30 PM'],
        remaining: 10,
        daysSupply: 10,
      ),
    ];

    const profiles = [
      Profile(
        id: 'p1',
        name: 'Leo',
        color: Colors.blue,
        isPrimary: true,
        bedtime: '10:00 PM',
      ),
    ];

    await pastBedtimeService.startSnoozeForTimeSlot(
      timeSlot: '9:30 PM',
      prescriptions: prescriptions,
      profiles: profiles,
      snoozeDurationMinutes: 15,
    );

    expect(recordedCalls.last.method, 'dismissActivity');
    expect(recordedCalls.last.arguments['batchId'], 'batch_21_30');
  });

  test('syncTimeSlotDoses updates when doses remain and dismisses when all taken',
      () async {
    final oneRemaining = [
      const Prescription(
        id: '1',
        profileId: 'p1',
        name: 'Allegra',
        dosage: '10mg',
        reminderTimes: ['8:00 AM'],
        takenTimes: {'8:00 AM'},
        remaining: 10,
        daysSupply: 10,
      ),
      const Prescription(
        id: '2',
        profileId: 'p1',
        name: 'Lisinopril',
        dosage: '20mg',
        reminderTimes: ['8:00 AM'],
        remaining: 10,
        daysSupply: 10,
      ),
    ];

    await service.syncTimeSlotDoses(
      timeSlot: '8:00 AM',
      prescriptions: oneRemaining,
    );
    expect(recordedCalls.last.method, 'updateRemainingDoses');
    expect(recordedCalls.last.arguments['remainingCount'], 1);

    final allTaken = [
      oneRemaining[0],
      oneRemaining[1].copyWith(takenTimes: {'8:00 AM'}),
    ];
    await service.syncTimeSlotDoses(
      timeSlot: '8:00 AM',
      prescriptions: allTaken,
    );
    expect(recordedCalls.last.method, 'dismissActivity');
    expect(recordedCalls.last.arguments['batchId'], 'batch_08_00');
  });

  test('startSnoozeForTimeSlot respects bedtime bypass until 6:00 AM', () async {
    var currentTime = DateTime(2026, 10, 26, 22, 15); // 10:15 PM (past 10:00 PM)
    final snoozeSettings = SnoozeSettingsService(clock: () => currentTime);
    await snoozeSettings.load();

    final eveningService = LiveReminderService(
      channel: channel,
      snoozeSettings: snoozeSettings,
      clock: () => currentTime,
    );

    const prescriptions = [
      Prescription(
        id: '1',
        profileId: 'p1',
        name: 'Night Med',
        dosage: '10mg',
        reminderTimes: ['9:30 PM'],
        remaining: 10,
        daysSupply: 10,
      ),
    ];
    const profiles = [
      Profile(
        id: 'p1',
        name: 'Leo',
        color: Colors.blue,
        isPrimary: true,
        bedtime: '10:00 PM',
      ),
    ];

    // Without bypass -> blockedByBedtime
    await eveningService.startSnoozeForTimeSlot(
      timeSlot: '9:30 PM',
      prescriptions: prescriptions,
      profiles: profiles,
      snoozeDurationMinutes: 15,
    );
    expect(eveningService.lastStartOutcome?.status,
        SnoozeStartStatus.blockedByBedtime);

    // Pause bedtime quiet hours until 6:00 AM next morning
    final resetAt = await snoozeSettings.pauseBedtimeUntilMorning();
    expect(resetAt, DateTime(2026, 10, 27, 6, 0));
    expect(snoozeSettings.isBedtimeBypassed(), isTrue);

    await eveningService.startSnoozeForTimeSlot(
      timeSlot: '9:30 PM',
      prescriptions: prescriptions,
      profiles: profiles,
      snoozeDurationMinutes: 15,
    );
    expect(eveningService.lastStartOutcome?.status, SnoozeStartStatus.started);
    expect(eveningService.lastStartOutcome?.effectiveDurationMinutes, 15);
    expect(
      eveningService.activeSnoozeEndForTimeSlot('9:30 PM'),
      DateTime(2026, 10, 26, 22, 30),
    );

    // After 6:00 AM next morning, bypass expires automatically
    currentTime = DateTime(2026, 10, 27, 6, 1);
    expect(snoozeSettings.isBedtimeBypassed(), isFalse);
    final cleared = await snoozeSettings.clearExpiredBedtimeBypass();
    expect(cleared, isTrue);
  });

  test('calculateNextMorningReset handles late-night past-midnight pause cleanly',
      () {
    expect(
      calculateNextMorningReset(DateTime(2026, 10, 27, 1, 30)),
      DateTime(2026, 10, 27, 6, 0),
    );
    expect(
      calculateNextMorningReset(DateTime(2026, 10, 26, 14, 0)),
      DateTime(2026, 10, 27, 6, 0),
    );
  });

  test('startSnoozeActivity surfaces LIVE_ACTIVITIES_DISABLED in lastStartOutcome',
      () async {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (MethodCall call) async {
      throw PlatformException(
        code: 'LIVE_ACTIVITIES_DISABLED',
        message: 'Live Activities are disabled in iOS Settings.',
      );
    });

    await service.startSnoozeActivity(
      batchId: 'batch_08_00',
      snoozeDurationMinutes: 15,
      remainingCount: 1,
    );

    expect(
      service.lastStartOutcome?.status,
      SnoozeStartStatus.liveActivitiesDisabled,
    );
    expect(service.lastStartOutcome?.snoozeEndTime, isNotNull);
  });

  test('shouldSuppressFollowUpNudgeForSnooze prevents double-buzzing near Touch 2',
      () {
    final nudge9am = DateTime(2026, 10, 26, 9, 0);
    // Snooze ends at 8:15 AM -> 45m before 9 AM nudge -> keep Touch 2 as safety net
    expect(
      shouldSuppressFollowUpNudgeForSnooze(
        nudgeTime: nudge9am,
        activeSnoozeEnd: DateTime(2026, 10, 26, 8, 15),
      ),
      isFalse,
    );
    // Snooze ends at 8:50 AM -> within 20m of 9 AM nudge -> suppress Touch 2
    expect(
      shouldSuppressFollowUpNudgeForSnooze(
        nudgeTime: nudge9am,
        activeSnoozeEnd: DateTime(2026, 10, 26, 8, 50),
      ),
      isTrue,
    );
    // Snooze ends at 9:10 AM -> after 9 AM nudge -> suppress Touch 2
    expect(
      shouldSuppressFollowUpNudgeForSnooze(
        nudgeTime: nudge9am,
        activeSnoozeEnd: DateTime(2026, 10, 26, 9, 10),
      ),
      isTrue,
    );
  });

  test('early-snooze lead time and privacy-safe snooze notification formatting',
      () {
    final now = DateTime(2026, 10, 26, 11, 0);
    final lead = timeUntilScheduledSlot(now: now, timeSlot: '8:00 PM');
    expect(lead, const Duration(hours: 9));
    expect(formatLeadTimeDuration(const Duration(hours: 2, minutes: 15)),
        '2 hr 15 min');
    expect(formatLeadTimeDuration(const Duration(minutes: 45)), '45 min');
    expect(formatLeadTimeDuration(const Duration(hours: 1)), '1 hr');

    final title = formatSnoozeNotificationTitle('8:00 AM');
    final body = formatSnoozeNotificationBody(
      remainingCount: 2,
      timeSlot: '8:00 AM',
      profileName: 'Leo',
    );
    expect(title, 'Morning Routine • Snooze Ended');
    expect(body, 'Time to log 2 pending doses for Leo (8:00 AM).');
  });

  test(
      'startSnoozeForTimeSlot routes through BedtimeService (clamping, quiet hours, and pauseTonight auto-resume)',
      () async {
    // Monday Oct 26, 2026 9:45 PM; Bedtime 10:00 PM -> 7:00 AM
    var currentTime = DateTime(2026, 10, 26, 21, 45);
    final bedtimeService = BedtimeService(
      clock: () => currentTime,
      initialSchedule: BedtimeSchedule.everyDay(
        isEnabled: true,
        bedtime: '10:00 PM',
        wakeTime: '7:00 AM',
      ),
    );
    await bedtimeService.load();

    final liveService = LiveReminderService(
      channel: channel,
      bedtimeService: bedtimeService,
      clock: () => currentTime,
    );

    const prescriptions = [
      Prescription(
        id: '1',
        profileId: 'p1',
        name: 'Night Med',
        dosage: '10mg',
        reminderTimes: ['9:30 PM'],
        remaining: 10,
        daysSupply: 10,
      ),
    ];
    const profiles = [
      Profile(id: 'p1', name: 'Leo', color: Colors.blue, isPrimary: true),
    ];

    // 9:45 PM + 30m -> clamped to 15m (ends at 10:00 PM)
    await liveService.startSnoozeForTimeSlot(
      timeSlot: '9:30 PM',
      prescriptions: prescriptions,
      profiles: profiles,
      snoozeDurationMinutes: 30,
    );
    expect(liveService.lastStartOutcome?.status, SnoozeStartStatus.started);
    expect(liveService.lastStartOutcome?.effectiveDurationMinutes, 15);
    expect(liveService.lastStartOutcome?.clampedToBedtime, isTrue);

    // 10:15 PM -> blocked by quiet hours
    currentTime = DateTime(2026, 10, 26, 22, 15);
    await liveService.startSnoozeForTimeSlot(
      timeSlot: '9:30 PM',
      prescriptions: prescriptions,
      profiles: profiles,
      snoozeDurationMinutes: 15,
    );
    expect(
      liveService.lastStartOutcome?.status,
      SnoozeStartStatus.blockedByBedtime,
    );

    // Pause tonight -> allows snooze tonight, auto-resumes Tuesday 10:00 PM
    final resumeAt = await bedtimeService.pauseTonight();
    expect(resumeAt, DateTime(2026, 10, 27, 22, 0));

    await liveService.startSnoozeForTimeSlot(
      timeSlot: '9:30 PM',
      prescriptions: prescriptions,
      profiles: profiles,
      snoozeDurationMinutes: 15,
    );
    expect(liveService.lastStartOutcome?.status, SnoozeStartStatus.started);
    expect(liveService.lastStartOutcome?.effectiveDurationMinutes, 15);

    // Tuesday 10:00 PM -> auto-resumed -> blocked again!
    currentTime = DateTime(2026, 10, 27, 22, 0);
    await liveService.startSnoozeForTimeSlot(
      timeSlot: '9:30 PM',
      prescriptions: prescriptions,
      profiles: profiles,
      snoozeDurationMinutes: 15,
    );
    expect(
      liveService.lastStartOutcome?.status,
      SnoozeStartStatus.blockedByBedtime,
    );
  });
}
