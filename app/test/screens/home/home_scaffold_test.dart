import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pillpal/core/theme/app_theme.dart';
import 'package:pillpal/core/utils/ios_design_era.dart';
import 'package:pillpal/data/local/app_database.dart';
import 'package:pillpal/presentation/widgets/classic_ios_tab_bar.dart';
import 'package:pillpal/presentation/widgets/floating_tab_bar.dart';
import 'package:pillpal/screens/home/home_scaffold.dart';

void main() {
  tearDown(() {
    debugIOSMajorVersionOverride = null;
    debugIsHomeButtonOverride = null;
  });

  Widget buildScaffold({
    required Size size,
    EdgeInsets padding = EdgeInsets.zero,
    EdgeInsets viewPadding = EdgeInsets.zero,
  }) {
    return MaterialApp(
      theme: AppTheme.lightTheme,
      home: MediaQuery(
        data: MediaQueryData(
          size: size,
          padding: padding,
          viewPadding: viewPadding,
        ),
        child: HomeScaffold(
          database: AppDatabase(NativeDatabase.memory()),
        ),
      ),
    );
  }

  testWidgets('renders ClassicIOSTabBar on iPhone SE metrics even on iOS 26 runtime',
      (tester) async {
    debugIOSMajorVersionOverride = 26;

    // iPhone SE 3rd Gen: 375x667, 0 bottom inset
    await tester.pumpWidget(buildScaffold(
      size: const Size(375, 667),
      padding: const EdgeInsets.only(top: 20),
      viewPadding: const EdgeInsets.only(top: 20),
    ));
    await tester.pumpAndSettle();

    expect(find.byType(ClassicIOSTabBar), findsOneWidget);
    expect(find.byType(FloatingTabBar), findsNothing);

    // Clean up timers
    await tester.pumpWidget(const SizedBox());
    await tester.pump(Duration.zero);
  });

  testWidgets('renders FloatingTabBar on modern iPhone 17 metrics on iOS 26',
      (tester) async {
    debugIOSMajorVersionOverride = 26;

    // iPhone 17: 393x852, 34 bottom inset
    await tester.pumpWidget(buildScaffold(
      size: const Size(393, 852),
      padding: const EdgeInsets.only(top: 54, bottom: 34),
      viewPadding: const EdgeInsets.only(top: 54, bottom: 34),
    ));
    await tester.pumpAndSettle();

    expect(find.byType(FloatingTabBar), findsOneWidget);
    expect(find.byType(ClassicIOSTabBar), findsNothing);

    // Clean up timers
    await tester.pumpWidget(const SizedBox());
    await tester.pump(Duration.zero);
  });
}
