import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pillpal/core/theme/app_theme.dart';
import 'package:pillpal/data/models/dose_event.dart';
import 'package:pillpal/data/models/prescription.dart';
import 'package:pillpal/data/models/profile.dart';
import 'package:pillpal/screens/profiles/dose_history_screen.dart';

void main() {
  const me = Profile(id: '1', name: 'Me', color: Colors.blue, isPrimary: true);
  const mom = Profile(id: '2', name: 'Mom', color: Colors.purple);
  const allegra = Prescription(
    id: 'rx1',
    profileId: '1',
    name: 'Allegra',
    dosage: '10mg',
    reminderTimes: ['8:00 AM'],
    remaining: 14,
    daysSupply: 14,
  );
  const lisinopril = Prescription(
    id: 'rx2',
    profileId: '2',
    name: 'Lisinopril',
    dosage: '20mg',
    reminderTimes: ['8:00 AM'],
    remaining: 4,
    daysSupply: 4,
  );

  final events = [
    DoseEvent(
      id: 'd1',
      prescriptionId: 'rx1',
      profileId: '1',
      occurredAt: DateTime.now(),
      action: DoseAction.taken,
    ),
    DoseEvent(
      id: 'd2',
      prescriptionId: 'rx2',
      profileId: '2',
      occurredAt: DateTime.now(),
      action: DoseAction.skipped,
    ),
  ];

  Widget buildScreen({
    ValueChanged<Prescription>? onEdit,
  }) {
    return MaterialApp(
      theme: AppTheme.lightTheme,
      home: DoseHistoryScreen(
        profiles: const [me, mom],
        prescriptions: const [allegra, lisinopril],
        doseEvents: events,
        onEditMedication: onEdit ?? (_) {},
      ),
    );
  }

  testWidgets('displays history rows with Took and Skipped status',
      (tester) async {
    await tester.pumpWidget(buildScreen());
    await tester.pumpAndSettle();

    expect(find.text('Dose History'), findsOneWidget);
    expect(find.text('Took Allegra'), findsOneWidget);
    expect(find.text('Skipped Lisinopril'), findsOneWidget);
    expect(find.text('All Profiles'), findsOneWidget);
    expect(find.text('Me'), findsWidgets);
    expect(find.text('Mom'), findsWidgets);
  });

  testWidgets('filters history by profile chip', (tester) async {
    await tester.pumpWidget(buildScreen());
    await tester.pumpAndSettle();

    // Tap 'Me' chip
    await tester.tap(find.text('Me').first);
    await tester.pumpAndSettle();

    expect(find.text('Took Allegra'), findsOneWidget);
    expect(find.text('Skipped Lisinopril'), findsNothing);
  });

  testWidgets('tapping history row calls onEditMedication', (tester) async {
    Prescription? edited;
    await tester.pumpWidget(buildScreen(onEdit: (p) => edited = p));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Took Allegra'));
    await tester.pumpAndSettle();

    expect(edited, isNotNull);
    expect(edited!.name, 'Allegra');
  });
}
