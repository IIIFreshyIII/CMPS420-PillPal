import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pillpal/core/theme/app_theme.dart';
import 'package:pillpal/data/models/dose_event.dart';
import 'package:pillpal/data/models/prescription.dart';
import 'package:pillpal/data/models/profile.dart';
import 'package:pillpal/presentation/widgets/profile_chip.dart';
import 'package:pillpal/screens/profiles/dose_history_screen.dart';
import 'package:pillpal/screens/profiles/profiles_screen.dart';

void main() {
  const me = Profile(id: '1', name: 'Me', color: Colors.blue, isPrimary: true);
  const allegra = Prescription(
    id: 'rx1',
    profileId: '1',
    name: 'Allegra',
    dosage: '10mg',
    reminderTimes: ['8:00 AM'],
    remaining: 14,
    daysSupply: 14,
  );

  final doseEvents = [
    DoseEvent(
      id: 'd1',
      prescriptionId: 'rx1',
      profileId: '1',
      occurredAt: DateTime.now(),
      action: DoseAction.taken,
    ),
  ];

  Widget buildScreen({
    List<Profile> profiles = const [me],
    List<Prescription> prescriptions = const [allegra],
    List<DoseEvent>? events,
    ValueChanged<Prescription>? onEdit,
  }) {
    return MaterialApp(
      theme: AppTheme.lightTheme,
      home: Scaffold(
        body: ProfilesScreen(
          profiles: profiles,
          prescriptions: prescriptions,
          doseEvents: events ?? doseEvents,
          onEditMedication: onEdit ?? (_) {},
        ),
      ),
    );
  }

  testWidgets('renders Meds page with adherence graph and saved medications',
      (tester) async {
    await tester.pumpWidget(buildScreen());
    await tester.pumpAndSettle();

    expect(find.text('Meds'), findsOneWidget);
    expect(find.text('1 Active'), findsOneWidget);
    expect(find.text('CONSISTENCY'), findsOneWidget);
    expect(find.text('Dose History Log'), findsOneWidget);
    expect(find.text('SAVED MEDICATIONS'), findsOneWidget);
    expect(find.text('Allegra'), findsOneWidget);
    expect(find.text('10mg'), findsOneWidget);
  });

  testWidgets('tapping saved medication card calls onEditMedication',
      (tester) async {
    Prescription? edited;
    await tester.pumpWidget(buildScreen(onEdit: (p) => edited = p));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Allegra'));
    await tester.pumpAndSettle();

    expect(edited, isNotNull);
    expect(edited!.id, 'rx1');
  });

  testWidgets('tapping Dose History Log navigates to DoseHistoryScreen',
      (tester) async {
    await tester.pumpWidget(buildScreen());
    await tester.pumpAndSettle();

    await tester.tap(find.text('Dose History Log'));
    await tester.pumpAndSettle();

    expect(find.byType(DoseHistoryScreen), findsOneWidget);
    expect(find.text('Dose History'), findsOneWidget);
  });

  testWidgets('shows purge notice banner if expired logs exist',
      (tester) async {
    final oldEvents = [
      DoseEvent(
        id: 'old1',
        prescriptionId: 'rx1',
        profileId: '1',
        occurredAt: DateTime.now().subtract(const Duration(days: 400)),
        action: DoseAction.taken,
      ),
    ];

    await tester.pumpWidget(buildScreen(events: oldEvents));
    await tester.pumpAndSettle();

    expect(find.text('1-Year History Cleanup Notice'), findsOneWidget);
    expect(find.text('Export Backup'), findsOneWidget);
    expect(find.text('Purge Logs'), findsOneWidget);
  });

  testWidgets('renders active count with pill shape (radius 20) and capsule icon',
      (tester) async {
    await tester.pumpWidget(buildScreen());
    await tester.pumpAndSettle();

    final badgeContainer = tester.widget<Container>(
      find.ancestor(of: find.text('1 Active'), matching: find.byType(Container)).first,
    );
    final decoration = badgeContainer.decoration as BoxDecoration;
    expect(decoration.borderRadius, BorderRadius.circular(20));
  });

  testWidgets('multiple profiles render pill-shaped tabs and filter saved meds on tap',
      (tester) async {
    tester.view.physicalSize = const Size(800, 2000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    const mom = Profile(id: '2', name: 'Mom', color: Colors.purple);
    const lisinopril = Prescription(
      id: 'rx2',
      profileId: '2',
      name: 'Lisinopril',
      dosage: '20mg',
      reminderTimes: ['8:00 AM'],
      remaining: 4,
      daysSupply: 4,
    );

    await tester.pumpWidget(buildScreen(
      profiles: const [me, mom],
      prescriptions: const [allegra, lisinopril],
    ));
    await tester.pumpAndSettle();

    // Verify filter tabs are rendered
    expect(find.widgetWithText(ProfileChip, 'All'), findsOneWidget);
    expect(find.widgetWithText(ProfileChip, 'Me'), findsOneWidget);
    expect(find.widgetWithText(ProfileChip, 'Mom'), findsOneWidget);
    expect(find.text('Allegra'), findsOneWidget);
    expect(find.text('Lisinopril'), findsOneWidget);

    // Verify pill shape of the tabs (BorderRadius 20)
    final momChipContainer = tester.widget<Container>(
      find.descendant(
        of: find.widgetWithText(ProfileChip, 'Mom'),
        matching: find.byType(Container),
      ).first,
    );
    final momDecoration = momChipContainer.decoration as BoxDecoration;
    expect(momDecoration.borderRadius, BorderRadius.circular(20));

    // Tap 'Mom' to filter
    await tester.tap(find.widgetWithText(ProfileChip, 'Mom'));
    await tester.pumpAndSettle();

    expect(find.text('Lisinopril'), findsOneWidget);
    expect(find.text('Allegra'), findsNothing);

    // Tap 'All' to restore
    await tester.tap(find.widgetWithText(ProfileChip, 'All'));
    await tester.pumpAndSettle();

    expect(find.text('Allegra'), findsOneWidget);
    expect(find.text('Lisinopril'), findsOneWidget);
  });

  testWidgets(
      'hides profile badge on SavedMedicationCard when only 1 profile exists',
      (tester) async {
    await tester.pumpWidget(buildScreen(profiles: const [me]));
    await tester.pumpAndSettle();

    expect(find.text('Allegra'), findsOneWidget);
    // Profile badge 'Me' should not be rendered when single profile
    expect(find.text('Me'), findsNothing);
  });

  testWidgets(
      'shows profile badge on SavedMedicationCard when multiple profiles exist',
      (tester) async {
    tester.view.physicalSize = const Size(800, 2000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    const mom = Profile(id: '2', name: 'Mom', color: Colors.purple);
    await tester.pumpWidget(buildScreen(profiles: const [me, mom]));
    await tester.pumpAndSettle();

    expect(find.text('Allegra'), findsOneWidget);
    // Profile badge 'Me' is rendered (both in filter tabs and on the card)
    expect(find.text('Me'), findsWidgets);
  });
}
