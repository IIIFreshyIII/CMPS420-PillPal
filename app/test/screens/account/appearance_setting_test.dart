import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:pillpal/screens/account/appearance_setting.dart';

void main() {
  Future<List<ThemeMode>> pump(WidgetTester tester, ThemeMode mode) async {
    final calls = <ThemeMode>[];
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: SizedBox(
          width: 360,
          child: AppearanceSwitch(mode: mode, onChanged: calls.add),
        ),
      ),
    ));
    return calls;
  }

  testWidgets('tapping another segment reports that mode', (tester) async {
    final calls = await pump(tester, ThemeMode.system);
    await tester.tap(find.text('Dark'));
    await tester.pump();
    expect(calls, [ThemeMode.dark]);
  });

  testWidgets('tapping the selected segment does nothing', (tester) async {
    final calls = await pump(tester, ThemeMode.light);
    await tester.tap(find.text('Light'));
    await tester.pump();
    expect(calls, isEmpty);
  });

  testWidgets('all three options are shown', (tester) async {
    await pump(tester, ThemeMode.system);
    expect(find.text('System'), findsOneWidget);
    expect(find.text('Light'), findsOneWidget);
    expect(find.text('Dark'), findsOneWidget);
  });
}
