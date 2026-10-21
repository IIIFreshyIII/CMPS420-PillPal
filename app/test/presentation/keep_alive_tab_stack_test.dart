import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pillpal/presentation/widgets/keep_alive_tab_stack.dart';

class _StatefulCounter extends StatefulWidget {
  final String label;
  const _StatefulCounter({required this.label});

  @override
  State<_StatefulCounter> createState() => _StatefulCounterState();
}

class _StatefulCounterState extends State<_StatefulCounter> {
  int count = 0;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text('${widget.label}: $count'),
        ElevatedButton(
          onPressed: () => setState(() => count++),
          child: Text('Increment ${widget.label}'),
        ),
      ],
    );
  }
}

void main() {
  testWidgets('KeepAliveTabStack lazily mounts tabs and preserves state across switches',
      (tester) async {
    int selectedIndex = 0;
    late StateSetter setStackState;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: StatefulBuilder(
            builder: (context, setState) {
              setStackState = setState;
              return KeepAliveTabStack(
                selectedIndex: selectedIndex,
                builders: [
                  (context) => const _StatefulCounter(label: 'Tab0'),
                  (context) => const _StatefulCounter(label: 'Tab1'),
                  (context) => const _StatefulCounter(label: 'Tab2'),
                ],
              );
            },
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    // Tab 0 is mounted and active
    expect(find.text('Tab0: 0'), findsOneWidget);
    // Tab 1 and Tab 2 are NOT mounted at all yet
    expect(find.text('Tab1: 0'), findsNothing);
    expect(find.text('Tab2: 0'), findsNothing);

    // Increment Tab 0's internal state
    await tester.tap(find.text('Increment Tab0'));
    await tester.pumpAndSettle();
    expect(find.text('Tab0: 1'), findsOneWidget);

    // Switch to Tab 1
    setStackState(() => selectedIndex = 1);
    await tester.pump();
    await tester.pumpAndSettle();

    // Tab 1 is now mounted and visible
    expect(find.text('Tab1: 0'), findsOneWidget);
    // Tab 0 is offstage (skipOffstage: true skips it)
    expect(find.text('Tab0: 1'), findsNothing);
    expect(find.text('Tab0: 1', skipOffstage: false), findsOneWidget);

    // Increment Tab 1's state
    await tester.tap(find.text('Increment Tab1'));
    await tester.pumpAndSettle();
    expect(find.text('Tab1: 1'), findsOneWidget);

    // Switch back to Tab 0
    setStackState(() => selectedIndex = 0);
    await tester.pumpAndSettle();

    // Tab 0 preserved its internal state count of 1!
    expect(find.text('Tab0: 1'), findsOneWidget);
    // Tab 1 is offstage but preserved its count of 1!
    expect(find.text('Tab1: 1'), findsNothing);
    expect(find.text('Tab1: 1', skipOffstage: false), findsOneWidget);
  });
}
