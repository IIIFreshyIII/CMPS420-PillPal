import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:pillpal/main.dart';
import 'package:pillpal/models/medication.dart';
import 'package:pillpal/services/med_store.dart';

void main() {
  test('refillDate is fill date + days supply, warn is 7 days before', () {
    final m = Medication(
      id: '1',
      fillDate: DateTime(2026, 8, 1),
      daysSupply: 30,
    );
    expect(m.refillDate, DateTime(2026, 8, 31));
    expect(m.refillWarnDate, DateTime(2026, 8, 24));
  });

  test('refillDate is null without both inputs', () {
    expect(Medication(id: '1', daysSupply: 30).refillDate, isNull);
    expect(Medication(id: '1', fillDate: DateTime(2026)).refillDate, isNull);
  });

  testWidgets('capture -> confirm -> save adds a medication to the list',
      (tester) async {
    // start from a clean store
    for (final m in MedStore.instance.meds.toList()) {
      MedStore.instance.remove(m.id);
    }

    await tester.pumpWidget(const PillPalApp());
    expect(find.text('No medications yet'), findsOneWidget);

    await tester.tap(find.text('Add from label'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Simulate capture'));
    await tester.pumpAndSettle();

    expect(find.text('Check the details'), findsOneWidget);
    await tester.tap(find.text('Confirm & save'));
    await tester.pumpAndSettle();

    expect(find.text('Metformin HCl'), findsOneWidget);
    expect(MedStore.instance.meds, hasLength(1));
  });
}
