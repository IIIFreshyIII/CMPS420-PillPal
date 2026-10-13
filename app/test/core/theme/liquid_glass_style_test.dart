import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pillpal/core/services/ios_accessibility_service.dart';
import 'package:pillpal/core/theme/liquid_glass_mode.dart';
import 'package:pillpal/core/theme/liquid_glass_style.dart';

void main() {
  tearDown(() {
    IOSAccessibilityService.setDebugReduceTransparencyOverride(null);
  });

  Widget buildTestContext(
    WidgetBuilder builder, {
    bool highContrast = false,
    bool disableAnimations = false,
  }) {
    return MaterialApp(
      home: MediaQuery(
        data: MediaQueryData(
          highContrast: highContrast,
          disableAnimations: disableAnimations,
        ),
        child: Builder(builder: builder),
      ),
    );
  }

  group('LiquidGlassStyle.resolve', () {
    testWidgets('Auto mode with default settings resolves to Liquid Glass',
        (tester) async {
      late LiquidGlassStyle style;
      await tester.pumpWidget(buildTestContext((context) {
        style = LiquidGlassStyle.resolve(
          context,
          isDark: false,
          isLifted: false,
          mode: LiquidGlassMode.auto,
        );
        return const SizedBox();
      }));

      expect(style.resolvedMode, LiquidGlassMode.liquid);
      expect(style.hasBlur, isTrue);
      expect(style.blurSigma, 25.0);
      expect(style.solidBackgroundColor, isNull);
      expect(style.backgroundGradient, isNotNull);
      expect(style.liftScale, 1.0);
    });

    testWidgets(
        'Auto mode switches to Opaque with 0% blur when High Contrast / Reduce Transparency is enabled',
        (tester) async {
      late LiquidGlassStyle style;
      await tester.pumpWidget(buildTestContext(
        (context) {
          style = LiquidGlassStyle.resolve(
            context,
            isDark: false,
            isLifted: false,
            mode: LiquidGlassMode.auto,
          );
          return const SizedBox();
        },
        highContrast: true,
      ));

      expect(style.resolvedMode, LiquidGlassMode.opaque);
      expect(style.hasBlur, isFalse);
      expect(style.blurSigma, 0.0);
      expect(style.solidBackgroundColor, const Color(0xFFFFFFFF));
      expect(style.backgroundGradient, isNull);
      expect(style.border.top.width, 1.5);
    });

    testWidgets(
        'Auto mode switches to Opaque when native iOS Reduce Transparency is enabled',
        (tester) async {
      IOSAccessibilityService.setDebugReduceTransparencyOverride(true);
      late LiquidGlassStyle style;
      await tester.pumpWidget(buildTestContext((context) {
        style = LiquidGlassStyle.resolve(
          context,
          isDark: true,
          isLifted: false,
          mode: LiquidGlassMode.auto,
        );
        return const SizedBox();
      }));

      expect(style.resolvedMode, LiquidGlassMode.opaque);
      expect(style.hasBlur, isFalse);
      expect(style.blurSigma, 0.0);
      expect(style.solidBackgroundColor, const Color(0xFF141D1C));
      expect(style.backgroundGradient, isNull);
      expect(style.border.top.width, 1.5);
    });

    testWidgets(
        'Reduce Motion (disableAnimations) locks liftScale to 1.0 and marks disableAnimations',
        (tester) async {
      late LiquidGlassStyle styleLifted;
      await tester.pumpWidget(buildTestContext(
        (context) {
          styleLifted = LiquidGlassStyle.resolve(
            context,
            isDark: false,
            isLifted: true,
            mode: LiquidGlassMode.liquid,
          );
          return const SizedBox();
        },
        disableAnimations: true,
      ));

      expect(styleLifted.disableAnimations, isTrue);
      expect(styleLifted.liftScale, 1.0);
    });

    testWidgets('Lifted state without Reduce Motion applies spring lift scale',
        (tester) async {
      late LiquidGlassStyle styleLifted;
      await tester.pumpWidget(buildTestContext(
        (context) {
          styleLifted = LiquidGlassStyle.resolve(
            context,
            isDark: false,
            isLifted: true,
            mode: LiquidGlassMode.liquid,
          );
          return const SizedBox();
        },
        disableAnimations: false,
      ));

      expect(styleLifted.disableAnimations, isFalse);
      expect(styleLifted.liftScale, 1.05);
    });

    testWidgets('Explicit Frosted mode resolves 12px blur with frosted gradient',
        (tester) async {
      late LiquidGlassStyle style;
      await tester.pumpWidget(buildTestContext((context) {
        style = LiquidGlassStyle.resolve(
          context,
          isDark: false,
          isLifted: false,
          mode: LiquidGlassMode.frosted,
        );
        return const SizedBox();
      }));

      expect(style.resolvedMode, LiquidGlassMode.frosted);
      expect(style.hasBlur, isTrue);
      expect(style.blurSigma, 12.0);
      expect(style.backgroundGradient, isNotNull);
      expect(style.solidBackgroundColor, isNull);
    });

    testWidgets('Explicit Opaque mode resolves 0% blur and solid background',
        (tester) async {
      late LiquidGlassStyle style;
      await tester.pumpWidget(buildTestContext((context) {
        style = LiquidGlassStyle.resolve(
          context,
          isDark: true,
          isLifted: false,
          mode: LiquidGlassMode.opaque,
        );
        return const SizedBox();
      }));

      expect(style.resolvedMode, LiquidGlassMode.opaque);
      expect(style.hasBlur, isFalse);
      expect(style.blurSigma, 0.0);
      expect(style.solidBackgroundColor, const Color(0xFF141D1C));
      expect(style.backgroundGradient, isNull);
    });
  });
}
