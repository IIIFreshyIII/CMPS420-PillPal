import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pillpal/core/theme/app_theme.dart';
import 'package:pillpal/data/models/prescription.dart';
import 'package:pillpal/data/models/profile.dart';
import 'package:pillpal/data/services/extractor.dart';
import 'package:pillpal/screens/confirm/confirm_screen.dart';
import 'package:pillpal/screens/medication_detail/medication_detail_sheet.dart';
import 'package:pillpal/screens/medication_form/medication_form.dart';

void main() {
  const profiles = [
    Profile(id: '1', name: 'Me', color: Colors.blue, isPrimary: true),
    Profile(id: '2', name: 'Mom', color: Colors.purple),
  ];

  testWidgets(
      'Shared MedicationForm toggles Scheduled <-> As Needed and saves PRN fields',
      (tester) async {
    tester.view.physicalSize = const Size(1200, 2600);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    Prescription? saved;
    await tester.pumpWidget(MaterialApp(
      theme: AppTheme.lightTheme,
      home: Builder(
        builder: (context) => ElevatedButton(
          onPressed: () async {
            saved = await ConfirmScreen.show(
              context,
              profiles: profiles,
              isManual: true,
            );
          },
          child: const Text('open'),
        ),
      ),
    ));

    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();

    // Enter name, strength, and multi-pill dose amount
    await tester.enterText(find.byKey(const Key('field_drug')), 'Ibuprofen');
    await tester.enterText(find.byKey(const Key('field_strength')), '200 mg');
    await tester.enterText(find.byKey(const Key('field_dose')), '2 tablets');
    await tester.pumpAndSettle();

    // Auto-parsed doseQuantity == 2
    expect(find.text('2'), findsWidgets);

    // Select "With food"
    await tester.tap(find.byKey(const Key('med_form_food_with_food')));
    await tester.pumpAndSettle();

    // Switch top toggle to As Needed
    await tester.tap(find.byKey(const Key('med_form_mode_as_needed')));
    await tester.pumpAndSettle();

    // Pick 6h cooldown and toggle Allow after bedtime
    await tester.tap(find.byKey(const Key('med_form_cooldown_360')));
    await tester.tap(find.byKey(const Key('med_form_allow_after_bedtime')));
    await tester.enterText(find.byKey(const Key('field_quantity')), '40');
    await tester.pumpAndSettle();

    // Save with blank refills (optional)
    await tester.tap(find.byKey(const Key('confirm_save_button')));
    await tester.pumpAndSettle();

    expect(saved, isNotNull);
    expect(saved!.name, 'Ibuprofen');
    expect(saved!.strength, '200 mg');
    expect(saved!.doseAmount, '2 tablets');
    expect(saved!.doseQuantity, 2);
    expect(saved!.foodInstruction, 'with_food');
    expect(saved!.isAsNeeded, isTrue);
    expect(saved!.cooldownMinutes, 360);
    expect(saved!.allowAfterBedtime, isTrue);
    expect(saved!.reminderTimes, isEmpty);
    expect(saved!.remaining, 40);
    expect(saved!.refillsRemaining, 0);
  });

  testWidgets(
      'OCR amber flags highlight only missed/unrecognized fields and clear on edit',
      (tester) async {
    tester.view.physicalSize = const Size(1200, 2600);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    final extraction = Extraction(rawText: 'LISINOPRIL 10 MG')
      ..drug = 'Lisinopril'
      ..strength = '10 mg'
      ..dose = null // missed on label -> flagged
      ..form = 'tablet'
      ..frequency = 'once daily'
      ..daysSupply = 30
      ..quantity = 30
      ..fieldRecognized['drug'] = true
      ..fieldRecognized['strength'] = false; // low confidence -> flagged

    await tester.pumpWidget(MaterialApp(
      theme: AppTheme.lightTheme,
      home: Builder(
        builder: (context) => ElevatedButton(
          onPressed: () => ConfirmScreen.show(
            context,
            extraction: extraction,
            profiles: profiles,
            isManual: false,
          ),
          child: const Text('open'),
        ),
      ),
    ));

    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();

    // Unrecognized strength + missed dose are flagged; optional refills is NOT falsely flagged.
    expect(find.text('Verify — OCR read "10 mg"'), findsOneWidget);
    expect(find.text('Not detected on label'), findsOneWidget);

    // Editing the flagged field clears its amber warning live.
    await tester.enterText(find.byKey(const Key('field_strength')), '20 mg');
    await tester.enterText(find.byKey(const Key('field_dose')), '1 tablet');
    await tester.pumpAndSettle();

    expect(find.text('Verify — OCR read "10 mg"'), findsNothing);
    expect(find.text('Not detected on label'), findsNothing);
  });

  testWidgets(
      'MedicationDetailSheet allows editing reminder times and multi-pill supply math',
      (tester) async {
    tester.view.physicalSize = const Size(1200, 2600);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    const existing = Prescription(
      id: 'rx_edit',
      profileId: '1',
      name: 'Metformin',
      dosage: '500 mg, 2 tablets',
      strength: '500 mg',
      doseAmount: '2 tablets',
      doseQuantity: 2,
      reminderTimes: ['8:00 AM'],
      remaining: 60,
      daysSupply: 30,
      refillsRemaining: 1,
    );

    Prescription? updated;
    await tester.pumpWidget(MaterialApp(
      theme: AppTheme.lightTheme,
      home: Builder(
        builder: (context) => ElevatedButton(
          onPressed: () => MedicationDetailSheet.show(
            context,
            prescription: existing,
            profiles: profiles,
            onUpdate: (rx) => updated = rx,
            onDelete: () {},
          ),
          child: const Text('open'),
        ),
      ),
    ));

    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();

    // Switch frequency from Once daily -> Twice daily in Edit mode
    await tester.tap(find.text('Twice daily'));
    await tester.pumpAndSettle();

    // Save changes
    await tester.tap(find.byKey(const Key('detail_save_button')));
    await tester.pumpAndSettle();

    expect(updated, isNotNull);
    expect(updated!.reminderTimes, ['8:00 AM', '8:00 PM']);
    expect(updated!.doseQuantity, 2);
  });

  test('Prescription multi-pill doseQuantity decrements remaining and daysSupply accurately',
      () {
    expect(Prescription.parseDoseQuantity('2 tablets'), 2);
    expect(Prescription.parseDoseQuantity('Take two capsules'), 2);
    expect(Prescription.parseDoseQuantity('3 puffs'), 3);
    expect(Prescription.parseDoseQuantity(''), 1);

    const rx = Prescription(
      id: 'rx_multi',
      profileId: '1',
      name: 'Calcium',
      dosage: '500 mg, 2 tablets',
      doseQuantity: 2,
      reminderTimes: ['8:00 AM'],
      remaining: 60,
      daysSupply: 30,
    );
    expect(rx.dailyDoseUnits, 2);
    final nextRemaining = rx.remaining - rx.effectiveDoseQuantity;
    expect(nextRemaining, 58);
    expect(
      rx.adjustedDaysSupply(newRemaining: nextRemaining, deltaDoses: -1),
      29,
    );
  });
}
