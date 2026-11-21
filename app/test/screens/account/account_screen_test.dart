import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:pillpal/core/utils/ios_design_era.dart';
import 'package:pillpal/data/models/prescription.dart';
import 'package:pillpal/data/models/profile.dart';
import 'package:pillpal/core/theme/liquid_glass_controller.dart';
import 'package:pillpal/data/services/notification_service.dart';
import 'package:pillpal/screens/account/account_screen.dart';
import 'package:pillpal/screens/account/bedtime_screen.dart';
import 'package:pillpal/services/bedtime_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  tearDown(() {
    debugIsLiquidGlassSupportedOverride = null;
  });

  const me = Profile(id: '1', name: 'Me', color: Colors.blue, isPrimary: true);
  const mom = Profile(id: '2', name: 'Mom', color: Colors.purple);
  const momsRx = Prescription(
    id: 'rx1',
    profileId: '2',
    name: 'Metformin',
    dosage: '500mg',
    reminderTimes: ['12:00 PM'],
    remaining: 28,
    daysSupply: 28,
  );

  Widget buildApp({
    required List<Profile> profiles,
    required List<Prescription> prescriptions,
    required ValueChanged<Profile> onUpdateProfile,
    required ValueChanged<String> onDeleteProfile,
  }) {
    return MaterialApp(
      home: AccountScreen(
        profiles: profiles,
        prescriptions: prescriptions,
        onUpdateProfile: onUpdateProfile,
        onDeleteProfile: onDeleteProfile,
        notificationService: NotificationService(),
      ),
    );
  }

  testWidgets('Add Family Member creates a non-primary profile with the entered name', (tester) async {
    Profile? added;
    await tester.pumpWidget(buildApp(
      profiles: const [me],
      prescriptions: const [],
      onUpdateProfile: (p) => added = p,
      onDeleteProfile: (_) {},
    ));

    await tester.tap(find.text('Add Family Member'));
    await tester.pumpAndSettle();

    expect(find.text('Add'), findsOneWidget);
    await tester.enterText(find.byKey(const Key('field_new_profile_name')), 'Dad');
    await tester.pump();
    await tester.tap(find.byKey(const Key('add_profile_save_button')));
    await tester.pumpAndSettle();

    expect(added, isNotNull);
    expect(added!.name, 'Dad');
    expect(added!.isPrimary, isFalse);
  });

  testWidgets('Add is disabled until a name is entered', (tester) async {
    await tester.pumpWidget(buildApp(
      profiles: const [me],
      prescriptions: const [],
      onUpdateProfile: (_) {},
      onDeleteProfile: (_) {},
    ));

    await tester.tap(find.text('Add Family Member'));
    await tester.pumpAndSettle();

    final addButton = tester.widget<TextButton>(find.byKey(const Key('add_profile_save_button')));
    expect(addButton.onPressed, isNull);
  });

  testWidgets('a non-primary profile with no prescriptions can be deleted', (tester) async {
    String? deletedId;
    await tester.pumpWidget(buildApp(
      profiles: const [me, mom],
      prescriptions: const [],
      onUpdateProfile: (_) {},
      onDeleteProfile: (id) => deletedId = id,
    ));

    await tester.tap(find.text('Mom'));
    await tester.pumpAndSettle();

    expect(find.text('Delete Profile'), findsOneWidget);
    await tester.tap(find.text('Delete Profile'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Delete Profile').last); // confirm in the action sheet
    await tester.pumpAndSettle();

    expect(deletedId, '2');
  });

  testWidgets('a profile with prescriptions shows a blocking message instead of delete', (tester) async {
    await tester.pumpWidget(buildApp(
      profiles: const [me, mom],
      prescriptions: const [momsRx],
      onUpdateProfile: (_) {},
      onDeleteProfile: (_) {},
    ));

    await tester.tap(find.text('Mom'));
    await tester.pumpAndSettle();

    expect(find.text('Delete Profile'), findsNothing);
    expect(find.text('Reassign or delete their medications first to delete this profile.'), findsOneWidget);
  });

  testWidgets('the primary profile has no delete option at all', (tester) async {
    await tester.pumpWidget(buildApp(
      profiles: const [me, mom],
      prescriptions: const [],
      onUpdateProfile: (_) {},
      onDeleteProfile: (_) {},
    ));

    await tester.tap(find.text('Me'));
    await tester.pumpAndSettle();

    expect(find.text('Delete Profile'), findsNothing);
    expect(find.text('Reassign or delete their medications first to delete this profile.'), findsNothing);
  });

  testWidgets('renders LiquidGlassSetting under Preferences when liquidGlassController is provided', (tester) async {

    final controller = LiquidGlassController();
    await tester.pumpWidget(MaterialApp(
      home: MediaQuery(
        data: const MediaQueryData(
          size: Size(393, 852),
          padding: EdgeInsets.only(top: 59, bottom: 34),
        ),
        child: AccountScreen(
          profiles: const [me],
          prescriptions: const [],
          onUpdateProfile: (_) {},
          onDeleteProfile: (_) {},
          notificationService: NotificationService(),
          liquidGlassController: controller,
        ),
      ),
    ));

    await tester.scrollUntilVisible(
      find.text('Liquid Glass Effect'),
      200,
    );
    expect(find.text('Liquid Glass Effect'), findsOneWidget);
    expect(find.text('Auto'), findsWidgets);
  });

  testWidgets('hides LiquidGlassSetting when Liquid Glass is not supported (Android or pre-iOS 26)', (tester) async {
    debugIsLiquidGlassSupportedOverride = false;
    final controller = LiquidGlassController();
    await tester.pumpWidget(MaterialApp(
      home: MediaQuery(
        data: const MediaQueryData(
          size: Size(393, 852),
          padding: EdgeInsets.only(top: 59, bottom: 34),
        ),
        child: AccountScreen(
          profiles: const [me],
          prescriptions: const [],
          onUpdateProfile: (_) {},
          onDeleteProfile: (_) {},
          notificationService: NotificationService(),
          liquidGlassController: controller,
        ),
      ),
    ));

    expect(find.text('Liquid Glass Effect'), findsNothing);
  });

  testWidgets(
      'Settings screen renders header, profile summaries, 3 grouped sections, and pushes BedtimeScreen',
      (tester) async {
    SharedPreferences.setMockInitialValues({});
    final bedtimeService = BedtimeService(
      clock: () => DateTime(2026, 10, 26, 21, 0), // Monday 9:00 PM
      initialSchedule: BedtimeSchedule.everyDay(
        isEnabled: true,
        bedtime: '10:00 PM',
        wakeTime: '7:00 AM',
      ),
    );
    await bedtimeService.load();

    await tester.pumpWidget(MaterialApp(
      home: AccountScreen(
        profiles: const [me, mom],
        prescriptions: const [momsRx],
        onUpdateProfile: (_) {},
        onDeleteProfile: (_) {},
        notificationService: NotificationService(),
        bedtimeService: bedtimeService,
      ),
    ));
    await tester.pumpAndSettle();

    // Header & profile medication counts
    expect(find.text('Settings'), findsOneWidget);
    expect(find.text('Primary · 0 medications'), findsOneWidget);
    expect(find.text('1 medication'), findsOneWidget);
    expect(find.text('Zero-Knowledge Architecture'), findsNothing);

    // Regrouped sections
    expect(find.text('REMINDERS & SLEEP'), findsOneWidget);
    expect(find.text('Bedtime'), findsOneWidget);
    expect(find.text('10:00 PM – 7:00 AM · Every day'), findsOneWidget);

    await tester.scrollUntilVisible(
      find.text('All data is stored locally on this device.'),
      200,
    );
    expect(find.text('PRIVACY & DATA'), findsOneWidget);
    expect(
      find.text('All data is stored locally on this device.'),
      findsOneWidget,
    );

    // Scroll back up and tap Bedtime row -> pushes BedtimeScreen
    await tester.scrollUntilVisible(
      find.byKey(const Key('bedtime_settings_row')),
      -200,
    );
    await tester.tap(find.byKey(const Key('bedtime_settings_row')));
    await tester.pumpAndSettle();

    expect(find.byType(BedtimeScreen), findsOneWidget);
    expect(find.text('Bedtime Quiet Hours'), findsOneWidget);

    // Toggle Pause Tonight on -> auto-resumes Tuesday 10:00 PM
    await tester.tap(find.byKey(const Key('bedtime_pause_tonight_switch')));
    await tester.pumpAndSettle();
    expect(bedtimeService.isPausedAt(), isTrue);
    expect(find.text('Auto-resumes Tue at 10:00 PM'), findsOneWidget);

    // Switch to Custom mode -> verify S M T W T F S pills, arrows, and day toggle
    await tester.tap(find.byKey(const ValueKey('bedtime_mode_custom')));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('bedtime_day_pill_1')), findsOneWidget);
    expect(find.byKey(const ValueKey('bedtime_day_pill_7')), findsOneWidget);
    expect(find.byKey(const Key('bedtime_prev_day_button')), findsOneWidget);
    expect(find.byKey(const Key('bedtime_next_day_button')), findsOneWidget);

    // Tap Wednesday pill, disable it, verify label updates
    await tester.tap(find.byKey(const ValueKey('bedtime_day_pill_3')));
    await tester.pumpAndSettle();
    expect(find.text('Wednesday'), findsOneWidget);

    await tester.scrollUntilVisible(
      find.byKey(const Key('bedtime_custom_day_toggle')),
      150,
    );
    await tester.tap(find.byKey(const Key('bedtime_custom_day_toggle')));
    await tester.pumpAndSettle();
    expect(
      bedtimeService.schedule.windowForWeekday(DateTime.wednesday).enabled,
      isFalse,
    );
    expect(
      find.textContaining('Quiet hours are off on Wednesdays'),
      findsOneWidget,
    );

    // Navigate back to Settings and confirm paused preview is shown
    await tester.pageBack();
    await tester.pumpAndSettle();
    expect(find.text('Paused tonight · Resumes Tue 10:00 PM'), findsOneWidget);
  });

  testWidgets(
      'BedtimeScreen animates disclosure when toggling master switch and swaps all 3 schedule modes cleanly',
      (tester) async {
    SharedPreferences.setMockInitialValues({});
    final bedtimeService = BedtimeService(
      clock: () => DateTime(2026, 10, 26, 15, 0),
      initialSchedule: BedtimeSchedule.disabled(),
    );
    await bedtimeService.load();

    await tester.pumpWidget(MaterialApp(
      home: BedtimeScreen(service: bedtimeService),
    ));
    await tester.pumpAndSettle();

    // Initially master is off -> schedule section is collapsed/unmounted
    expect(find.text('SLEEP SCHEDULE'), findsNothing);
    expect(find.byKey(const Key('bedtime_pause_tonight_switch')), findsNothing);

    // Toggle master ON -> content descends and fades into place
    await tester.tap(find.byKey(const Key('bedtime_master_switch')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 120)); // mid-transition
    expect(find.text('SLEEP SCHEDULE'), findsOneWidget);
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('bedtime_pause_tonight_switch')), findsOneWidget);

    // Swap through all 3 mode tabs (Every Day -> Weekdays & Weekends -> Custom -> Every Day)
    await tester.tap(find.byKey(const ValueKey('bedtime_mode_weekdaysAndWeekends')));
    await tester.pump(const Duration(milliseconds: 140));
    await tester.pumpAndSettle();
    expect(find.text('Weekdays'), findsOneWidget);
    expect(find.text('Weekends'), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('bedtime_mode_custom')));
    await tester.pump(const Duration(milliseconds: 140));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('bedtime_next_day_button')), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('bedtime_mode_everyDay')));
    await tester.pump(const Duration(milliseconds: 140));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('bedtime_picker_every_day')), findsOneWidget);

    // Toggle master OFF -> content ascends, fades away, and unmounts
    await tester.tap(find.byKey(const Key('bedtime_master_switch')));
    await tester.pumpAndSettle();
    expect(find.text('SLEEP SCHEDULE'), findsNothing);
    expect(find.byKey(const Key('bedtime_pause_tonight_switch')), findsNothing);
  });
}

