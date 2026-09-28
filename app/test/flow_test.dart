import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:pillpal/main.dart';
import 'package:pillpal/data/models/medication.dart';

void main() {
  // `Medication` (the label-extraction model) isn't wired into the live UI
  // yet -- see PillPal/app/README.md -- but its refill-date arithmetic is
  // real, load-bearing logic, so it stays covered here.
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

  testWidgets('home screen shows the seeded schedule and a scan adds a med',
      (tester) async {
    // tall surface so the schedule screen fits without scrolling
    tester.view.physicalSize = const Size(1200, 3000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(const PillPalApp());
    await tester.pumpAndSettle();

    // HomeScaffold seeds three hardcoded prescriptions on the Schedule tab.
    expect(find.text('Allegra'), findsOneWidget);
    expect(find.text('Amoxicillin'), findsNothing);

    await tester.tap(find.text('+ Scan Bottle'));
    await tester.pump(); // isScanning = true
    await tester.pump(const Duration(milliseconds: 1500)); // fake scan delay
    await tester.pumpAndSettle();

    // _simulateScan() inserts a hardcoded Amoxicillin prescription.
    expect(find.text('Amoxicillin'), findsOneWidget);
  });
}
