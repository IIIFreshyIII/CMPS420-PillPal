import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pillpal/core/navigation/navigator_key.dart';
import 'package:pillpal/core/state/app_state_manager.dart';
import 'package:pillpal/presentation/widgets/debug_floating_switcher.dart';

class MockSecureStorage extends Fake implements FlutterSecureStorage {
  final Map<String, String> _data = {};

  @override
  Future<String?> read({
    required String key,
    AppleOptions? iOptions,
    AndroidOptions? aOptions,
    LinuxOptions? lOptions,
    WebOptions? webOptions,
    AppleOptions? mOptions,
    WindowsOptions? wOptions,
  }) async =>
      _data[key];

  @override
  Future<void> write({
    required String key,
    required String? value,
    AppleOptions? iOptions,
    AndroidOptions? aOptions,
    LinuxOptions? lOptions,
    WebOptions? webOptions,
    AppleOptions? mOptions,
    WindowsOptions? wOptions,
  }) async {
    if (value == null) {
      _data.remove(key);
    } else {
      _data[key] = value;
    }
  }

  @override
  Future<void> delete({
    required String key,
    AppleOptions? iOptions,
    AndroidOptions? aOptions,
    LinuxOptions? lOptions,
    WebOptions? webOptions,
    AppleOptions? mOptions,
    WindowsOptions? wOptions,
  }) async {
    _data.remove(key);
  }
}

void main() {
  late MockSecureStorage mockStorage;
  late AppStateManager appStateManager;

  setUp(() {
    mockStorage = MockSecureStorage();
    appStateManager = AppStateManager(storage: mockStorage);
  });

  Widget createTestWidget() {
    return MaterialApp(
      navigatorKey: rootNavigatorKey,
      builder: (context, child) => Stack(
        children: [
          child!,
          DebugFloatingSwitcher(
            appStateManager: appStateManager,
            navigatorKey: rootNavigatorKey,
          ),
        ],
      ),
      home: const Scaffold(
        body: Center(
          child: Text('Main Content'),
        ),
      ),
    );
  }

  testWidgets(
      'DebugFloatingSwitcher opens presets sheet without navigator error and resets onboarding',
      (tester) async {
    // Start with onboarding completed
    await appStateManager.setHasCompletedOnboarding(true);
    await appStateManager.setUserName('Alice');
    expect(appStateManager.hasCompletedOnboarding, isTrue);

    await tester.pumpWidget(createTestWidget());
    await tester.pump();

    // Verify Debug pill is present
    expect(find.text('Debug'), findsOneWidget);

    // Tap the floating Debug button (which is rendered in MaterialApp.builder)
    await tester.tap(find.text('Debug'));
    await tester.pumpAndSettle();

    // Verify presets sheet opened successfully without navigator context error
    expect(find.text('Developer Presets'), findsOneWidget);
    expect(find.text('Fresh A-to-Z Onboarding'), findsOneWidget);
    expect(find.text('Seeded UI Testing'), findsOneWidget);
    expect(find.text('Replay Tab Tutorials'), findsOneWidget);

    // Tap Preset 1: Fresh A-to-Z Onboarding
    await tester.tap(find.text('Fresh A-to-Z Onboarding'));
    await tester.pumpAndSettle();

    // Verify sheet closed and state reset
    expect(find.text('Developer Presets'), findsNothing);
    expect(appStateManager.hasCompletedOnboarding, isFalse);
    expect(appStateManager.userName, isEmpty);
  });

  testWidgets('DebugFloatingSwitcher switches to Seeded UI Testing mode',
      (tester) async {
    await tester.pumpWidget(createTestWidget());
    await tester.pump();

    await tester.tap(find.text('Debug'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Seeded UI Testing'));
    await tester.pumpAndSettle();

    expect(find.text('Developer Presets'), findsNothing);
    expect(appStateManager.hasCompletedOnboarding, isTrue);
    expect(appStateManager.isSeededTestingMode, isTrue);
    expect(appStateManager.hasSeenScheduleTour, isTrue);
    expect(appStateManager.hasSeenMedsTour, isTrue);
    expect(appStateManager.hasSeenAccountTour, isTrue);
  });

  testWidgets('DebugFloatingSwitcher replays tab tutorials', (tester) async {
    await appStateManager.setSeededUiTesting();
    expect(appStateManager.hasSeenScheduleTour, isTrue);

    await tester.pumpWidget(createTestWidget());
    await tester.pump();

    await tester.tap(find.text('Debug'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Replay Tab Tutorials'));
    await tester.pumpAndSettle();

    expect(find.text('Developer Presets'), findsNothing);
    expect(appStateManager.hasCompletedOnboarding, isTrue);
    expect(appStateManager.hasSeenScheduleTour, isFalse);
    expect(appStateManager.hasSeenMedsTour, isFalse);
    expect(appStateManager.hasSeenAccountTour, isFalse);
  });
}
