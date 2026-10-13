import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pillpal/core/theme/app_theme.dart';
import 'package:pillpal/presentation/widgets/profile_chip.dart';

void main() {
  testWidgets('ProfileChip renders with pill shape (BorderRadius 20) and triggers onTap',
      (tester) async {
    var tapped = false;

    await tester.pumpWidget(MaterialApp(
      theme: AppTheme.lightTheme,
      home: Scaffold(
        body: Center(
          child: ProfileChip(
            label: 'Mom',
            isSelected: true,
            selectedColor: Colors.orange,
            onTap: () => tapped = true,
          ),
        ),
      ),
    ));
    await tester.pumpAndSettle();

    expect(find.text('Mom'), findsOneWidget);

    final container = tester.widget<Container>(
      find.ancestor(of: find.text('Mom'), matching: find.byType(Container)).first,
    );
    final decoration = container.decoration as BoxDecoration;
    expect(decoration.borderRadius, BorderRadius.circular(20));
    expect(decoration.color, Colors.orange);

    await tester.tap(find.text('Mom'));
    await tester.pumpAndSettle();
    expect(tapped, isTrue);
  });

  testWidgets('ProfileChip unselected renders surface background and borderChip',
      (tester) async {
    await tester.pumpWidget(MaterialApp(
      theme: AppTheme.lightTheme,
      home: Scaffold(
        body: Center(
          child: ProfileChip(
            label: 'All',
            isSelected: false,
            onTap: () {},
          ),
        ),
      ),
    ));
    await tester.pumpAndSettle();

    final container = tester.widget<Container>(
      find.ancestor(of: find.text('All'), matching: find.byType(Container)).first,
    );
    final decoration = container.decoration as BoxDecoration;
    expect(decoration.borderRadius, BorderRadius.circular(20));
    expect(decoration.boxShadow, isNull);
  });
}
