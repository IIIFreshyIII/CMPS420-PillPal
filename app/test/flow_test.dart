import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:pillpal/core/ner/refill_math.dart';
import 'package:pillpal/core/theme/app_theme.dart';
import 'package:pillpal/data/local/app_database.dart';
import 'package:pillpal/data/models/prescription.dart';
import 'package:pillpal/data/models/profile.dart';
import 'package:pillpal/data/services/extractor.dart';
import 'package:pillpal/screens/confirm/confirm_screen.dart';
import 'package:pillpal/screens/home/home_scaffold.dart';

void main() {
  // Refill-date arithmetic is real, load-bearing logic (spec rule: plain
  // math, never predicted by a model), so it stays covered here even though
  // it now lives in core/ner/refill_math.dart rather than on a Medication
  // model -- see extractor.dart / extraction_mapper.dart for the current
  // extraction-side design.
  test('refillDate is fill date + days supply, warn is 7 days before', () {
    final fillDate = DateTime(2026, 8, 1);
    expect(
      computeRefillDate(fillDate: fillDate, daysSupply: 30),
      DateTime(2026, 8, 31),
    );
    expect(
      computeRefillWarnDate(fillDate: fillDate, daysSupply: 30),
      DateTime(2026, 8, 24),
    );
  });

  test('refillDate is null without both inputs', () {
    expect(computeRefillDate(daysSupply: 30), isNull);
    expect(computeRefillDate(fillDate: DateTime(2026)), isNull);
  });

  testWidgets('Add Meds opens the anchored popover menu with 3 modes',
      (tester) async {
    // tall surface so the schedule screen fits without scrolling
    tester.view.physicalSize = const Size(1200, 3000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    // Real PillPalApp always opens a real on-disk database (path_provider
    // needs a platform channel this plain widget test doesn't have), so an
    // in-memory AppDatabase is injected here instead -- same schema/seed
    // logic, no disk access.
    await tester.pumpWidget(MaterialApp(
      theme: AppTheme.lightTheme,
      home: HomeScaffold(database: AppDatabase(NativeDatabase.memory())),
    ));
    await tester.pumpAndSettle();

    // HomeScaffold seeds three demo prescriptions on the Schedule tab.
    expect(find.text('Allegra'), findsOneWidget);

    await tester.tap(find.text('Add Meds'));
    await tester.pumpAndSettle();

    // The real entry point: an anchored popover with live scan, photo import,
    // and manual entry.
    expect(find.text('Scan Bottle'), findsOneWidget);
    expect(find.text('Import from Photos'), findsOneWidget);
    expect(find.text('Enter Manually'), findsOneWidget);

    // Dispose HomeScaffold here (rather than leaving it to the implicit
    // end-of-test teardown): closing its DoseEvent/Prescription/Profile
    // stream subscriptions schedules a zero-duration Timer inside drift's
    // StreamQueryStore, and this pump gives it a chance to fire before
    // flutter_test's pending-timer check runs.
    await tester.pumpWidget(const SizedBox());
    // `pump()` with no duration never calls FakeAsync.elapse(), so a
    // zero-duration Timer never actually fires -- an explicit (even zero)
    // duration is required to flush it.
    await tester.pump(Duration.zero);
  });

  testWidgets('ConfirmScreen maps a confirmed Extraction into a real Prescription',
      (tester) async {
    // Same shape StubExtractor used to return -- this is the confirm-and-save
    // path's coverage now that a real camera/model can't run in a widget test.
    final extraction = Extraction(rawText: 'test label')
      ..drug = 'Metformin HCl'
      ..strength = '500 mg'
      ..dose = '1 tablet'
      ..form = 'tablet'
      ..frequency = 'twice daily'
      ..daysSupply = 30;
    const profiles = [Profile(id: '1', name: 'Me', color: Color(0xFF3B82F6), isPrimary: true)];

    // tall surface so every field, including the save button, is mounted --
    // a ListView's sliver only builds children near the viewport.
    tester.view.physicalSize = const Size(1200, 3000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    Prescription? result;
    await tester.pumpWidget(MaterialApp(
      theme: AppTheme.lightTheme,
      home: Builder(
        builder: (context) => ElevatedButton(
          onPressed: () async {
            result = await ConfirmScreen.show(context, extraction: extraction, profiles: profiles);
          },
          child: const Text('open'),
        ),
      ),
    ));

    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();

    // Fields pre-filled from the extraction -- shown both in the hero card
    // (which live-updates from the drug-name field) and the field itself.
    expect(find.text('Metformin HCl'), findsWidgets);

    // All-in-one verification sheet: name, dosage, schedule and profile are
    // all pre-filled and editable in a single view.
    final saveButton = tester.widget<GestureDetector>(find.byKey(const Key('confirm_save_button')));
    expect(saveButton.onTap, isNotNull);

    await tester.tap(find.byKey(const Key('confirm_save_button')));
    await tester.pumpAndSettle();

    expect(result, isNotNull);
    expect(result!.name, 'Metformin HCl');
    expect(result!.dosage, '500 mg, 1 tablet, tablet');
    // "twice daily" is periodic (12h interval) -- at least the picked start
    // time is always included; exact count depends on the real wall clock
    // the rotary picker defaulted to (TimeOfDay.now()), so only the format
    // and non-emptiness are asserted, not a literal count.
    expect(result!.reminderTimes, isNotEmpty);
    for (final time in result!.reminderTimes) {
      expect(time, matches(RegExp(r'^\d{1,2}:\d{2} (AM|PM)$')));
    }
    expect(result!.daysSupply, 30);
    expect(result!.remaining, 30);
    expect(result!.profileId, '1');
  });
}
