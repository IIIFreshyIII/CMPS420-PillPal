import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pillpal/core/services/ios_accessibility_service.dart';
import 'package:pillpal/core/theme/liquid_glass_controller.dart';
import 'package:pillpal/core/theme/liquid_glass_mode.dart';
import 'package:pillpal/presentation/widgets/floating_tab_bar.dart';

void main() {
  tearDown(() {
    IOSAccessibilityService.setDebugReduceTransparencyOverride(null);
  });

  Widget wrapTabBar({
    required AppTab activeTab,
    required ValueChanged<AppTab> onTabPress,
    LiquidGlassController? controller,
    LiquidGlassMode? debugModeOverride,
    bool highContrast = false,
  }) {
    return MaterialApp(
      home: Scaffold(
        body: MediaQuery(
          data: MediaQueryData(highContrast: highContrast),
          child: Stack(
            children: [
              FloatingTabBar(
                activeTab: activeTab,
                onTabPress: onTabPress,
                controller: controller,
                debugModeOverride: debugModeOverride,
              ),
            ],
          ),
        ),
      ),
    );
  }

  testWidgets('renders BackdropFilter when in liquid mode', (tester) async {
    await tester.pumpWidget(wrapTabBar(
      activeTab: AppTab.schedule,
      onTabPress: (_) {},
      debugModeOverride: LiquidGlassMode.liquid,
    ));

    expect(find.byType(BackdropFilter), findsOneWidget);
  });

  testWidgets('omits BackdropFilter completely when in opaque mode',
      (tester) async {
    await tester.pumpWidget(wrapTabBar(
      activeTab: AppTab.schedule,
      onTabPress: (_) {},
      debugModeOverride: LiquidGlassMode.opaque,
    ));

    // BackdropFilter should be completely bypassed to eliminate GPU blur passes
    expect(find.byType(BackdropFilter), findsNothing);
  });

  testWidgets(
      'omits BackdropFilter when auto mode detects system High Contrast',
      (tester) async {
    await tester.pumpWidget(wrapTabBar(
      activeTab: AppTab.schedule,
      onTabPress: (_) {},
      debugModeOverride: LiquidGlassMode.auto,
      highContrast: true,
    ));

    expect(find.byType(BackdropFilter), findsNothing);
  });

  testWidgets(
      'omits BackdropFilter when auto mode detects native iOS Reduce Transparency',
      (tester) async {
    IOSAccessibilityService.setDebugReduceTransparencyOverride(true);

    await tester.pumpWidget(wrapTabBar(
      activeTab: AppTab.schedule,
      onTabPress: (_) {},
      debugModeOverride: LiquidGlassMode.auto,
      highContrast: false,
    ));

    expect(find.byType(BackdropFilter), findsNothing);
  });

  testWidgets('taps switch tab and notify callback', (tester) async {
    AppTab? selectedTab;
    await tester.pumpWidget(wrapTabBar(
      activeTab: AppTab.schedule,
      onTabPress: (tab) => selectedTab = tab,
    ));

    await tester.tap(find.text('Meds'));
    await tester.pumpAndSettle();

    expect(selectedTab, AppTab.meds);
  });

  testWidgets('dynamically removes BackdropFilter when controller changes to opaque',
      (tester) async {
    final controller = LiquidGlassController(LiquidGlassMode.liquid);
    await tester.pumpWidget(wrapTabBar(
      activeTab: AppTab.schedule,
      onTabPress: (_) {},
      controller: controller,
    ));

    expect(find.byType(BackdropFilter), findsOneWidget);

    controller.value = LiquidGlassMode.opaque;
    await tester.pumpAndSettle();

    expect(find.byType(BackdropFilter), findsNothing);
  });
}
