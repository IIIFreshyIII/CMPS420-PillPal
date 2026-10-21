import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pillpal/core/permissions/camera_permission.dart';
import 'package:pillpal/core/state/app_state_manager.dart';
import 'package:pillpal/core/theme/app_theme.dart';
import 'package:pillpal/core/utils/ios_design_era.dart';
import 'package:pillpal/data/services/notification_service.dart';
import 'package:pillpal/presentation/widgets/scan_bottle_button.dart';
import 'package:pillpal/screens/onboarding/steps/step1_splash.dart';
import 'package:pillpal/screens/onboarding/steps/step2_legal.dart';
import 'package:pillpal/screens/onboarding/steps/step3_name_morph.dart';
import 'package:pillpal/screens/onboarding/steps/step4_permissions.dart';
import 'package:pillpal/screens/onboarding/steps/step5_first_reminder.dart';

class MockStorage extends Fake implements FlutterSecureStorage {
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

class FakeNotificationService extends NotificationService {
  bool enabled = false;

  @override
  Future<bool> requestPermissions() async {
    enabled = true;
    return true;
  }

  @override
  Future<bool> areNotificationsEnabled() async => enabled;
}

void main() {
  tearDown(() {
    debugIsLiquidGlassSupportedOverride = null;
  });

  Widget wrap(Widget child) {
    return MaterialApp(
      theme: AppTheme.lightTheme,
      home: child,
    );
  }

  testWidgets('Step 1 Splash renders and taps to advance', (tester) async {
    var completed = false;
    await tester.pumpWidget(wrap(Step1Splash(
      onComplete: () => completed = true,
      autoAdvanceDelay: const Duration(seconds: 10),
    )));

    expect(find.text('Medication tracking, simplified & private.'), findsOneWidget);

    // Tap anywhere to advance
    await tester.tap(find.byType(GestureDetector).first);
    await tester.pump(const Duration(milliseconds: 350));
    await tester.pump(const Duration(milliseconds: 50));

    expect(completed, isTrue);

    await tester.pumpWidget(const SizedBox());
    await tester.pump(Duration.zero);
  });

  testWidgets('Step 2 Legal renders disclosures and advances on agree',
      (tester) async {
    var agreed = false;
    await tester.pumpWidget(wrap(Step2Legal(
      onAgree: () => agreed = true,
    )));
    await tester.pumpAndSettle();

    expect(find.textContaining('Important Information'), findsOneWidget);
    expect(find.text('Medical Emergencies (911)'), findsOneWidget);
    expect(find.text('Not a Doctor or Pharmacist'), findsOneWidget);
    expect(find.text('OCR Label Verification Duty'), findsOneWidget);

    // Drag to bottom so agree button unlocks
    await tester.drag(find.byType(SingleChildScrollView), const Offset(0, -800));
    await tester.pumpAndSettle();

    expect(find.text('I Understand & Agree'), findsOneWidget);
    await tester.tap(find.text('I Understand & Agree'));
    await tester.pumpAndSettle();

    expect(agreed, isTrue);
  });

  testWidgets('Step 3 Name Morph choreographs typing, name isolation, and greeting',
      (tester) async {
    String? confirmedName;
    var nextTapped = false;

    await tester.pumpWidget(wrap(Step3NameMorph(
      onNameConfirmed: (name) async {
        confirmedName = name;
      },
      onNext: () => nextTapped = true,
    )));

    // Phase A: Prompt and input field
    expect(find.text("Hi! What's your name?"), findsOneWidget);
    expect(find.byType(TextField), findsOneWidget);

    // Enter name
    await tester.enterText(find.byType(TextField), 'Cade');
    await tester.pump();

    // Submit
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pump();

    expect(confirmedName, 'Cade');

    // Run animation to completion (1600ms 4-beat sequence)
    await tester.pump(const Duration(milliseconds: 500));
    await tester.pump(const Duration(milliseconds: 600));
    await tester.pump(const Duration(milliseconds: 600));
    await tester.pumpAndSettle();

    // Greeting verified
    expect(find.text('Hi '), findsOneWidget);
    expect(find.text('Cade'), findsOneWidget);
    expect(find.text('Welcome to '), findsOneWidget);

    // Next button present
    expect(find.text('Next'), findsOneWidget);
    await tester.tap(find.text('Next'));
    await tester.pumpAndSettle();

    expect(nextTapped, isTrue);
  });

  testWidgets('Step 4 Permissions displays controls and enables Next',
      (tester) async {
    final storage = MockStorage();
    final manager = AppStateManager(storage: storage);
    final fakeNotifs = FakeNotificationService();
    var nextTapped = false;

    await tester.pumpWidget(wrap(Step4Permissions(
      appStateManager: manager,
      notificationService: fakeNotifs,
      onNext: () => nextTapped = true,
      requestCamera: () async => CameraPermissionResult.granted,
      checkCamera: () async => CameraPermissionResult.denied,
    )));
    await tester.pumpAndSettle();

    expect(find.text('Permissions & Local Setup'), findsOneWidget);
    expect(find.textContaining('Account tab'), findsOneWidget);
    expect(find.text('On-Device Camera Access'), findsOneWidget);
    expect(find.text('Dose & Refill Notifications'), findsOneWidget);
    expect(find.text('Appearance Theme'), findsOneWidget);
    expect(find.text('History Retention'), findsOneWidget);

    // CupertinoSwitch is rendered
    final cupertinoSwitches = find.byType(CupertinoSwitch);
    expect(cupertinoSwitches, findsWidgets);

    // Toggle camera switch
    await tester.tap(cupertinoSwitches.first);
    await tester.pumpAndSettle();

    // Toggle notif switch
    await tester.tap(cupertinoSwitches.at(1));
    await tester.pumpAndSettle();

    // Test Theme Selector
    await tester.tap(find.text('Dark'));
    await tester.pumpAndSettle();
    expect(manager.appearanceMode, ThemeMode.dark);

    // Test Retention Pull-Down Menu
    await tester.ensureVisible(find.text('History Retention'));
    await tester.pumpAndSettle();
    await tester.tap(find.textContaining('Months'));
    await tester.pumpAndSettle();
    expect(find.text('6 Months'), findsOneWidget);
    await tester.tap(find.text('6 Months'));
    await tester.pumpAndSettle();
    expect(manager.retentionDays, 180);

    // Tap Next
    final nextButton = find.text('Next');
    expect(nextButton, findsOneWidget);
    await tester.tap(nextButton);
    await tester.pumpAndSettle();
    expect(nextTapped, isTrue);
  });

  testWidgets('Step 5 First Reminder renders ScanBottleButton and options',
      (tester) async {
    var scanTapped = false;
    var skipTapped = false;

    await tester.pumpWidget(wrap(Step5FirstReminder(
      onStartScan: () => scanTapped = true,
      onSkipToSchedule: () => skipTapped = true,
    )));

    expect(find.text("Thanks! Now, let's set up your first reminder!"), findsOneWidget);
    expect(find.byType(ScanBottleButton), findsOneWidget);
    expect(find.text('Add New Prescription'), findsOneWidget);

    await tester.tap(find.text('Add New Prescription'));
    await tester.pumpAndSettle();
    expect(scanTapped, isTrue);

    await tester.tap(find.text('Or go directly to Schedule'));
    await tester.pumpAndSettle();
    expect(skipTapped, isTrue);
  });

  testWidgets('Step 4 Permissions hides Liquid Glass styling when not supported (Android / pre-iOS 26)',
      (tester) async {
    debugIsLiquidGlassSupportedOverride = false;
    final storage = MockStorage();
    final manager = AppStateManager(storage: storage);
    final fakeNotifs = FakeNotificationService();

    await tester.pumpWidget(wrap(Step4Permissions(
      appStateManager: manager,
      notificationService: fakeNotifs,
      onNext: () {},
      requestCamera: () async => CameraPermissionResult.granted,
      checkCamera: () async => CameraPermissionResult.denied,
    )));
    await tester.pumpAndSettle();

    expect(find.text('Liquid Glass Styling'), findsNothing);
  });

  testWidgets('Step 4 Permissions shows Liquid Glass styling when supported (iOS 26+)',
      (tester) async {
    debugIsLiquidGlassSupportedOverride = true;
    final storage = MockStorage();
    final manager = AppStateManager(storage: storage);
    final fakeNotifs = FakeNotificationService();

    await tester.pumpWidget(wrap(Step4Permissions(
      appStateManager: manager,
      notificationService: fakeNotifs,
      onNext: () {},
      requestCamera: () async => CameraPermissionResult.granted,
      checkCamera: () async => CameraPermissionResult.denied,
    )));
    await tester.pumpAndSettle();

    expect(find.text('Liquid Glass Styling'), findsOneWidget);
  });
}
