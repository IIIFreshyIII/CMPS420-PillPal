import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pillpal/core/theme/liquid_glass_controller.dart';
import 'package:pillpal/core/theme/liquid_glass_mode.dart';
import 'package:pillpal/screens/account/liquid_glass_setting.dart';

void main() {
  testWidgets('LiquidGlassSetting renders segments and responds to selection',
      (tester) async {
    final controller = LiquidGlassController(LiquidGlassMode.auto);

    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: LiquidGlassSetting(controller: controller),
      ),
    ));

    expect(find.text('Liquid Glass Effect'), findsOneWidget);
    expect(find.text('Auto'), findsWidgets);
    expect(find.text('Liquid'), findsOneWidget);
    expect(find.text('Frosted'), findsOneWidget);
    expect(find.text('Opaque'), findsOneWidget);
    expect(find.text(LiquidGlassMode.auto.description), findsOneWidget);

    // Tap Frosted
    await tester.tap(find.byKey(const ValueKey('liquid_glass_frosted')));
    await tester.pumpAndSettle();

    expect(controller.value, LiquidGlassMode.frosted);
    expect(find.text(LiquidGlassMode.frosted.description), findsOneWidget);

    // Tap Opaque
    await tester.tap(find.byKey(const ValueKey('liquid_glass_opaque')));
    await tester.pumpAndSettle();

    expect(controller.value, LiquidGlassMode.opaque);
    expect(find.text(LiquidGlassMode.opaque.description), findsOneWidget);

    // Tap Liquid
    await tester.tap(find.byKey(const ValueKey('liquid_glass_liquid')));
    await tester.pumpAndSettle();

    expect(controller.value, LiquidGlassMode.liquid);
    expect(find.text(LiquidGlassMode.liquid.description), findsOneWidget);
  });
}
