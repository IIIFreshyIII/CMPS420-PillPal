import 'dart:ui' show ImageFilter;

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pillpal/core/theme/app_theme.dart';
import 'package:pillpal/presentation/widgets/classic_ios_tab_bar.dart';
import 'package:pillpal/presentation/widgets/floating_tab_bar.dart';

void main() {
  Future<void> pumpBar(
    WidgetTester tester, {
    required Size size,
    EdgeInsets padding = EdgeInsets.zero,
    AppTab active = AppTab.schedule,
    ValueChanged<AppTab>? onTap,
    bool translucent = false,
    double textScale = 1.0,
  }) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(MaterialApp(
      theme: AppTheme.lightTheme,
      home: MediaQuery(
        data: MediaQueryData(
          size: size,
          padding: padding,
          textScaler: TextScaler.linear(textScale),
        ),
        child: Scaffold(
          body: const SizedBox.expand(),
          bottomNavigationBar: ClassicIOSTabBar(
            activeTab: active,
            onTabPress: onTap ?? (_) {},
            translucent: translucent,
          ),
        ),
      ),
    ));
  }

  double barHeight(WidgetTester tester) =>
      tester.getSize(find.byType(ClassicIOSTabBar)).height;

  testWidgets('home-button iPhone portrait: 49pt bar, no inset, stacked items',
      (tester) async {
    // iPhone 8 / SE (2nd & 3rd gen): 375x667pt, no home indicator.
    await pumpBar(tester, size: const Size(375, 667));

    expect(barHeight(tester), ClassicIOSTabBar.regularHeight);
    expect(find.text('Schedule'), findsOneWidget);
    expect(find.text('Meds'), findsOneWidget);
    expect(find.text('Profile'), findsOneWidget);

    // Stacked: glyph sits above its label.
    final icon = tester.getCenter(find.byIcon(CupertinoIcons.capsule));
    final label = tester.getCenter(find.text('Meds'));
    expect(icon.dy, lessThan(label.dy));
    expect((icon.dx - label.dx).abs(), lessThan(1.0));
  });

  testWidgets('Face ID iPhone adds the home-indicator inset below the 49pt bar',
      (tester) async {
    await pumpBar(
      tester,
      size: const Size(375, 812),
      padding: const EdgeInsets.only(bottom: 34),
    );
    expect(barHeight(tester), ClassicIOSTabBar.regularHeight + 34);
  });

  testWidgets('iPhone landscape uses the 32pt compact bar with inline items',
      (tester) async {
    await pumpBar(tester, size: const Size(667, 375));

    expect(barHeight(tester), ClassicIOSTabBar.compactHeight);
    final icon = tester.getCenter(find.byIcon(CupertinoIcons.capsule));
    final label = tester.getCenter(find.text('Meds'));
    expect(icon.dx, lessThan(label.dx));
    expect((icon.dy - label.dy).abs(), lessThan(2.0));
  });

  testWidgets('selected tab is teal with a filled glyph; others are systemGray',
      (tester) async {
    await pumpBar(tester, size: const Size(375, 667), active: AppTab.meds);

    expect(find.byIcon(CupertinoIcons.capsule_fill), findsOneWidget);
    expect(find.byIcon(CupertinoIcons.capsule), findsNothing);
    expect(find.byIcon(CupertinoIcons.calendar_today), findsOneWidget);

    final medsColor = tester.widget<Text>(find.text('Meds')).style!.color;
    final scheduleColor =
        tester.widget<Text>(find.text('Schedule')).style!.color;
    expect(medsColor, const Color(0xFF168B87));
    expect(scheduleColor, const Color(0xFF8E8E93));
  });

  testWidgets('tapping a tab reports it', (tester) async {
    AppTab? tapped;
    await pumpBar(tester,
        size: const Size(375, 667), onTap: (t) => tapped = t);

    await tester.tap(find.text('Profile'));
    expect(tapped, AppTab.profile);
  });

  testWidgets('labels ignore Dynamic Type so the bar never overflows',
      (tester) async {
    await pumpBar(tester, size: const Size(320, 568), textScale: 3.0);

    expect(barHeight(tester), ClassicIOSTabBar.regularHeight);
    expect(tester.takeException(), isNull);
  });

  testWidgets('blur only when translucent; opaque bars skip the BackdropFilter',
      (tester) async {
    await pumpBar(tester, size: const Size(375, 667), translucent: false);
    expect(
      find.descendant(
          of: find.byType(ClassicIOSTabBar),
          matching: find.byType(BackdropFilter)),
      findsNothing,
    );

    await pumpBar(tester, size: const Size(375, 667), translucent: true);
    final filter = tester.widget<BackdropFilter>(find.descendant(
        of: find.byType(ClassicIOSTabBar),
        matching: find.byType(BackdropFilter)));
    expect(filter.filter, isA<ImageFilter>());
  });
}
