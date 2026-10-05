import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:pillpal/presentation/widgets/confetti_burst.dart';

void main() {
  Future<BuildContext> pumpHost(WidgetTester tester,
      {bool disableAnimations = false}) async {
    late BuildContext ctx;
    await tester.pumpWidget(MediaQuery(
      data: MediaQueryData(disableAnimations: disableAnimations),
      child: MaterialApp(
        home: Builder(builder: (c) {
          ctx = c;
          return const SizedBox.shrink();
        }),
      ),
    ));
    return ctx;
  }

  testWidgets('plays once, then removes itself', (tester) async {
    final ctx = await pumpHost(tester);
    ConfettiBurst.show(ctx,
        origin: const Offset(100, 100), colors: const [Colors.teal]);
    await tester.pump();
    expect(find.byType(ConfettiBurst), findsOneWidget);

    await tester
        .pump(ConfettiBurst.duration + const Duration(milliseconds: 50));
    await tester.pump();
    expect(find.byType(ConfettiBurst), findsNothing);
  });

  testWidgets('skipped when "Remove animations" is on', (tester) async {
    final ctx = await pumpHost(tester, disableAnimations: true);
    ConfettiBurst.show(ctx,
        origin: const Offset(100, 100), colors: const [Colors.teal]);
    await tester.pump();
    expect(find.byType(ConfettiBurst), findsNothing);
  });
}
