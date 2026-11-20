import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pillpal/core/theme/app_theme.dart';
import 'package:pillpal/ui/widgets/medication_type_selector.dart';

void main() {
  group('MedicationTypeSelector', () {
    testWidgets('renders primary chips including Topical and Other', (tester) async {
      String? selected = 'Pill / Oral';

      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.lightTheme,
          home: Scaffold(
            body: StatefulBuilder(
              builder: (context, setState) => MedicationTypeSelector(
                selectedType: selected,
                onSelected: (val) => setState(() => selected = val),
              ),
            ),
          ),
        ),
      );

      for (final label in [
        'Pill / Oral',
        'Liquid',
        'Inhaler',
        'Injection',
        'Topical',
        'Other',
      ]) {
        expect(find.text(label), findsOneWidget);
      }

      await tester.tap(find.text('Topical'));
      await tester.pumpAndSettle();

      expect(selected, 'Topical');
    });

    testWidgets('Other sheet supports searching and custom entry', (tester) async {
      String? selected = 'Pill / Oral';

      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.lightTheme,
          home: Scaffold(
            body: StatefulBuilder(
              builder: (context, setState) => MedicationTypeSelector(
                selectedType: selected,
                onSelected: (val) => setState(() => selected = val),
              ),
            ),
          ),
        ),
      );

      await tester.ensureVisible(find.byKey(const Key('med_type_chip_other')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('med_type_chip_other')));
      await tester.pumpAndSettle();

      expect(find.text('Other Medication Type'), findsOneWidget);
      expect(find.byKey(const Key('medication_type_search_field')), findsOneWidget);

      // Search for an existing secondary option
      await tester.enterText(
        find.byKey(const Key('medication_type_search_field')),
        'Suppository',
      );
      await tester.pumpAndSettle();
      expect(find.widgetWithText(ListTile, 'Suppository'), findsOneWidget);

      // Enter a custom value not in the list
      await tester.enterText(
        find.byKey(const Key('medication_type_search_field')),
        'Mouthwash',
      );
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('medication_type_custom_option')), findsOneWidget);
      expect(find.text('Use "Mouthwash"'), findsOneWidget);

      await tester.tap(find.byKey(const Key('medication_type_custom_option')));
      await tester.pumpAndSettle();

      expect(selected, 'Mouthwash');
      expect(find.text('Other: Mouthwash'), findsOneWidget);
    });
  });
}
