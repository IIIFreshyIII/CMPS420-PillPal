import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pillpal/core/state/app_state_manager.dart';
import 'package:pillpal/core/theme/app_theme.dart';
import 'package:pillpal/data/services/notification_service.dart';
import 'package:pillpal/screens/onboarding/steps/step1_splash.dart';
import 'package:pillpal/screens/onboarding/steps/step2_legal.dart';
import 'package:pillpal/screens/onboarding/steps/step3_name_morph.dart';
import 'package:pillpal/screens/onboarding/steps/step4_permissions.dart';
import 'package:pillpal/screens/onboarding/steps/step5_bedtime.dart';
import 'package:pillpal/screens/onboarding/steps/step5_first_reminder.dart';
import 'package:pillpal/services/bedtime_service.dart';

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

  testWidgets('Step 4 Privacy & Protection displays controls and enables Continue',
      (tester) async {
    final storage = MockStorage();
    final manager = AppStateManager(storage: storage);
    final fakeNotifs = FakeNotificationService();
    var nextTapped = false;

    await tester.pumpWidget(wrap(Step4Permissions(
      appStateManager: manager,
      notificationService: fakeNotifs,
      onNext: () => nextTapped = true,
    )));
    await tester.pumpAndSettle();

    expect(find.text('Privacy & Security'), findsOneWidget);
    expect(find.text('Your Data Stays on Your Device'), findsOneWidget);
    expect(find.text('Lock with Face ID / Passcode'), findsOneWidget);
    expect(find.text('Dose Reminder Alerts'), findsOneWidget);

    // PlatformSwitch renders Material Switch on Android (default test platform)
    final switches = find.byType(Switch);
    expect(switches, findsNWidgets(2));

    // Toggle biometrics switch
    await tester.tap(switches.first);
    await tester.pumpAndSettle();
    expect(manager.biometricsEnabled, isTrue);

    // Toggle notif switch
    await tester.tap(switches.at(1));
    await tester.pumpAndSettle();
    expect(fakeNotifs.enabled, isTrue);

    // On iOS, PlatformSwitch renders CupertinoSwitch
    await tester.pumpWidget(MaterialApp(
      theme: ThemeData(platform: TargetPlatform.iOS),
      home: Scaffold(
        body: Step4Permissions(
          appStateManager: manager,
          notificationService: fakeNotifs,
          onNext: () => nextTapped = true,
        ),
      ),
    ));
    await tester.pumpAndSettle();
    expect(find.byType(CupertinoSwitch), findsNWidgets(2));
    expect(find.byType(Switch), findsNothing);

    // Tap Continue
    final continueButton = find.text('Continue');
    expect(continueButton, findsOneWidget);
    await tester.tap(continueButton);
    await tester.pumpAndSettle();
    expect(nextTapped, isTrue);
  });

  testWidgets('Step 5 Bedtime displays default 10:00 PM / 7:00 AM and confirms schedule',
      (tester) async {
    BedtimeSchedule? savedSchedule;
    var nextTapped = false;

    await tester.pumpWidget(wrap(Step5Bedtime(
      onBedtimeConfirmed: (schedule) async {
        savedSchedule = schedule;
      },
      onNext: () => nextTapped = true,
    )));
    await tester.pumpAndSettle();

    expect(find.text('Set your sleep schedule'), findsOneWidget);
    expect(find.text('10:00 PM'), findsOneWidget);
    expect(find.text('7:00 AM'), findsOneWidget);

    // Tap Save & Continue
    await tester.tap(find.text('Save & Continue'));
    await tester.pumpAndSettle();

    expect(savedSchedule, isNotNull);
    expect(savedSchedule!.isEnabled, isTrue);
    expect(savedSchedule!.windowForWeekday(DateTime.monday).bedtime, '10:00 PM');
    expect(savedSchedule!.windowForWeekday(DateTime.monday).wakeTime, '7:00 AM');
    expect(nextTapped, isTrue);
  });

  testWidgets('Step 5 Bedtime allows skipping with Set later in Settings',
      (tester) async {
    BedtimeSchedule? savedSchedule = BedtimeSchedule.everyDay();
    var nextTapped = false;

    await tester.pumpWidget(wrap(Step5Bedtime(
      onBedtimeConfirmed: (schedule) async {
        savedSchedule = schedule;
      },
      onNext: () => nextTapped = true,
    )));
    await tester.pumpAndSettle();

    // Tap Set later in Settings
    await tester.tap(find.text('Set later in Settings'));
    await tester.pumpAndSettle();

    expect(savedSchedule, isNull);
    expect(nextTapped, isTrue);
  });

  testWidgets('Step 6 First Reminder renders all 3 entry options and skip capsule',
      (tester) async {
    var scanTapped = false;
    var photoTapped = false;
    var manualTapped = false;
    var skipTapped = false;

    await tester.pumpWidget(wrap(Step5FirstReminder(
      onStartScan: () => scanTapped = true,
      onUploadPhoto: () => photoTapped = true,
      onManualEntry: () => manualTapped = true,
      onSkipToSchedule: () => skipTapped = true,
    )));

    expect(find.text("Now, let's add your first medication!"), findsOneWidget);
    expect(find.text('Scan Prescription Label'), findsOneWidget);
    expect(find.text('From Photos'), findsOneWidget);
    expect(find.text('Enter Manually'), findsOneWidget);
    expect(find.text('Or go directly to Schedule'), findsOneWidget);

    await tester.tap(find.text('Scan Prescription Label'));
    await tester.pumpAndSettle();
    expect(scanTapped, isTrue);

    await tester.tap(find.text('From Photos'));
    await tester.pumpAndSettle();
    expect(photoTapped, isTrue);

    await tester.tap(find.text('Enter Manually'));
    await tester.pumpAndSettle();
    expect(manualTapped, isTrue);

    await tester.tap(find.text('Or go directly to Schedule'));
    await tester.pumpAndSettle();
    expect(skipTapped, isTrue);
  });
}
