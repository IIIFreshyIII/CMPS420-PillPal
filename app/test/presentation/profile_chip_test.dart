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

  testWidgets('All chip selected in Dark mode renders teal background and dark text',
      (tester) async {
    await tester.pumpWidget(MaterialApp(
      theme: AppTheme.darkTheme,
      home: Scaffold(
        body: Center(
          child: ProfileChip(
            label: 'All',
            isSelected: true,
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
    // Should be dark mode c.teal, NOT bright white c.ink
    expect(decoration.color, const Color(0xFF2FB5AE));

    final defaultTextStyle = tester.widget<AnimatedDefaultTextStyle>(
      find.ancestor(of: find.text('All'), matching: find.byType(AnimatedDefaultTextStyle)).first,
    );
    // Text color should be c.onTeal (0xFF0C1514) for high contrast
    expect(defaultTextStyle.style.color, const Color(0xFF0C1514));
  });

  testWidgets('All chip selected in Light mode renders dark ink background and white text',
      (tester) async {
    await tester.pumpWidget(MaterialApp(
      theme: AppTheme.lightTheme,
      home: Scaffold(
        body: Center(
          child: ProfileChip(
            label: 'All',
            isSelected: true,
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
    expect(decoration.color, const Color(0xFF102A29));

    final defaultTextStyle = tester.widget<AnimatedDefaultTextStyle>(
      find.ancestor(of: find.text('All'), matching: find.byType(AnimatedDefaultTextStyle)).first,
    );
    expect(defaultTextStyle.style.color, Colors.white);
  });
}

