import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:pillpal/presentation/widgets/pressable.dart';

void main() {
  Widget host(Widget child) =>
      MaterialApp(home: Scaffold(body: Center(child: child)));

  double scaleOf(WidgetTester tester) =>
      tester.widget<AnimatedScale>(find.byType(AnimatedScale)).scale;

  testWidgets('tap fires onTap; press shrinks and release springs back',
      (tester) async {
    var taps = 0;
    await tester.pumpWidget(host(Pressable(
      onTap: () => taps++,
      scale: 0.94,
      child: const SizedBox(width: 100, height: 40, child: Text('Go')),
    )));

    final gesture =
        await tester.startGesture(tester.getCenter(find.text('Go')));
    await tester.pump(const Duration(milliseconds: 150));
    expect(scaleOf(tester), 0.94);

    await gesture.up();
    await tester.pumpAndSettle();
    expect(scaleOf(tester), 1.0);
    expect(taps, 1);
  });

  testWidgets('disabled (onTap null) neither scales nor fires', (tester) async {
    await tester.pumpWidget(host(const Pressable(
      child: SizedBox(width: 100, height: 40, child: Text('Off')),
    )));
    final gesture =
        await tester.startGesture(tester.getCenter(find.text('Off')));
    await tester.pump(const Duration(milliseconds: 150));
    expect(scaleOf(tester), 1.0);
    await gesture.up();
  });

  testWidgets('a tap on the foreground does not trigger the surface',
      (tester) async {
    var surfaceTaps = 0;
    var checkTaps = 0;
    await tester.pumpWidget(host(Pressable(
      onTap: () => surfaceTaps++,
      borderRadius: BorderRadius.circular(18),
      foreground: Align(
        alignment: Alignment.centerRight,
        child: GestureDetector(
          onTap: () => checkTaps++,
          child: const SizedBox(width: 48, height: 48, child: Text('Check')),
        ),
      ),
      child: const SizedBox(width: 300, height: 80, child: Text('Card')),
    )));

    final gesture =
        await tester.startGesture(tester.getCenter(find.text('Check')));
    await tester.pump(const Duration(milliseconds: 150));
    expect(scaleOf(tester), 1.0,
        reason: 'holding the check must not press the card');
    await gesture.up();
    await tester.pumpAndSettle();

    expect(checkTaps, 1);
    expect(surfaceTaps, 0);

    await tester.tap(find.text('Card'));
    await tester.pumpAndSettle();
    expect(surfaceTaps, 1);
  });
}
