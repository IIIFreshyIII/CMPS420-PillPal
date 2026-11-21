import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:pillpal/data/models/prescription.dart';
import 'package:pillpal/data/models/profile.dart';
import 'package:pillpal/screens/medication_detail/medication_detail_sheet.dart';
import 'package:pillpal/screens/medication_detail/medication_quick_view_sheet.dart';

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

  testWidgets('MedicationQuickViewSheet exposes Snooze and Skip Dose actions when untaken',
      (tester) async {
    var snoozed = false;
    var skipped = false;

    await tester.pumpWidget(MaterialApp(
      home: Builder(
        builder: (context) => ElevatedButton(
          onPressed: () => MedicationQuickViewSheet.show(
            context,
            prescription: prescription,
            profiles: profiles,
            timeSlot: '8:00 AM',
            onEdit: () {},
            onSnooze: () => snoozed = true,
            onSkip: () => skipped = true,
          ),
          child: const Text('open'),
        ),
      ),
    ));

    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('quick_view_snooze_button')), findsOneWidget);
    expect(find.byKey(const Key('quick_view_skip_button')), findsOneWidget);
    expect(find.text('Skip Dose'), findsOneWidget);

    await tester.tap(find.byKey(const Key('quick_view_snooze_button')));
    await tester.pumpAndSettle();
    expect(snoozed, isTrue);

    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('quick_view_skip_button')));
    await tester.pumpAndSettle();
    expect(skipped, isTrue);
  });

  testWidgets('MedicationQuickViewSheet flips Snooze to Cancel Snooze when active and hides actions when taken',
      (tester) async {
    var cancelSnoozeCalled = false;

    await tester.pumpWidget(MaterialApp(
      home: Builder(
        builder: (context) => Column(
          children: [
            ElevatedButton(
              onPressed: () => MedicationQuickViewSheet.show(
                context,
                prescription: prescription,
                profiles: profiles,
                timeSlot: '8:00 AM',
                isSnoozeActive: true,
                snoozeEndTime: DateTime(2026, 10, 26, 8, 15),
                onEdit: () {},
                onSnooze: () {},
                onCancelSnooze: () => cancelSnoozeCalled = true,
                onSkip: () {},
              ),
              child: const Text('open_snoozed'),
            ),
            ElevatedButton(
              onPressed: () => MedicationQuickViewSheet.show(
                context,
                prescription: prescription,
                profiles: profiles,
                timeSlot: '8:00 AM',
                isTaken: true,
                onEdit: () {},
                onSnooze: () {},
                onSkip: () {},
              ),
              child: const Text('open_taken'),
            ),
          ],
        ),
      ),
    ));

    // Active snooze flips button to Cancel Snooze and shows status banner
    await tester.tap(find.text('open_snoozed'));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('quick_view_snooze_button')), findsNothing);
    expect(find.byKey(const Key('quick_view_cancel_snooze_button')), findsOneWidget);
    expect(find.byKey(const Key('quick_view_snooze_banner')), findsOneWidget);
    expect(find.text('Snoozed until 8:15 AM'), findsOneWidget);

    await tester.tap(find.byKey(const Key('quick_view_cancel_snooze_button')));
    await tester.pumpAndSettle();
    expect(cancelSnoozeCalled, isTrue);

    // Taken card hides Snooze and Skip actions completely
    await tester.tap(find.text('open_taken'));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('quick_view_snooze_button')), findsNothing);
    expect(find.byKey(const Key('quick_view_cancel_snooze_button')), findsNothing);
    expect(find.byKey(const Key('quick_view_skip_button')), findsNothing);
  });

  testWidgets('MedicationQuickViewSheet swipe up >50px opens Edit and swipe down dismisses',
      (tester) async {
    var editOpened = false;

    await tester.pumpWidget(MaterialApp(
      home: Builder(
        builder: (context) => ElevatedButton(
          onPressed: () => MedicationQuickViewSheet.show(
            context,
            prescription: prescription,
            profiles: profiles,
            timeSlot: '8:00 AM',
            onEdit: () => editOpened = true,
          ),
          child: const Text('open'),
        ),
      ),
    ));

    // 1. Swipe up past 50px closes Quick View and immediately opens Edit
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    expect(find.text('Medication'), findsOneWidget);

    await tester.drag(
      find.byKey(const Key('quick_view_drag_surface')),
      const Offset(0, -80),
    );
    await tester.pumpAndSettle();
    expect(editOpened, isTrue);
    expect(find.text('Medication'), findsNothing);

    // 2. Swipe down dismisses Quick View cleanly
    editOpened = false;
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    await tester.drag(
      find.byKey(const Key('quick_view_drag_surface')),
      const Offset(0, 140),
    );
    await tester.pumpAndSettle();
    expect(editOpened, isFalse);
    expect(find.text('Medication'), findsNothing);
  });

  testWidgets('MedicationDetailSheet swipe down dismisses when clean and prompts discard when dirty',
      (tester) async {
    await openSheet(tester);

    // Swipe down with no edits -> dismisses cleanly
    await tester.drag(
      find.byKey(const Key('detail_sheet_drag_header')),
      const Offset(0, 140),
    );
    await tester.pumpAndSettle();
    expect(find.text('Prescription Details'), findsNothing);

    // Reopen, edit name, swipe down -> shows discard confirmation
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    await tester.enterText(find.widgetWithText(TextField, 'Allegra'), 'Allegra D');
    await tester.pumpAndSettle();

    await tester.drag(
      find.byKey(const Key('detail_sheet_drag_header')),
      const Offset(0, 140),
    );
    await tester.pumpAndSettle();
    expect(find.text('Discard changes?'), findsOneWidget);
  });
}
