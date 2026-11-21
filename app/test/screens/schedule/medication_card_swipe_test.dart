import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pillpal/data/models/prescription.dart';
import 'package:pillpal/screens/schedule/widgets/medication_card.dart';

void main() {
  const prescription = Prescription(
    id: 'rx_1',
    profileId: 'prof_1',
    name: 'Metformin',
    dosage: '500mg',
    reminderTimes: ['8:00 AM'],
    remaining: 30,
    daysSupply: 30,
  );

  Widget createCard({
    bool isTaken = false,
    bool isSkipped = false,
    VoidCallback? onTakeDose,
    VoidCallback? onSnooze,
    VoidCallback? onSkip,
    VoidCallback? onEdit,
    VoidCallback? onDelete,
  }) {
    return MaterialApp(
      theme: ThemeData(platform: TargetPlatform.iOS),
      home: Scaffold(
        body: MedicationCard(
          item: prescription,
          time: '8:00 AM',
          isTaken: isTaken,
          isSkipped: isSkipped,
          profile: null,
          onTakeDose: onTakeDose ?? () {},
          onViewDetails: () {},
          onSnooze: onSnooze,
          onSkip: onSkip,
          onEdit: onEdit,
          onDelete: onDelete,
        ),
      ),
    );
  }

  testWidgets('Renders card details and handles isSkipped badge', (tester) async {
    await tester.pumpWidget(createCard(isSkipped: true));
    await tester.pumpAndSettle();

    expect(find.text('Metformin'), findsOneWidget);
    expect(find.text('500mg'), findsOneWidget);
    expect(find.text('Skipped'), findsOneWidget);
  });

  testWidgets('Swipe right reveals Snooze and Skip circular action buttons', (tester) async {
    bool snoozeTapped = false;
    bool skipTapped = false;

    await tester.pumpWidget(createCard(
      onSnooze: () => snoozeTapped = true,
      onSkip: () => skipTapped = true,
      onEdit: () {},
      onDelete: () {},
    ));
    await tester.pumpAndSettle();

    // Find Slidable and trigger drag right (revealing startActionPane)
    final cardFinder = find.byType(MedicationCard);
    await tester.drag(cardFinder, const Offset(250, 0));
    await tester.pumpAndSettle();

    // Verify amber clock icon and forward icon are visible
    expect(find.byIcon(CupertinoIcons.clock_fill), findsOneWidget);
    expect(find.byIcon(CupertinoIcons.forward_fill), findsOneWidget);

    // Tap Snooze
    await tester.tap(find.byIcon(CupertinoIcons.clock_fill));
    await tester.pumpAndSettle();
    expect(snoozeTapped, isTrue);

    // Drag right again to tap Skip
    await tester.drag(cardFinder, const Offset(250, 0));
    await tester.pumpAndSettle();

    await tester.tap(find.byIcon(CupertinoIcons.forward_fill));
    await tester.pumpAndSettle();
    expect(skipTapped, isTrue);
  });

  testWidgets('Swipe left reveals Edit and Delete buttons', (tester) async {
    bool editTapped = false;

    await tester.pumpWidget(createCard(
      onSnooze: () {},
      onSkip: () {},
      onEdit: () => editTapped = true,
      onDelete: () {},
    ));
    await tester.pumpAndSettle();

    // Drag left (revealing endActionPane)
    final cardFinder = find.byType(MedicationCard);
    await tester.drag(cardFinder, const Offset(-250, 0));
    await tester.pumpAndSettle();

    // Verify trash and pencil icons are present
    expect(find.byIcon(CupertinoIcons.trash_fill), findsOneWidget);
    expect(find.byIcon(CupertinoIcons.pencil), findsOneWidget);

    // Tap Edit
    await tester.tap(find.byIcon(CupertinoIcons.pencil));
    await tester.pumpAndSettle();
    expect(editTapped, isTrue);
  });

  testWidgets('Overswiping left triggers dismiss confirmation sheet', (tester) async {
    bool deleteTriggered = false;

    await tester.pumpWidget(createCard(
      onSnooze: () {},
      onSkip: () {},
      onEdit: () {},
      onDelete: () => deleteTriggered = true,
    ));
    await tester.pumpAndSettle();

    final cardFinder = find.byType(MedicationCard);
    await tester.timedDrag(
      cardFinder,
      const Offset(-600, 0),
      const Duration(milliseconds: 400),
    );
    await tester.pumpAndSettle();

    // Confirm sheet appears
    expect(find.text('Delete "Metformin"?'), findsOneWidget);
    expect(find.text('Delete Prescription'), findsOneWidget);

    // Tap Delete Prescription
    await tester.tap(find.text('Delete Prescription'));
    await tester.pumpAndSettle();
    expect(deleteTriggered, isTrue);
  });

  testWidgets('Cancelling overswipe sheet snaps slidable back closed', (tester) async {
    bool deleteTriggered = false;

    await tester.pumpWidget(createCard(
      onSnooze: () {},
      onSkip: () {},
      onEdit: () {},
      onDelete: () => deleteTriggered = true,
    ));
    await tester.pumpAndSettle();

    final cardFinder = find.byType(MedicationCard);
    await tester.timedDrag(
      cardFinder,
      const Offset(-600, 0),
      const Duration(milliseconds: 400),
    );
    await tester.pumpAndSettle();

    // Confirm sheet appears
    expect(find.text('Cancel'), findsOneWidget);

    // Tap Cancel
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();
    expect(deleteTriggered, isFalse);
    expect(find.text('Delete "Metformin"?'), findsNothing);
  });

  testWidgets('Dragging slightly past extent (< threshold) springs back to open buttons', (tester) async {
    await tester.pumpWidget(createCard(
      onSnooze: () {},
      onSkip: () {},
      onEdit: () {},
      onDelete: () {},
    ));
    await tester.pumpAndSettle();

    final cardFinder = find.byType(MedicationCard);
    // Drag -350px (43.75% of 800px, which is > 32% extent but < 65% dismissThreshold)
    await tester.timedDrag(
      cardFinder,
      const Offset(-350, 0),
      const Duration(milliseconds: 400),
    );
    await tester.pumpAndSettle();

    // No sheet should have appeared
    expect(find.text('Delete "Metformin"?'), findsNothing);

    // Both Edit and Delete icons should still be visible in the open resting position
    expect(find.byIcon(CupertinoIcons.pencil), findsOneWidget);
    expect(find.byIcon(CupertinoIcons.trash_fill), findsOneWidget);

    // Tapping the Delete circle after springing back still opens the confirmation sheet
    await tester.tap(find.byIcon(CupertinoIcons.trash_fill));
    await tester.pumpAndSettle();
    expect(find.text('Delete "Metformin"?'), findsOneWidget);
  });

  testWidgets('Tapping Delete button confirms and deletes, or cancels cleanly', (tester) async {
    bool deleteTriggered = false;

    await tester.pumpWidget(createCard(
      onSnooze: () {},
      onSkip: () {},
      onEdit: () {},
      onDelete: () => deleteTriggered = true,
    ));
    await tester.pumpAndSettle();

    final cardFinder = find.byType(MedicationCard);
    await tester.drag(cardFinder, const Offset(-200, 0));
    await tester.pumpAndSettle();

    // Tap Delete button -> confirmation sheet appears
    await tester.tap(find.byIcon(CupertinoIcons.trash_fill));
    await tester.pumpAndSettle();
    expect(find.text('Delete "Metformin"?'), findsOneWidget);

    // Cancel -> closes without deleting
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();
    expect(deleteTriggered, isFalse);

    // Open again and confirm Delete
    await tester.drag(cardFinder, const Offset(-200, 0));
    await tester.pumpAndSettle();
    await tester.tap(find.byIcon(CupertinoIcons.trash_fill));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Delete Prescription'));
    await tester.pumpAndSettle();
    expect(deleteTriggered, isTrue);
  });

  testWidgets('Overswiping left keeps Delete oval at 44px height with trash at front and Edit spaced in front', (tester) async {
    await tester.pumpWidget(createCard(
      onSnooze: () {},
      onSkip: () {},
      onEdit: () {},
      onDelete: () {},
    ));
    await tester.pumpAndSettle();

    // Start a drag > 32% of 800px (say -440px = 55%) and hold without releasing
    final gesture = await tester.startGesture(tester.getCenter(find.byType(MedicationCard)));
    await gesture.moveBy(const Offset(-440, 0));
    await tester.pump();

    final trashRect = tester.getRect(find.byIcon(CupertinoIcons.trash_fill));
    final editRect = tester.getRect(find.byIcon(CupertinoIcons.pencil));
    final deleteOvalContainer = tester.widget<Container>(
      find.ancestor(
        of: find.byIcon(CupertinoIcons.trash_fill),
        matching: find.byType(Container),
      ).first,
    );
    final deleteOvalRect = tester.getRect(
      find.ancestor(
        of: find.byIcon(CupertinoIcons.trash_fill),
        matching: find.byType(Container),
      ).first,
    );
    final editCircleRect = tester.getRect(
      find.ancestor(
        of: find.byIcon(CupertinoIcons.pencil),
        matching: find.byType(Container),
      ).first,
    );

    // Red Delete oval maintains exact 44px height and lengthens horizontally past 44px
    expect(deleteOvalRect.height, 44.0);
    expect(deleteOvalRect.width, greaterThan(100.0));
    expect((deleteOvalContainer.decoration as BoxDecoration).borderRadius, BorderRadius.circular(22.0));

    // Trash icon stays anchored near the leading (left) front of the red oval
    expect(trashRect.left - deleteOvalRect.left, closeTo(12.0, 1.0));

    // Edit button stays visible in front of the red oval with an 8px gap
    expect(editRect, isNotNull);
    expect(deleteOvalRect.left - editCircleRect.right, closeTo(8.0, 1.0));

    await gesture.up();
    await tester.pumpAndSettle();
  });

  testWidgets('Android renders plain card with no swipe actions', (tester) async {
    await tester.pumpWidget(MaterialApp(
      theme: ThemeData(platform: TargetPlatform.android),
      home: Scaffold(
        body: MedicationCard(
          item: prescription,
          time: '8:00 AM',
          isTaken: false,
          profile: null,
          onTakeDose: () {},
          onViewDetails: () {},
          onSnooze: () {},
          onSkip: () {},
          onEdit: () {},
          onDelete: () {},
        ),
      ),
    ));
    await tester.pumpAndSettle();

    await tester.drag(find.byType(MedicationCard), const Offset(-250, 0));
    await tester.pumpAndSettle();
    expect(find.byIcon(CupertinoIcons.trash_fill), findsNothing);
    expect(find.byIcon(CupertinoIcons.pencil), findsNothing);

    await tester.drag(find.byType(MedicationCard), const Offset(250, 0));
    await tester.pumpAndSettle();
    expect(find.byIcon(CupertinoIcons.clock_fill), findsNothing);
    expect(find.byIcon(CupertinoIcons.forward_fill), findsNothing);
  });

  testWidgets('Press-and-hold opens Quick View while finger is down without double-opening on release (iOS & Android)',
      (tester) async {
    for (final platform in [TargetPlatform.iOS, TargetPlatform.android]) {
      var viewDetailsCount = 0;
      await tester.pumpWidget(MaterialApp(
        theme: ThemeData(platform: platform),
        home: Scaffold(
          body: MedicationCard(
            item: prescription,
            time: '8:00 AM',
            isTaken: false,
            profile: null,
            onTakeDose: () {},
            onViewDetails: () => viewDetailsCount++,
            onSnooze: () {},
            onSkip: () {},
            onEdit: () {},
            onDelete: () {},
          ),
        ),
      ));
      await tester.pumpAndSettle();

      // Press and hold on card center without lifting finger
      final gesture = await tester.startGesture(
        tester.getCenter(find.text('Metformin')),
      );
      await tester.pump(const Duration(milliseconds: 200));
      expect(viewDetailsCount, 0);

      // Past ~375ms -> fires immediately while finger is STILL DOWN
      await tester.pump(const Duration(milliseconds: 220));
      expect(viewDetailsCount, 1);

      // Releasing finger must NOT double-open
      await gesture.up();
      await tester.pumpAndSettle();
      expect(viewDetailsCount, 1);

      // Allow cooldown timer to clear before next platform iteration
      await tester.pump(const Duration(milliseconds: 400));
    }
  });

  testWidgets('Open swipe action buttons block hold-to-peek and tapping card or check closes pane without firing actions',
      (tester) async {
    var viewDetailsCount = 0;
    var takeDoseCount = 0;

    await tester.pumpWidget(MaterialApp(
      theme: ThemeData(platform: TargetPlatform.iOS),
      home: Scaffold(
        body: MedicationCard(
          item: prescription,
          time: '8:00 AM',
          isTaken: false,
          profile: null,
          onTakeDose: () => takeDoseCount++,
          onViewDetails: () => viewDetailsCount++,
          onSnooze: () {},
          onSkip: () {},
          onEdit: () {},
          onDelete: () {},
        ),
      ),
    ));
    await tester.pumpAndSettle();

    // Swipe right to reveal Snooze/Skip buttons
    await tester.drag(find.byType(MedicationCard), const Offset(250, 0));
    await tester.pumpAndSettle();
    expect(find.byIcon(CupertinoIcons.clock_fill), findsOneWidget);

    // Press-and-hold while pane is open must NOT peek
    final holdGesture =
        await tester.startGesture(tester.getCenter(find.text('Metformin')));
    await tester.pump(const Duration(milliseconds: 450));
    expect(viewDetailsCount, 0);
    await holdGesture.up();
    await tester.pumpAndSettle();
    expect(viewDetailsCount, 0);

    // Swipe right open again and tap card -> closes pane without opening Quick View
    await tester.drag(find.byType(MedicationCard), const Offset(250, 0));
    await tester.pumpAndSettle();
    expect(find.byIcon(CupertinoIcons.clock_fill), findsOneWidget);

    await tester.tap(find.text('Metformin'));
    await tester.pumpAndSettle();
    expect(viewDetailsCount, 0);
    expect(find.byIcon(CupertinoIcons.clock_fill), findsNothing);

    // Open swipe-left buttons, tap the dose check circle -> closes pane without marking taken
    await tester.drag(find.byType(MedicationCard), const Offset(-250, 0));
    await tester.pumpAndSettle();
    expect(find.byIcon(CupertinoIcons.pencil), findsOneWidget);

    final cardRect = tester.getRect(find.byType(MedicationCard));
    // Tap near the right edge of the slid card where _DoseCheck sits
    await tester.tapAt(Offset(cardRect.right - 290, cardRect.center.dy));
    await tester.pumpAndSettle();
    expect(takeDoseCount, 0);
    expect(viewDetailsCount, 0);
  });

  testWidgets('Active snooze shows snooze badge and flips swipe-right Snooze button to Cancel Snooze',
      (tester) async {
    var cancelSnoozeTapped = false;

    await tester.pumpWidget(MaterialApp(
      theme: ThemeData(platform: TargetPlatform.iOS),
      home: Scaffold(
        body: MedicationCard(
          item: prescription,
          time: '8:00 AM',
          isTaken: false,
          isSnoozeActive: true,
          snoozeEndTime: DateTime(2026, 10, 26, 8, 15),
          profile: null,
          onTakeDose: () {},
          onViewDetails: () {},
          onSnooze: () {},
          onCancelSnooze: () => cancelSnoozeTapped = true,
          onSkip: () {},
        ),
      ),
    ));
    await tester.pumpAndSettle();

    expect(find.text('Snoozed • 8:15 AM'), findsOneWidget);

    await tester.drag(find.byType(MedicationCard), const Offset(250, 0));
    await tester.pumpAndSettle();

    expect(find.byIcon(CupertinoIcons.bell_slash_fill), findsOneWidget);
    await tester.tap(find.byIcon(CupertinoIcons.bell_slash_fill));
    await tester.pumpAndSettle();
    expect(cancelSnoozeTapped, isTrue);
  });
}
