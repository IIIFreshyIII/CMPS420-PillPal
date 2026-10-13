import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pillpal/core/theme/app_theme.dart';
import 'package:pillpal/data/models/prescription.dart';
import 'package:pillpal/data/models/profile.dart';
import 'package:pillpal/screens/schedule/schedule_screen.dart';

void main() {
  const profile = Profile(id: '1', name: 'Marcus', color: Colors.blue, isPrimary: true);

  testWidgets('renders time interval headers and separates Mark All per interval', (tester) async {
    tester.view.physicalSize = const Size(1200, 3000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    const prescriptions = [
      Prescription(
        id: '1',
        name: 'Allegra',
        dosage: '10mg',
        reminderTimes: ['8:00 AM'],
        daysSupply: 14,
        remaining: 14,
        profileId: '1',
        takenTimes: {},
      ),
      Prescription(
        id: '2',
        name: 'Lisinopril',
        dosage: '20mg',
        reminderTimes: ['8:00 AM'],
        daysSupply: 4,
        remaining: 4,
        profileId: '1',
        takenTimes: {},
      ),
      Prescription(
        id: '3',
        name: 'Metformin',
        dosage: '500mg',
        reminderTimes: ['12:00 PM'],
        daysSupply: 28,
        remaining: 28,
        profileId: '1',
        takenTimes: {},
      ),
      Prescription(
        id: '4',
        name: 'Lipitor',
        dosage: '20mg',
        reminderTimes: ['6:00 PM'],
        daysSupply: 30,
        remaining: 30,
        profileId: '1',
        takenTimes: {},
      ),
      Prescription(
        id: '5',
        name: 'Melatonin',
        dosage: '5mg',
        reminderTimes: ['10:00 PM'],
        daysSupply: 30,
        remaining: 30,
        profileId: '1',
        takenTimes: {},
      ),
    ];

    List<(String, String)>? toggledTargets;
    bool? toggledState;

    await tester.pumpWidget(MaterialApp(
      theme: AppTheme.lightTheme,
      home: Scaffold(
        body: ScheduleScreen(
          prescriptions: prescriptions,
          profiles: const [profile],
          selectedProfileId: 'all',
          onSelectProfile: (_) {},
          onTakeDose: (_, __) {},
          onViewMedication: (_) {},
          onToggleAllCompleted: (targets, markTaken) {
            toggledTargets = targets;
            toggledState = markTaken;
          },
          onOpenScan: () {},
          isScanning: false,
        ),
      ),
    ));
    await tester.pumpAndSettle();

    // Verify all 4 time interval headers are rendered
    expect(find.text('MORNING'), findsOneWidget);
    expect(find.text('AFTERNOON'), findsOneWidget);
    expect(find.text('EVENING'), findsOneWidget);
    expect(find.text('NIGHT'), findsOneWidget);

    // Each interval header has its own Mark All button
    expect(find.byKey(const ValueKey('mark_all_morning')), findsOneWidget);
    expect(find.byKey(const ValueKey('mark_all_afternoon')), findsOneWidget);
    expect(find.byKey(const ValueKey('mark_all_evening')), findsOneWidget);
    expect(find.byKey(const ValueKey('mark_all_night')), findsOneWidget);

    // Section counter chips show interval-specific progress
    expect(find.text('0 of 2'), findsOneWidget); // Morning (2 doses)
    expect(find.text('0 of 1'), findsNWidgets(3)); // Afternoon, Evening, Night (1 dose each)
    // Global counter at the top is no longer present
    expect(find.text('0 of 5'), findsNothing);

    // Tap Mark All on Morning header
    await tester.tap(find.byKey(const ValueKey('mark_all_morning')));
    await tester.pumpAndSettle();

    // Assert only morning doses were targeted
    expect(toggledTargets, isNotNull);
    expect(toggledTargets, hasLength(2));
    expect(toggledTargets, contains(('1', '8:00 AM')));
    expect(toggledTargets, contains(('2', '8:00 AM')));
    expect(toggledState, isTrue);

    // Tap Mark All on Afternoon header
    await tester.tap(find.byKey(const ValueKey('mark_all_afternoon')));
    await tester.pumpAndSettle();

    expect(toggledTargets, [('3', '12:00 PM')]);
    expect(toggledState, isTrue);
  });

  testWidgets('shows Reset when interval is completed, and resets on tap', (tester) async {
    tester.view.physicalSize = const Size(1200, 3000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    const prescriptions = [
      Prescription(
        id: '1',
        name: 'Allegra',
        dosage: '10mg',
        reminderTimes: ['8:00 AM'],
        daysSupply: 14,
        remaining: 14,
        profileId: '1',
        takenTimes: {'8:00 AM'},
      ),
      Prescription(
        id: '2',
        name: 'Metformin',
        dosage: '500mg',
        reminderTimes: ['12:00 PM'],
        daysSupply: 28,
        remaining: 28,
        profileId: '1',
        takenTimes: {},
      ),
    ];

    List<(String, String)>? toggledTargets;
    bool? toggledState;

    await tester.pumpWidget(MaterialApp(
      theme: AppTheme.lightTheme,
      home: Scaffold(
        body: ScheduleScreen(
          prescriptions: prescriptions,
          profiles: const [profile],
          selectedProfileId: 'all',
          onSelectProfile: (_) {},
          onTakeDose: (_, __) {},
          onViewMedication: (_) {},
          onToggleAllCompleted: (targets, markTaken) {
            toggledTargets = targets;
            toggledState = markTaken;
          },
          onOpenScan: () {},
          isScanning: false,
        ),
      ),
    ));
    await tester.pumpAndSettle();

    // Morning is completed -> shows Reset and 1 of 1
    expect(find.text('1 of 1'), findsOneWidget);
    expect(find.descendant(
      of: find.byKey(const ValueKey('mark_all_morning')),
      matching: find.text('Reset'),
    ), findsOneWidget);

    // Afternoon is not completed -> shows Mark All and 0 of 1
    expect(find.text('0 of 1'), findsOneWidget);
    expect(find.descendant(
      of: find.byKey(const ValueKey('mark_all_afternoon')),
      matching: find.text('Mark All'),
    ), findsOneWidget);

    // Tap Reset on Morning
    await tester.tap(find.byKey(const ValueKey('mark_all_morning')));
    await tester.pumpAndSettle();

    expect(toggledTargets, [('1', '8:00 AM')]);
    expect(toggledState, isFalse);
  });

  testWidgets('selected profile chip matches profile color while All tab matches ink color', (tester) async {
    const p1 = Profile(id: '1', name: 'Marcus', color: Colors.purple, isPrimary: true);
    const p2 = Profile(id: '2', name: 'Mom', color: Colors.orange);

    await tester.pumpWidget(MaterialApp(
      theme: AppTheme.lightTheme,
      home: Scaffold(
        body: ScheduleScreen(
          prescriptions: const [],
          profiles: const [p1, p2],
          selectedProfileId: '2', // Mom selected
          onSelectProfile: (_) {},
          onTakeDose: (_, __) {},
          onViewMedication: (_) {},
          onToggleAllCompleted: (_, __) {},
          onOpenScan: () {},
          isScanning: false,
        ),
      ),
    ));
    await tester.pumpAndSettle();

    final momChipContainer = tester.widget<Container>(
      find.ancestor(of: find.text('Mom'), matching: find.byType(Container)).first,
    );
    final decoration = momChipContainer.decoration as BoxDecoration;
    expect(decoration.color, Colors.orange);
  });

  testWidgets('filtering profiles smoothly collapses non-matching cards without rebuilding the whole list', (tester) async {
    tester.view.physicalSize = const Size(1200, 3000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    const p1 = Profile(id: '1', name: 'Marcus', color: Colors.blue, isPrimary: true);
    const p2 = Profile(id: '2', name: 'Mom', color: Colors.amber);

    final prescriptions = [
      const Prescription(
        id: '1',
        name: 'Allegra',
        dosage: '10mg',
        reminderTimes: ['8:00 AM'],
        daysSupply: 14,
        remaining: 14,
        profileId: '1',
        takenTimes: {},
      ),
      const Prescription(
        id: '2',
        name: 'Metformin',
        dosage: '500mg',
        reminderTimes: ['12:00 PM'],
        daysSupply: 28,
        remaining: 28,
        profileId: '2',
        takenTimes: {},
      ),
    ];

    String selectedProfile = 'all';

    await tester.pumpWidget(MaterialApp(
      theme: AppTheme.lightTheme,
      home: StatefulBuilder(
        builder: (context, setState) {
          return Scaffold(
            body: ScheduleScreen(
              prescriptions: prescriptions,
              profiles: const [p1, p2],
              selectedProfileId: selectedProfile,
              onSelectProfile: (id) => setState(() => selectedProfile = id),
              onTakeDose: (_, __) {},
              onViewMedication: (_) {},
              onToggleAllCompleted: (_, __) {},
              onOpenScan: () {},
              isScanning: false,
            ),
          );
        },
      ),
    ));
    await tester.pumpAndSettle();

    AnimatedCrossFade crossFadeOf(Key key) => tester.widget<AnimatedCrossFade>(
          find.descendant(of: find.byKey(key), matching: find.byType(AnimatedCrossFade)),
        );

    // In 'All', both cards are visible in showFirst state
    expect(crossFadeOf(const ValueKey('anim_slot_1_8:00 AM')).crossFadeState, CrossFadeState.showFirst);
    expect(crossFadeOf(const ValueKey('anim_slot_2_12:00 PM')).crossFadeState, CrossFadeState.showFirst);

    // Tap 'Mom' profile chip
    await tester.tap(find.text('Mom').first);
    await tester.pump();

    // Allegra collapses to showSecond, while Metformin remains showFirst
    expect(crossFadeOf(const ValueKey('anim_slot_1_8:00 AM')).crossFadeState, CrossFadeState.showSecond);
    expect(crossFadeOf(const ValueKey('anim_slot_2_12:00 PM')).crossFadeState, CrossFadeState.showFirst);

    // Morning section collapses to showSecond since Mom has no morning meds
    expect(crossFadeOf(const ValueKey('anim_sec_MORNING')).crossFadeState, CrossFadeState.showSecond);

    // Afternoon section remains showFirst
    expect(crossFadeOf(const ValueKey('anim_sec_AFTERNOON')).crossFadeState, CrossFadeState.showFirst);

    await tester.pumpAndSettle();
  });

  testWidgets('on iOS, cards and sections animate with genuine rise-and-fade and fall-into-place transition', (tester) async {
    tester.view.physicalSize = const Size(1200, 3000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
    try {

    const p1 = Profile(id: '1', name: 'Marcus', color: Colors.blue, isPrimary: true);
    const p2 = Profile(id: '2', name: 'Mom', color: Colors.amber);

    final prescriptions = [
      const Prescription(
        id: '1',
        name: 'Allegra',
        dosage: '10mg',
        reminderTimes: ['8:00 AM'],
        daysSupply: 14,
        remaining: 14,
        profileId: '1',
        takenTimes: {},
      ),
      const Prescription(
        id: '2',
        name: 'Metformin',
        dosage: '500mg',
        reminderTimes: ['12:00 PM'],
        daysSupply: 28,
        remaining: 28,
        profileId: '2',
        takenTimes: {},
      ),
    ];

    String selectedProfile = 'all';

    await tester.pumpWidget(MaterialApp(
      theme: AppTheme.lightTheme,
      home: StatefulBuilder(
        builder: (context, setState) {
          return Scaffold(
            body: ScheduleScreen(
              prescriptions: prescriptions,
              profiles: const [p1, p2],
              selectedProfileId: selectedProfile,
              onSelectProfile: (id) => setState(() => selectedProfile = id),
              onTakeDose: (_, __) {},
              onViewMedication: (_) {},
              onToggleAllCompleted: (_, __) {},
              onOpenScan: () {},
              isScanning: false,
            ),
          );
        },
      ),
    ));
    await tester.pumpAndSettle();

    // Verify both cards are rendered initially
    expect(find.byKey(const ValueKey('med_1_8:00 AM')), findsOneWidget);
    expect(find.byKey(const ValueKey('med_2_12:00 PM')), findsOneWidget);

    // Metformin stays visible across the filter change, so its element must
    // survive untouched (UITableView-style: only inserted/deleted rows animate).
    final metforminElement =
        tester.element(find.byKey(const ValueKey('med_2_12:00 PM')));

    double opacityWithin(Key key) => tester
        .widget<Opacity>(find
            .descendant(of: find.byKey(key), matching: find.byType(Opacity))
            .first)
        .opacity;

    // Tap Mom chip
    await tester.tap(find.text('Mom').first);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 150));

    // Mid-animation: the Morning section (Allegra) is still on screen, fading
    // out as it tucks away; the Afternoon section is fully opaque and untouched.
    expect(find.text('Allegra'), findsOneWidget);
    final morningOpacity = opacityWithin(const ValueKey('ios_sec_MORNING'));
    expect(morningOpacity, greaterThan(0.0));
    expect(morningOpacity, lessThan(1.0));
    expect(opacityWithin(const ValueKey('ios_sec_AFTERNOON')), 1.0);

    // Pump to completion
    await tester.pumpAndSettle();

    // Once settled, only Mom's medication is rendered (collapsed rows unmount)
    expect(find.text('Metformin'), findsOneWidget);
    expect(find.text('Allegra'), findsNothing);
    expect(
      tester.element(find.byKey(const ValueKey('med_2_12:00 PM'))),
      same(metforminElement),
    );

    // Switch back to All
    await tester.tap(find.text('All'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 150));

    // Mid-animation: Allegra's section is opening back up and fading in
    expect(find.text('Allegra'), findsOneWidget);
    final reopening = opacityWithin(const ValueKey('ios_sec_MORNING'));
    expect(reopening, greaterThan(0.0));
    expect(reopening, lessThan(1.0));

    await tester.pumpAndSettle();
    // Fully settled in All: both medications visible
    expect(find.text('Allegra'), findsOneWidget);
    expect(find.text('Metformin'), findsOneWidget);
    expect(opacityWithin(const ValueKey('ios_sec_MORNING')), 1.0);
    } finally {
      debugDefaultTargetPlatformOverride = null;
    }
  });
}
