import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:pillpal/data/models/prescription.dart';
import 'package:pillpal/data/models/profile.dart';
import 'package:pillpal/screens/medication_detail/medication_detail_sheet.dart';

void main() {
  const prescription = Prescription(
    id: '1',
    profileId: '1',
    name: 'Allegra',
    dosage: '10mg',
    reminderTimes: ['8:00 AM'],
    remaining: 14,
    daysSupply: 14,
  );
  const profiles = [Profile(id: '1', name: 'Me', color: Colors.blue, isPrimary: true)];

  Future<void> openSheet(WidgetTester tester, {VoidCallback? onDelete}) async {
    await tester.pumpWidget(MaterialApp(
      home: Builder(
        builder: (context) => ElevatedButton(
          onPressed: () => MedicationDetailSheet.show(
            context,
            prescription: prescription,
            profiles: profiles,
            onUpdate: (_) {},
            onDelete: onDelete ?? () {},
          ),
          child: const Text('open'),
        ),
      ),
    ));
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
  }

  testWidgets('closing with no edits pops immediately, no discard prompt', (tester) async {
    await openSheet(tester);

    await tester.tap(find.byIcon(CupertinoIcons.xmark).hitTestable());
    await tester.pumpAndSettle();

    expect(find.text('Discard changes?'), findsNothing);
    expect(find.text('Allegra'), findsNothing); // sheet is gone
  });

  testWidgets('closing after an edit shows the discard-changes prompt', (tester) async {
    await openSheet(tester);

    await tester.enterText(find.widgetWithText(TextField, 'Allegra'), 'Allegra XR');
    await tester.tap(find.byIcon(CupertinoIcons.xmark).hitTestable());
    await tester.pumpAndSettle();

    expect(find.text('Discard changes?'), findsOneWidget);
  });

  testWidgets('Keep Editing dismisses the prompt and preserves the edit', (tester) async {
    await openSheet(tester);

    await tester.enterText(find.widgetWithText(TextField, 'Allegra'), 'Allegra XR');
    await tester.tap(find.byIcon(CupertinoIcons.xmark).hitTestable());
    await tester.pumpAndSettle();

    await tester.tap(find.text('Keep Editing'));
    await tester.pumpAndSettle();

    expect(find.text('Discard changes?'), findsNothing);
    expect(find.text('Allegra XR'), findsOneWidget); // sheet still open, edit intact
  });

  testWidgets('Discard Changes closes the sheet', (tester) async {
    await openSheet(tester);

    await tester.enterText(find.widgetWithText(TextField, 'Allegra'), 'Allegra XR');
    await tester.tap(find.byIcon(CupertinoIcons.xmark).hitTestable());
    await tester.pumpAndSettle();

    await tester.tap(find.text('Discard Changes'));
    await tester.pumpAndSettle();

    expect(find.text('Discard changes?'), findsNothing);
    expect(find.text('Allegra XR'), findsNothing); // sheet is gone
  });
}
